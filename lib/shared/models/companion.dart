/// AI伴侣
class Companion {
  final int id;
  final int userId;
  final String name;
  final int gender;
  final String relationshipType;
  final String? description;
  final String speakingStyle;
  final String? avatarUrl;
  final String? themeColor;
  final int status;
  final int companionOrder;
  final List<String> personalityKeys;
  final DateTime? createTime;
  final DateTime? updateTime;

  const Companion({
    required this.id,
    required this.userId,
    required this.name,
    required this.gender,
    required this.relationshipType,
    this.description,
    this.speakingStyle = 'casual',
    this.avatarUrl,
    this.themeColor,
    this.status = 1,
    this.companionOrder = 0,
    this.personalityKeys = const [],
    this.createTime,
    this.updateTime,
  });

  factory Companion.fromJson(Map<String, dynamic> json) {
    return Companion(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      name: json['name'] as String? ?? '',
      gender: (json['gender'] as num?)?.toInt() ?? 0,
      relationshipType: json['relationshipType'] as String? ?? '',
      description: json['description'] as String?,
      speakingStyle: json['speakingStyle'] as String? ?? 'casual',
      avatarUrl: json['avatarUrl'] as String?,
      themeColor: json['themeColor'] as String?,
      status: (json['status'] as num?)?.toInt() ?? 1,
      companionOrder: (json['companionOrder'] as num?)?.toInt() ?? 0,
      personalityKeys: (json['personalityKeys'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
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
    'userId': userId,
    'name': name,
    'gender': gender,
    'relationshipType': relationshipType,
    'description': description,
    'speakingStyle': speakingStyle,
    'avatarUrl': avatarUrl,
    'themeColor': themeColor,
    'status': status,
    'companionOrder': companionOrder,
    'personalityKeys': personalityKeys,
    'createTime': createTime?.toIso8601String(),
    'updateTime': updateTime?.toIso8601String(),
  };
}
