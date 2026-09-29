import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:openai_dart/openai_dart.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/ai_prompt.dart';
import '../domain/ai_receipt_dto.dart';
import 'ai_config.dart';
import 'ai_recognition_service.dart'
    show aiReceiptDtoFromPythonJson, logAiParseSummary;

/// 标准 OpenAI 兼容接口识别服务（基础版）。
///
/// 与 Cline 手写轨（[`AiRecognitionService`]，私有 `data.choices` 信封 +
/// `x-client-type` 头）并存：标准站走本类（`openai_dart` 类型化调用，
/// 无私有头），Cline 站走手写轨。DTO 映射与 10MB/超时口径两轨一致。
class StandardRecognitionService {
  StandardRecognitionService({required this.config, OpenAIClient? client})
    : _client =
          client ??
          OpenAIClient(
            config: OpenAIConfig(
              authProvider: ApiKeyProvider(config.apiKey),
              baseUrl: config.baseUrl,
              timeout: timeout,
            ),
          ),
      _ownsClient = client == null;

  final AiConfig config;
  final OpenAIClient _client;
  final bool _ownsClient;

  static const int maxImageBytes = 10 * 1024 * 1024;
  static const Duration timeout = Duration(seconds: 60);

  /// 解析图片字节。
  Future<AiReceiptDto> parseImageBytes(
    Uint8List bytes, {
    String mime = 'image/jpeg',
    int sourceImageIndex = 0,
  }) async {
    config.requireConfigured();
    if (bytes.lengthInBytes > maxImageBytes) {
      throw const AiException(AiFailureKind.badPayload, '图片超过 10MB 上限');
    }
    final Stopwatch sw = Stopwatch()..start();
    final result = await _parseOnce(
      bytes,
      mime: mime,
      sourceImageIndex: sourceImageIndex,
    );
    logAiParseSummary(
      model: config.modelId,
      ms: sw.elapsedMilliseconds,
      dto: result.dto,
      rawBytes: result.rawBytes,
    );
    return result.dto;
  }

  Future<({AiReceiptDto dto, int rawBytes})> _parseOnce(
    Uint8List bytes, {
    required String mime,
    required int sourceImageIndex,
  }) async {
    final String base64Image = base64Encode(bytes);
    late final ChatCompletion response;
    try {
      response = await _client.chat.completions
          .create(
            ChatCompletionCreateRequest(
              model: config.modelId,
              messages: <ChatMessage>[
                ChatMessage.system(kReceiptSystemPrompt),
                ChatMessage.user(<ContentPart>[
                  ContentPart.text(kReceiptUserPrompt),
                  ContentPart.imageUrl('data:$mime;base64,$base64Image'),
                ]),
              ],
              temperature: 0.1,
              maxTokens: 2048,
            ),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException(AiFailureKind.network, 'AI 请求超时（60s）');
    } on ApiException catch (e) {
      throw AiException(
        AiFailureKind.badStatus,
        'AI 服务返回 ${e.statusCode}：${e.message}',
      );
    } on OpenAIException catch (e) {
      throw AiException(AiFailureKind.network, 'AI 网络异常：$e');
    }
    final String content = response.text?.trim() ?? '';
    if (content.isEmpty) {
      throw const AiException(AiFailureKind.badPayload, 'AI 响应内容为空');
    }
    try {
      final String stripped = _stripFences(content);
      final Map<String, dynamic> data =
          jsonDecode(stripped) as Map<String, dynamic>;
      final AiReceiptDto dto = aiReceiptDtoFromPythonJson(
        data,
        sourceImageIndex: sourceImageIndex,
      );
      if (dto.items.isEmpty) {
        throw const AiException(AiFailureKind.badPayload, 'AI 识别结果无商品');
      }
      return (dto: dto, rawBytes: content.length);
    } on AiException {
      rethrow;
    } on FormatException catch (e) {
      final String oneLine = content.replaceAll(RegExp(r'\s+'), ' ');
      final String snippet = oneLine.length <= 200
          ? oneLine
          : oneLine.substring(0, 200);
      throw AiException(
        AiFailureKind.badPayload,
        'AI 响应 JSON 非法：$e；原文前 200 字：$snippet',
      );
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

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
