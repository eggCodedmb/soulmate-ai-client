import 'package:shared_preferences/shared_preferences.dart';

/// 本地存储服务 - 存储用户偏好设置、简单配置
class LocalStorage {
  static late SharedPreferences _prefs;

  /// 初始化
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ==================== 用户偏好 ====================

  /// 主题模式
  static String get themeMode => _prefs.getString('theme_mode') ?? 'system';
  static Future<void> setThemeMode(String mode) async {
    await _prefs.setString('theme_mode', mode);
  }

  /// 语言
  static String get language => _prefs.getString('language') ?? 'zh-CN';
  static Future<void> setLanguage(String lang) async {
    await _prefs.setString('language', lang);
  }

  /// 字体大小
  static String get fontSize => _prefs.getString('font_size') ?? 'normal';
  static Future<void> setFontSize(String size) async {
    await _prefs.setString('font_size', size);
  }

  // ==================== 启动状态 ====================

  /// 是否首次启动
  static bool get isFirstLaunch => _prefs.getBool('first_launch') ?? true;
  static Future<void> setFirstLaunch(bool value) async {
    await _prefs.setBool('first_launch', value);
  }

  /// 是否完成引导
  static bool get onboardingCompleted =>
      _prefs.getBool('onboarding_completed') ?? false;
  static Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool('onboarding_completed', value);
  }

  /// 用户昵称
  static String? get nickname => _prefs.getString('nickname');
  static Future<void> setNickname(String value) async {
    await _prefs.setString('nickname', value);
  }

  // ==================== 通知设置 ====================

  /// 消息通知
  static bool get messageNotify => _prefs.getBool('message_notify') ?? true;
  static Future<void> setMessageNotify(bool value) async {
    await _prefs.setBool('message_notify', value);
  }

  /// 主动关心
  static bool get proactiveCare => _prefs.getBool('proactive_care') ?? true;
  static Future<void> setProactiveCare(bool value) async {
    await _prefs.setBool('proactive_care', value);
  }

  // ==================== 模型配置 ====================

  /// 模型Base URL
  static String? get modelBaseUrl => _prefs.getString('model_base_url');
  static Future<void> setModelBaseUrl(String? url) async {
    if (url != null) {
      await _prefs.setString('model_base_url', url);
    } else {
      await _prefs.remove('model_base_url');
    }
  }

  /// 模型名称
  static String? get modelName => _prefs.getString('model_name');
  static Future<void> setModelName(String? name) async {
    if (name != null) {
      await _prefs.setString('model_name', name);
    } else {
      await _prefs.remove('model_name');
    }
  }

  // ==================== TTS 配置 ====================

  /// TTS 服务器 Base URL
  static String? get ttsBaseUrl => _prefs.getString('tts_base_url');
  static Future<void> setTtsBaseUrl(String? url) async {
    if (url != null && url.isNotEmpty) {
      await _prefs.setString('tts_base_url', url);
    } else {
      await _prefs.remove('tts_base_url');
    }
  }

  /// TTS 全局默认声音档案 ID
  static String? get ttsGlobalProfileId => _prefs.getString('tts_global_profile_id');
  static Future<void> setTtsGlobalProfileId(String? id) async {
    if (id != null && id.isNotEmpty) {
      await _prefs.setString('tts_global_profile_id', id);
    } else {
      await _prefs.remove('tts_global_profile_id');
    }
  }

  /// TTS 全局默认声音档案名称（缓存显示用）
  static String? get ttsGlobalProfileName => _prefs.getString('tts_global_profile_name');
  static Future<void> setTtsGlobalProfileName(String? name) async {
    if (name != null && name.isNotEmpty) {
      await _prefs.setString('tts_global_profile_name', name);
    } else {
      await _prefs.remove('tts_global_profile_name');
    }
  }

  /// TTS 全局默认语言
  static String get ttsGlobalLanguage => _prefs.getString('tts_global_language') ?? 'zh';
  static Future<void> setTtsGlobalLanguage(String lang) async {
    await _prefs.setString('tts_global_language', lang);
  }

  /// TTS 全局默认引擎
  static String get ttsGlobalEngine => _prefs.getString('tts_global_engine') ?? 'qwen';
  static Future<void> setTtsGlobalEngine(String engine) async {
    await _prefs.setString('tts_global_engine', engine);
  }

  // ==================== 通用方法 ====================

  /// 获取字符串
  static String? getString(String key) => _prefs.getString(key);

  /// 设置字符串
  static Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  /// 获取布尔值
  static bool? getBool(String key) => _prefs.getBool(key);

  /// 设置布尔值
  static Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  /// 获取整数
  static int? getInt(String key) => _prefs.getInt(key);

  /// 设置整数
  static Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  /// 清除所有数据
  static Future<void> clearAll() async {
    await _prefs.clear();
  }
}
