/// ASR 语音识别配置
class AsrConfig {
  /// 提供商类型: 'system'(系统默认) | 'custom'(自定义接入) | 'mimo'(小米MiMo)
  final String providerType;

  /// 自定义服务商 Base URL（如 https://api.groq.com）
  final String? baseUrl;

  /// API Key
  final String? apiKey;

  /// 模型名称（如 whisper-large-v3-turbo）
  final String? model;

  const AsrConfig({
    this.providerType = 'system',
    this.baseUrl,
    this.apiKey,
    this.model,
  });

  /// 是否使用系统默认（后端）接口
  bool get isSystem => providerType == 'system';

  /// 是否使用小米 MiMo
  bool get isMimo => providerType == 'mimo';

  /// 自定义接入是否配置完整
  bool get isCustomReady =>
      providerType == 'custom' &&
      baseUrl != null &&
      baseUrl!.isNotEmpty;

  AsrConfig copyWith({
    String? providerType,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return AsrConfig(
      providerType: providerType ?? this.providerType,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  factory AsrConfig.fromJson(Map<String, dynamic> json) {
    return AsrConfig(
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
