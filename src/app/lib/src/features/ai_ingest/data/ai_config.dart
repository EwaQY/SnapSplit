import '../../../core/errors/app_exception.dart';

/// AI 配置（Cline 兼容接口）。
class AiConfig {
  const AiConfig({
    required this.baseUrl,
    required this.modelId,
    required this.apiKey,
  });

  final String baseUrl;
  final String modelId;
  final String apiKey;

  static const String defaultBaseUrl = 'https://api.cline.bot/api/v1';

  /// 是否配齐调用条件。
  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// 从键值表构造（测试/探针用，不读环境）。
  factory AiConfig.fromMap(Map<String, String> env) => AiConfig(
    baseUrl:
        env['base_url']?.trim().isNotEmpty == true
            ? env['base_url']!.trim()
            : defaultBaseUrl,
    modelId: (env['model_id'] ?? '').trim(),
    apiKey: (env['api_key'] ?? '').trim(),
  );

  void requireConfigured() {
    if (!isConfigured) {
      throw const AiException(
        AiFailureKind.missingKey,
        '未配置 AI api_key（见 src/app/.env.example）',
      );
    }
  }
}
