/// AI伴侣定时提醒模型
class Reminder {
  final int id;
  final int userId;
  final int companionId;
  final String? companionName;
  final String? companionAvatarUrl;
  final String reminderTime; // "HH:mm"
  final String repeatDays; // "1,2,3,4,5" etc.
  final String textTemplate;
  final String type; // "WAKE_UP" or "NOTIFICATION"
  final int enabled; // 1=启用, 0=停用
  final DateTime? createTime;
  final DateTime? updateTime;

  const Reminder({
    required this.id,
    required this.userId,
    required this.companionId,
    required this.reminderTime,
    required this.textTemplate,
    required this.type,
    this.companionName,
    this.companionAvatarUrl,
    this.repeatDays = '',
    this.enabled = 1,
    this.createTime,
    this.updateTime,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      companionId: (json['companionId'] as num).toInt(),
      companionName: json['companionName'] as String?,
      companionAvatarUrl: json['companionAvatarUrl'] as String?,
      reminderTime: json['reminderTime'] as String? ?? '08:00',
      repeatDays: json['repeatDays'] as String? ?? '',
      textTemplate: json['textTemplate'] as String? ?? '',
      type: json['type'] as String? ?? 'WAKE_UP',
      enabled: (json['enabled'] as num?)?.toInt() ?? 1,
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
    'companionId': companionId,
    'companionName': companionName,
    'companionAvatarUrl': companionAvatarUrl,
    'reminderTime': reminderTime,
    'repeatDays': repeatDays,
    'textTemplate': textTemplate,
    'type': type,
    'enabled': enabled,
    'createTime': createTime?.toIso8601String(),
    'updateTime': updateTime?.toIso8601String(),
  };

  Reminder copyWith({
    int? id,
    int? userId,
    int? companionId,
    String? companionName,
    String? companionAvatarUrl,
    String? reminderTime,
    String? repeatDays,
    String? textTemplate,
    String? type,
    int? enabled,
    DateTime? createTime,
    DateTime? updateTime,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companionId: companionId ?? this.companionId,
      companionName: companionName ?? this.companionName,
      companionAvatarUrl: companionAvatarUrl ?? this.companionAvatarUrl,
      reminderTime: reminderTime ?? this.reminderTime,
      repeatDays: repeatDays ?? this.repeatDays,
      textTemplate: textTemplate ?? this.textTemplate,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }
}
