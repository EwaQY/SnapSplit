import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openai_dart/openai_dart.dart';

import 'package:snap_split/src/core/errors/app_exception.dart';
import 'package:snap_split/src/features/ai_ingest/data/ai_config.dart';
import 'package:snap_split/src/features/ai_ingest/data/standard_recognition_service.dart';
import 'package:snap_split/src/features/ai_ingest/domain/ai_receipt_dto.dart';

/// 标准轨（openai_dart）：MockClient 注入，零网络零真实 key。
void main() {
  const AiConfig config = AiConfig(
    baseUrl: 'https://example.test/v1',
    modelId: 'test-model',
    apiKey: 'test-key',
  );
  final Uint8List image = Uint8List.fromList(<int>[1, 2, 3]);

  /// 标准 OpenAI 信封（顶层 choices，无 data 包裹、无私有头）。
  Map<String, dynamic> standardEnvelope(String content) => <String, dynamic>{
    'id': 'chatcmpl-test',
    'object': 'chat.completion',
    'created': 1720000000,
    'model': 'test-model',
    'choices': <Map<String, dynamic>>[
      <String, dynamic>{
        'index': 0,
        'message': <String, dynamic>{'role': 'assistant', 'content': content},
        'finish_reason': 'stop',
      },
    ],
  };

  http.Response okJson(Object json) => http.Response.bytes(
    utf8.encode(jsonEncode(json)),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );

  OpenAIClient clientOf(MockClient fn) => OpenAIClient(
    config: OpenAIConfig(
      authProvider: ApiKeyProvider('test-key'),
      baseUrl: 'https://example.test/v1',
    ),
    httpClient: fn,
  );

  String receiptContent() => jsonEncode(<String, dynamic>{
    'merchant': '盒马',
    'expense_date': '2026-09-21',
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
  });

  group('标准轨基础版', () {
    test('标准信封解析成功，无私有头', () async {
      final StandardRecognitionService service = StandardRecognitionService(
        config: config,
        client: clientOf(
          MockClient((http.Request request) async {
            expect(request.headers.containsKey('x-client-type'), isFalse);
            expect(
              request.headers['Authorization'],
              'Bearer test-key',
            );
            return okJson(standardEnvelope(receiptContent()));
          }),
        ),
      );
      addTearDown(service.close);
      final AiReceiptDto dto = await service.parseImageBytes(image);
      expect(dto.merchant, '盒马');
      expect(dto.items, hasLength(2));
      expect(dto.discounts.single.amount, -15.0);
    });

    test('缺 key 抛 missingKey', () async {
      final StandardRecognitionService service = StandardRecognitionService(
        config: const AiConfig(
          baseUrl: 'https://example.test/v1',
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

    test('超 10MB 抛 badPayload（不发请求）', () async {
      int calls = 0;
      final StandardRecognitionService service = StandardRecognitionService(
        config: config,
        client: clientOf(
          MockClient((http.Request request) async {
            calls++;
            return http.Response('{}', 200);
          }),
        ),
      );
      addTearDown(service.close);
      await expectLater(
        service.parseImageBytes(
          Uint8List(StandardRecognitionService.maxImageBytes + 1),
        ),
        throwsA(
          isA<AiException>().having(
            (AiException e) => e.kind,
            'kind',
            AiFailureKind.badPayload,
          ),
        ),
      );
      expect(calls, 0);
    });
  });
}
