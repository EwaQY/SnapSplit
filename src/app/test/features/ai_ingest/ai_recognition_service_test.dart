import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/features/ai_ingest/data/ai_config.dart';
import 'package:snap_split/src/features/ai_ingest/data/ai_recognition_service.dart';
import 'package:snap_split/src/features/ai_ingest/domain/ai_receipt_dto.dart';

/// T6：AI 调用层（全 MockClient，零网络零真实 key）。
void main() {
  const AiConfig config = AiConfig(
    baseUrl: 'https://example.test/api/v1',
    modelId: 'test-model',
    apiKey: 'test-key',
  );
  final Uint8List image = Uint8List.fromList(<int>[1, 2, 3]);

  Map<String, dynamic> envelopeOf(Object content) => <String, dynamic>{
    'data': <String, dynamic>{
      'choices': <Map<String, dynamic>>[
        <String, dynamic>{
          'message': <String, dynamic>{'content': content},
        },
      ],
    },
  };

  /// 中文 JSON 必须走 bytes + utf8（`http.Response(String)` 只支持 Latin1）。
  http.Response okJson(Object json) => http.Response.bytes(
    utf8.encode(jsonEncode(json)),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );

  /// order 级折扣单（含字符串数字 + 围栏）。
  String orderLevelContent() => '```json\n${jsonEncode(<String, dynamic>{
    'merchant': '盒马',
    'expense_date': '2026-09-21',
    'subtotal': '54.00',
    'total_discount': '-15.00',
    'amount': '47.00',
    'discount_model': 'order_level',
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': '牛奶',
        'quantity': '2',
        'unit_price': '15.00',
        'amount': '30.00',
        'paid_amount': '30.00',
      },
      <String, dynamic>{
        'name': '面包',
        'quantity': '1',
        'unit_price': '24.00',
        'amount': '24.00',
        'paid_amount': '24.00',
      },
    ],
  })}\n```';

  group('T6-1 真实信封解析', () {
    test('order 级折扣：基数+折扣摊入，paidAmount 存档', () async {
      final AiRecognitionService service = AiRecognitionService(
        config: config,
        client: MockClient((http.Request request) async {
          expect(request.url.path, '/api/v1/chat/completions');
          expect(
            request.headers['Authorization'],
            'Bearer test-key',
          );
          expect(request.headers['x-client-type'], 'cline-cli');
          return okJson(envelopeOf(orderLevelContent()));
        }),
      );
      addTearDown(service.close);
      final AiReceiptDto dto = await service.parseImageBytes(
        image,
        sourceImageIndex: 2,
      );
      expect(dto.merchant, '盒马');
      expect(dto.date, '2026-09-21');
      expect(dto.sourceImageIndex, 2);
      // 3000/2400 基数，-1500 摊入 → 2611/2089。
      expect(
        dto.items.map((AiReceiptItem e) => (e.amount * 100).round()),
        <int>[3000, 2400],
      );
      expect(
        dto.discounts.single.amount,
        -15.0,
      );
      expect(dto.items.first.paidAmount, 30.0);
    });

    test('item 级折扣单无围栏照常解析', () async {
      final AiRecognitionService service = AiRecognitionService(
        config: config,
        client: MockClient((http.Request request) async {
          return okJson(
            envelopeOf(
              jsonEncode(<String, dynamic>{
                'merchant': '店',
                'discount_model': 'item_level',
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'name': '衫',
                    'quantity': 1,
                    'unit_price': 100.0,
                    'amount': 100.0,
                    'paid_amount': 80.0,
                  },
                ],
              }),
            ),
          );
        }),
      );
      addTearDown(service.close);
      final AiReceiptDto dto = await service.parseImageBytes(image);
      expect(dto.items.single.paidAmount, 80.0);
      expect(dto.discounts, isEmpty);
    });
  });

  group('T6-2 类型化异常', () {
    test('缺 key 抛 missingKey', () async {
      final AiRecognitionService service = AiRecognitionService(
        config: const AiConfig(
          baseUrl: 'https://example.test',
          modelId: 'm',
          apiKey: '',
        ),
      );
      addTearDown(service.close);
      await expectLater(
        service.parseImageBytes(image),
        throwsA(
          isA<AiException>().having(
            (AiException e) => e.kind,
            'kind',
            AiFailureKind.missingKey,
          ),
        ),
      );
    });

    test('500 抛 badStatus', () async {
      final AiRecognitionService service = AiRecognitionService(
        config: config,
        client: MockClient((http.Request request) async {
          return http.Response('boom', 500);
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.parseImageBytes(image),
        throwsA(
          isA<AiException>().having(
            (AiException e) => e.kind,
            'kind',
            AiFailureKind.badStatus,
          ),
        ),
      );
    });

    test('超时抛 network', () async {
      final AiRecognitionService service = AiRecognitionService(
        config: config,
        client: MockClient((http.Request request) async {
          await Future<void>.delayed(const Duration(minutes: 2));
          return http.Response('{}', 200);
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.parseImageBytes(image),
        throwsA(
          isA<AiException>().having(
            (AiException e) => e.kind,
            'kind',
            AiFailureKind.network,
          ),
        ),
      );
    }, timeout: const Timeout(Duration(seconds: 150)));

    test('坏信封与空商品抛 badPayload', () async {
      final AiRecognitionService badEnvelope = AiRecognitionService(
        config: config,
        client: MockClient((http.Request request) async {
          return okJson(<String, dynamic>{'oops': 1});
        }),
      );
      addTearDown(badEnvelope.close);
      await expectLater(
        badEnvelope.parseImageBytes(image),
        throwsA(
          isA<AiException>().having(
            (AiException e) => e.kind,
            'kind',
            AiFailureKind.badPayload,
          ),
        ),
      );

      final AiRecognitionService emptyItems = AiRecognitionService(
        config: config,
        client: MockClient((http.Request request) async {
          return okJson(
            envelopeOf(
              jsonEncode(<String, dynamic>{
                'merchant': '空店',
                'items': const <dynamic>[],
              }),
            ),
          );
        }),
      );
      addTearDown(emptyItems.close);
      await expectLater(
        emptyItems.parseImageBytes(image),
        throwsA(isA<AiException>()),
      );
    });

    test('超 10MB 抛 badPayload', () async {
      final AiRecognitionService service = AiRecognitionService(
        config: config,
        client: MockClient((http.Request request) async {
          return http.Response('{}', 200);
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.parseImageBytes(
          Uint8List(AiRecognitionService.maxImageBytes + 1),
        ),
        throwsA(
          isA<AiException>().having(
            (AiException e) => e.kind,
            'kind',
            AiFailureKind.badPayload,
          ),
        ),
      );
    });

    test('500 重试一次后成功', () async {
      int calls = 0;
      final AiRecognitionService service = AiRecognitionService(
        config: config,
        client: MockClient((http.Request request) async {
          calls++;
          if (calls == 1) {
            return http.Response('busy', 500);
          }
          return okJson(
            envelopeOf(
              jsonEncode(<String, dynamic>{
                'merchant': '店',
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'name': '水',
                    'quantity': 1,
                    'unit_price': 200,
                    'amount': 200,
                  },
                ],
              }),
            ),
          );
        }),
      );
      addTearDown(service.close);
      final AiReceiptDto dto = await service.parseImageBytes(image);
      expect(dto.items.single.name, '水');
      expect(calls, 2);
    });

    test('截断 JSON 重试一次后成功', () async {
      int calls = 0;
      final AiRecognitionService service = AiRecognitionService(
        config: config,
        client: MockClient((http.Request request) async {
          calls++;
          if (calls == 1) {
            return okJson(envelopeOf('{"merchant": "店", "sub'));
          }
          return okJson(
            envelopeOf(
              jsonEncode(<String, dynamic>{
                'merchant': '店',
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'name': '水',
                    'quantity': 1,
                    'unit_price': 200,
                    'amount': 200,
                  },
                ],
              }),
            ),
          );
        }),
      );
      addTearDown(service.close);
      final AiReceiptDto dto = await service.parseImageBytes(image);
      expect(dto.merchant, '店');
      expect(calls, 2);
    });

    test('确定性错误不重试（401 一次即抛）', () async {
      int calls = 0;
      final AiRecognitionService service = AiRecognitionService(
        config: config,
        client: MockClient((http.Request request) async {
          calls++;
          return http.Response('unauthorized', 401);
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.parseImageBytes(image),
        throwsA(
          isA<AiException>().having(
            (AiException e) => e.kind,
            'kind',
            AiFailureKind.badStatus,
          ),
        ),
      );
      expect(calls, 1);
    });

    test('数量为 0 抛 badPayload', () async {
      final AiRecognitionService service = AiRecognitionService(
        config: config,
        client: MockClient((http.Request request) async {
          return okJson(
            envelopeOf(
              jsonEncode(<String, dynamic>{
                'merchant': '店',
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'name': '怪货',
                    'quantity': 0,
                    'unit_price': 100,
                    'amount': 100,
                  },
                ],
              }),
            ),
          );
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.parseImageBytes(image),
        throwsA(
          isA<AiException>().having(
            (AiException e) => e.kind,
            'kind',
            AiFailureKind.badPayload,
          ),
        ),
      );
    });
  });
}
