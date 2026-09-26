import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';
import 'ai_config.dart';
import '../domain/ai_prompt.dart';
import '../domain/ai_receipt_dto.dart';

/// 本地收据解析器（`source: local` 占位，后续本地 OCR 实现此接口）。
///
/// 当前恒返回 null，调用方继续降级到手动填写。
abstract class LocalReceiptParser {
  Future<AiReceiptDto?> parse(Uint8List imageBytes);
}

/// AI 账单识别服务（Cline 兼容 `/chat/completions`）。
///
/// 失败一律抛 [AiException]（分 kind），调用方按
/// AI → 本地解析 → 手动填写顺序降级。
class AiRecognitionService {
  AiRecognitionService({required this.config, http.Client? client})
    : _client = client ?? http.Client();

  final AiConfig config;
  final http.Client _client;

  static const int maxImageBytes = 10 * 1024 * 1024;
  static const Duration timeout = Duration(seconds: 60);

  /// 解析图片文件。
  Future<AiReceiptDto> parseImageFile(
    File file, {
    int sourceImageIndex = 0,
  }) => parseImageBytes(
    file.readAsBytesSync(),
    mime: _mimeOf(file.path),
    sourceImageIndex: sourceImageIndex,
  );

  /// 解析图片字节。
  Future<AiReceiptDto> parseImageBytes(
    Uint8List bytes, {
    String mime = 'image/jpeg',
    int sourceImageIndex = 0,
  }) async {
    config.requireConfigured();
    if (bytes.lengthInBytes > maxImageBytes) {
      throw const AiException(
        AiFailureKind.badPayload,
        '图片超过 10MB 上限',
      );
    }
    final String base64Image = base64Encode(bytes);
    final Map<String, dynamic> body = <String, dynamic>{
      'model': config.modelId,
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{'role': 'system', 'content': kReceiptSystemPrompt},
        <String, dynamic>{
          'role': 'user',
          'content': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'text',
              'text': 'Parse this receipt. Find the 实付/应付合计 amount.',
            },
            <String, dynamic>{
              'type': 'image_url',
              'image_url': <String, dynamic>{
                'url': 'data:$mime;base64,$base64Image',
              },
            },
          ],
        },
      ],
      'temperature': 0.1,
      'max_tokens': 2048,
    };
    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${config.baseUrl}/chat/completions'),
            headers: <String, String>{
              'Authorization': 'Bearer ${config.apiKey}',
              'Content-Type': 'application/json',
              'x-client-type': 'cline-cli',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException(AiFailureKind.network, 'AI 请求超时（60s）');
    } on SocketException catch (e) {
      throw AiException(AiFailureKind.network, 'AI 网络异常：$e');
    } on http.ClientException catch (e) {
      throw AiException(AiFailureKind.network, 'AI 网络异常：$e');
    }
    if (response.statusCode != 200) {
      throw AiException(
        AiFailureKind.badStatus,
        'AI 服务返回 ${response.statusCode}：${response.body}',
      );
    }
    try {
      final Map<String, dynamic> envelope =
          jsonDecode(response.body) as Map<String, dynamic>;
      final String content = _extractContent(envelope);
      final Map<String, dynamic> data =
          jsonDecode(_stripFences(content)) as Map<String, dynamic>;
      final AiReceiptDto dto = aiReceiptDtoFromPythonJson(
        data,
        sourceImageIndex: sourceImageIndex,
      );
      if (dto.items.isEmpty) {
        throw const AiException(AiFailureKind.badPayload, 'AI 识别结果无商品');
      }
      return dto;
    } on AiException {
      rethrow;
    } on FormatException catch (e) {
      throw AiException(AiFailureKind.badPayload, 'AI 响应 JSON 非法：$e');
    }
  }

  /// 提取 Cline 信封 `data.choices[0].message.content`。
  String _extractContent(Map<String, dynamic> envelope) {
    try {
      final Map<String, dynamic> data =
          envelope['data'] as Map<String, dynamic>;
      final List<dynamic> choices = data['choices'] as List<dynamic>;
      final Map<String, dynamic> message =
          (choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>;
      final String? content = message['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw const AiException(AiFailureKind.badPayload, 'AI 响应内容为空');
      }
      return content;
    } on AiException {
      rethrow;
    } catch (e) {
      throw AiException(AiFailureKind.badPayload, 'AI 响应信封非法：$e');
    }
  }

  /// 去 markdown 围栏。
  String _stripFences(String content) {
    if (content.contains('```json')) {
      return content.split('```json')[1].split('```')[0];
    }
    if (content.contains('```')) {
      return content.split('```')[1].split('```')[0];
    }
    return content;
  }

  void close() => _client.close();
}

/// Python 结构 → Dart DTO 映射（Dart DTO 口径）。
///
/// - `items[].amount`（折扣前小计）→ 基数；`total_discount`（负）→ 折扣数组；
/// - `surcharges` 置空；`paid_amount` 只存档；字符串数字兼容。
AiReceiptDto aiReceiptDtoFromPythonJson(
  Map<String, dynamic> json, {
  int sourceImageIndex = 0,
}) {
  num? toNum(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value;
    }
    return num.tryParse(value.toString());
  }

  final List<dynamic>? items = json['items'] as List<dynamic>?;
  if (items == null || items.isEmpty) {
    throw const AiException(AiFailureKind.badPayload, 'AI 识别结果无商品');
  }
  final num? totalDiscount = toNum(json['total_discount']);
  return AiReceiptDto(
    sourceImageIndex: sourceImageIndex,
    merchant: json['merchant']?.toString(),
    date: json['expense_date']?.toString(),
    items: <AiReceiptItem>[
      for (final dynamic raw in items)
        AiReceiptItem(
          name: (raw as Map<String, dynamic>)['name'].toString(),
          quantity: toNum(raw['quantity']) ?? 1,
          unitPrice:
              toNum(raw['unit_price']) ?? toNum(raw['amount']) ?? 0,
          amount: toNum(raw['amount']) ?? 0,
          paidAmount: toNum(raw['paid_amount']),
        ),
    ],
    discounts: <AiAdjustment>[
      if (totalDiscount != null && totalDiscount != 0)
        AiAdjustment(name: 'AI订单折扣', amount: totalDiscount),
    ],
  );
}

String _mimeOf(String path) {
  final String lower = path.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
