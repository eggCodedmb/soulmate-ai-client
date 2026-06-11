import 'dart:convert';

/// 用户信息
class User {
  final int id;
  final String email;
  final String nickname;
  final String? avatarUrl;
  final int gender;
  final String? birthday;
  final int guestFlag;
  final int status;
  final DateTime? lastLoginTime;
  final DateTime? createTime;
  final DateTime? updateTime;

  const User({
    required this.id,
    required this.email,
    required this.nickname,
    this.avatarUrl,
    this.gender = 0,
    this.birthday,
    this.guestFlag = 0,
    this.status = 1,
    this.lastLoginTime,
    this.createTime,
    this.updateTime,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      gender: (json['gender'] as num?)?.toInt() ?? 0,
      birthday: json['birthday'] as String?,
      guestFlag: (json['guestFlag'] as num?)?.toInt() ?? 0,
      status: (json['status'] as num?)?.toInt() ?? 1,
      lastLoginTime: json['lastLoginTime'] != null
          ? DateTime.parse(json['lastLoginTime'] as String)
          : null,
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.parse(json['updateTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'nickname': nickname,
    'avatarUrl': avatarUrl,
    'gender': gender,
    'birthday': birthday,
    'guestFlag': guestFlag,
    'status': status,
    'lastLoginTime': lastLoginTime?.toIso8601String(),
    'createTime': createTime?.toIso8601String(),
    'updateTime': updateTime?.toIso8601String(),
  };
}

/// 用户资料
class UserProfile {
  final String? personalityType;
  final Map<String, dynamic>? personalityResult;
  final List<String> interests;
  final String? chatStylePref;
  final List<String> topicsBlacklist;

  const UserProfile({
    this.personalityType,
    this.personalityResult,
    this.interests = const [],
    this.chatStylePref,
    this.topicsBlacklist = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      personalityType: json['personalityType'] as String?,
      personalityResult: _parseJsonMap(json['personalityResult']),
      interests: _parseJsonStringList(json['interests']),
      chatStylePref: json['chatStylePref'] as String?,
      topicsBlacklist: _parseJsonStringList(json['topicsBlacklist']),
    );
  }

  Map<String, dynamic> toJson() => {
    'personalityType': personalityType,
    'personalityResult': personalityResult != null
        ? jsonEncode(personalityResult)
        : null,
    'interests': interests.isNotEmpty ? jsonEncode(interests) : null,
    'chatStylePref': chatStylePref,
    'topicsBlacklist':
        topicsBlacklist.isNotEmpty ? jsonEncode(topicsBlacklist) : null,
  };
}

Map<String, dynamic>? _parseJsonMap(dynamic v) {
  if (v == null) return null;
  if (v is Map<String, dynamic>) return v;
  if (v is String && v.isNotEmpty) {
    return jsonDecode(v) as Map<String, dynamic>;
  }
  return null;
}

List<String> _parseJsonStringList(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => e.toString()).toList();
  if (v is String && v.isNotEmpty) {
    return List<String>.from(jsonDecode(v) as List);
  }
  return [];
}

/// 用户设置
class UserSettings {
  final int darkMode;
  final String fontSize;
  final String language;
  final int messageNotify;
  final int proactiveCare;
  final String? modelBaseUrl;
  final String? modelName;

  /// LLM 模型配置
  final String? llmProviderType;
  final String? llmBaseUrl;
  final String? llmApiKey;
  final String? llmModel;

  const UserSettings({
    this.darkMode = 0,
    this.fontSize = 'normal',
    this.language = 'zh-CN',
    this.messageNotify = 1,
    this.proactiveCare = 1,
    this.modelBaseUrl,
    this.modelName,
    this.llmProviderType,
    this.llmBaseUrl,
    this.llmApiKey,
    this.llmModel,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      darkMode: (json['darkMode'] as num?)?.toInt() ?? 0,
      fontSize: json['fontSize'] as String? ?? 'normal',
      language: json['language'] as String? ?? 'zh-CN',
      messageNotify: (json['messageNotify'] as num?)?.toInt() ?? 1,
      proactiveCare: (json['proactiveCare'] as num?)?.toInt() ?? 1,
      modelBaseUrl: json['modelBaseUrl'] as String?,
      modelName: json['modelName'] as String?,
      llmProviderType: json['llmProviderType'] as String?,
      llmBaseUrl: json['llmBaseUrl'] as String?,
      llmApiKey: json['llmApiKey'] as String?,
      llmModel: json['llmModel'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'darkMode': darkMode,
    'fontSize': fontSize,
    'language': language,
    'messageNotify': messageNotify,
    'proactiveCare': proactiveCare,
    'modelBaseUrl': modelBaseUrl,
    'modelName': modelName,
    'llmProviderType': llmProviderType,
    'llmBaseUrl': llmBaseUrl,
    'llmApiKey': llmApiKey,
    'llmModel': llmModel,
  };
}
