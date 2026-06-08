/// TTS（文字转语音）相关数据模型
///
/// 包含声音配置、声音档案、TTS生成请求等模型

/// TTS 配置 - 存储在伴侣上的 TTS 参数
class TtsConfig {
  /// 声音档案 ID（来自 TTS 服务器的 /profiles）
  final String? profileId;

  /// 声音档案名称（缓存，用于离线显示）
  final String? profileName;

  /// 声音语言
  final String language;

  /// TTS 引擎（如 qwen）
  final String? engine;

  /// 模型大小（如 1.7B）
  final String? modelSize;

  /// 语音指导指令
  final String? instruct;

  /// 是否启用个性语音
  final bool personality;

  /// 种子值（用于生成一致性）
  final int seed;

  /// 是否启用 TTS
  final bool enabled;

  /// 音效链
  final List<EffectsChainItem>? effectsChain;

  TtsConfig({
    this.profileId,
    this.profileName,
    this.language = 'zh',
    this.engine,
    this.modelSize,
    this.instruct,
    this.personality = false,
    this.seed = 0,
    this.enabled = false,
    this.effectsChain,
  });

  factory TtsConfig.fromJson(Map<String, dynamic> json) {
    return TtsConfig(
      profileId: json['profileId'] as String?,
      profileName: json['profileName'] as String?,
      language: json['language'] as String? ?? 'zh',
      engine: json['engine'] as String?,
      modelSize: json['modelSize'] as String?,
      instruct: json['instruct'] as String?,
      personality: json['personality'] as bool? ?? false,
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? false,
      effectsChain: (json['effectsChain'] as List<dynamic>?)
          ?.map((e) => EffectsChainItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (profileId != null) 'profileId': profileId,
        if (profileName != null) 'profileName': profileName,
        'language': language,
        if (engine != null) 'engine': engine,
        if (modelSize != null) 'modelSize': modelSize,
        if (instruct != null) 'instruct': instruct,
        'personality': personality,
        'seed': seed,
        'enabled': enabled,
        if (effectsChain != null)
          'effectsChain': effectsChain!.map((e) => e.toJson()).toList(),
      };

  /// 创建一个副本并覆盖部分字段
  TtsConfig copyWith({
    String? profileId,
    String? profileName,
    String? language,
    String? engine,
    String? modelSize,
    String? instruct,
    bool? personality,
    int? seed,
    bool? enabled,
    List<EffectsChainItem>? effectsChain,
  }) {
    return TtsConfig(
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
      language: language ?? this.language,
      engine: engine ?? this.engine,
      modelSize: modelSize ?? this.modelSize,
      instruct: instruct ?? this.instruct,
      personality: personality ?? this.personality,
      seed: seed ?? this.seed,
      enabled: enabled ?? this.enabled,
      effectsChain: effectsChain ?? this.effectsChain,
    );
  }
}

/// 音效链条目
class EffectsChainItem {
  final String type;
  final bool enabled;
  final Map<String, dynamic>? params;

  EffectsChainItem({
    required this.type,
    this.enabled = true,
    this.params,
  });

  factory EffectsChainItem.fromJson(Map<String, dynamic> json) {
    return EffectsChainItem(
      type: json['type'] as String,
      enabled: json['enabled'] as bool? ?? true,
      params: json['params'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'enabled': enabled,
        if (params != null) 'params': params,
      };
}

/// 声音档案 - 来自 TTS 服务器 GET /profiles
class VoiceProfile {
  final String id;
  final String name;
  final String? description;
  final String language;
  final String? avatarPath;
  final String voiceType;
  final String? presetEngine;
  final String? presetVoiceId;
  final String? designPrompt;
  final String defaultEngine;
  final String? personality;
  final int generationCount;
  final int sampleCount;
  final String createdAt;
  final String updatedAt;

  VoiceProfile({
    required this.id,
    required this.name,
    this.description,
    required this.language,
    this.avatarPath,
    required this.voiceType,
    this.presetEngine,
    this.presetVoiceId,
    this.designPrompt,
    required this.defaultEngine,
    this.personality,
    this.generationCount = 0,
    this.sampleCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VoiceProfile.fromJson(Map<String, dynamic> json) {
    return VoiceProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      language: json['language'] as String? ?? 'zh',
      avatarPath: json['avatar_path'] as String?,
      voiceType: json['voice_type'] as String? ?? 'preset',
      presetEngine: json['preset_engine'] as String?,
      presetVoiceId: json['preset_voice_id'] as String?,
      designPrompt: json['design_prompt'] as String?,
      defaultEngine: json['default_engine'] as String? ?? 'qwen',
      personality: json['personality'] as String?,
      generationCount: (json['generation_count'] as num?)?.toInt() ?? 0,
      sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  /// 声音类型显示文本
  String get voiceTypeLabel {
    switch (voiceType) {
      case 'cloned':
        return '克隆声音';
      case 'preset':
        return '预设声音';
      case 'designed':
        return 'AI设计';
      default:
        return voiceType;
    }
  }
}

/// TTS 生成请求 - POST /generate
class TtsGenerateRequest {
  final String profileId;
  final String text;
  final String language;
  final int seed;
  final String? modelSize;
  final String? instruct;
  final String engine;
  final bool personality;
  final int maxChunkChars;
  final int crossfadeMs;
  final bool normalize;
  final List<EffectsChainItem>? effectsChain;

  TtsGenerateRequest({
    required this.profileId,
    required this.text,
    this.language = 'zh',
    this.seed = 0,
    this.modelSize,
    this.instruct,
    this.engine = 'qwen',
    this.personality = false,
    this.maxChunkChars = 800,
    this.crossfadeMs = 50,
    this.normalize = true,
    this.effectsChain,
  });

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'text': text,
        'language': language,
        'seed': seed,
        if (modelSize != null) 'model_size': modelSize,
        if (instruct != null) 'instruct': instruct,
        'engine': engine,
        'personality': personality,
        'max_chunk_chars': maxChunkChars,
        'crossfade_ms': crossfadeMs,
        'normalize': normalize,
        if (effectsChain != null)
          'effects_chain': effectsChain!.map((e) => e.toJson()).toList(),
      };
}

/// 从 TtsConfig 和文本内容构建 TtsGenerateRequest
TtsGenerateRequest buildTtsRequest(TtsConfig config, String text) {
  return TtsGenerateRequest(
    profileId: config.profileId!,
    text: text,
    language: config.language,
    seed: config.seed,
    modelSize: config.modelSize,
    instruct: config.instruct,
    engine: config.engine ?? 'qwen',
    personality: config.personality,
    effectsChain: config.effectsChain,
  );
}
