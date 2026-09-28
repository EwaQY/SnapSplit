import '../../../core/errors/app_exception.dart';

/// AI 接入点硬编码（文件顶部常量，打真站只换这里或调函数传参）。
const String defaultAiBaseUrl = 'https://api.cline.bot/api/v1';

/// 默认模型（换模型只改这行，或调 [loadAiConfig] 传参覆盖）。
const String defaultAiModelId = '';

/// 默认 Key 占位（永不填真值；打真站调 [loadAiConfig] 传参覆盖，不落盘）。
const String defaultAiApiKey = 'YOUR_API_KEY';

/// Cline 私有头（只有打 api.cline.bot 才传，标准站传空）。
const Map<String, String> kClineClientHeaders = <String, String>{
  'x-client-type': 'cline-cli',
};

/// 读取调用配置：默认走顶部常量，调用方传参覆盖（切模型/换站/填 key/加头）。
AiConfig loadAiConfig({
  String? baseUrl,
  String? modelId,
  String? apiKey,
  Map<String, String>? extraHeaders,
}) => AiConfig(
  baseUrl: baseUrl ?? defaultAiBaseUrl,
  modelId: modelId ?? defaultAiModelId,
  apiKey: apiKey ?? defaultAiApiKey,
  extraHeaders: extraHeaders ?? const <String, String>{},
);

/// AI 配置（Cline 兼容接口）。
class AiConfig {
  const AiConfig({
    required this.baseUrl,
    required this.modelId,
    required this.apiKey,
    this.extraHeaders = const <String, String>{},
  });

  final String baseUrl;
  final String modelId;
  final String apiKey;

  /// 厂商私有头（如 Cline 的 x-client-type），标准站留空。
  final Map<String, String> extraHeaders;

  /// 是否配齐调用条件（占位符视为未配置）。
  bool get isConfigured =>
      apiKey.trim().isNotEmpty && apiKey.trim() != defaultAiApiKey;

  void requireConfigured() {
    if (!isConfigured) {
      throw const AiException(
        AiFailureKind.missingKey,
        '未配置 AI api_key（调 loadAiConfig 传参覆盖，不落盘不提交）',
      );
    }
  }
}
