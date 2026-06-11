/// LLM 大语言模型配置
class LlmConfig {
  /// 提供商类型: 'system'(系统默认) | 'openai'(OpenAI 协议，兼容 Ollama 等)
  final String providerType;

  /// Base URL（如 https://api.openai.com/v1 或 http://localhost:11434/v1）
  final String? baseUrl;

  /// API Key（Ollama 等本地模型可留空）
  final String? apiKey;

  /// 模型名称（如 gpt-4o、deepseek-chat、qwen2.5:7b 等）
  final String? model;

  const LlmConfig({
    this.providerType = 'system',
    this.baseUrl,
    this.apiKey,
    this.model,
  });

  /// 是否使用系统默认（后端内置模型）
  bool get isSystem => providerType == 'system';

  /// 是否使用 OpenAI 协议（含 Ollama 等兼容实现）
  bool get isOpenAi => providerType == 'openai';

  /// OpenAI 协议配置是否完整（只需 baseUrl，apiKey 可选）
  bool get isOpenAiReady =>
      providerType == 'openai' &&
      baseUrl != null &&
      baseUrl!.isNotEmpty;

  /// 配置是否可用
  bool get isConfigured => isSystem || isOpenAiReady;

  LlmConfig copyWith({
    String? providerType,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return LlmConfig(
      providerType: providerType ?? this.providerType,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  factory LlmConfig.fromJson(Map<String, dynamic> json) {
    return LlmConfig(
      providerType: json['providerType'] as String? ?? 'system',
      baseUrl: json['baseUrl'] as String?,
      apiKey: json['apiKey'] as String?,
      model: json['model'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'providerType': providerType,
      if (baseUrl != null) 'baseUrl': baseUrl,
      if (apiKey != null) 'apiKey': apiKey,
      if (model != null) 'model': model,
    };
  }
}
