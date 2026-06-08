/// 对话会话
class Conversation {
  final int id;
  final int userId;
  final int companionId;
  final String sceneMode;
  final String? lastMessagePreview;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final int pinned;
  final int contextWindow;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int companionReplyCount;

  const Conversation({
    required this.id,
    required this.userId,
    required this.companionId,
    this.sceneMode = 'daily',
    this.lastMessagePreview,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.pinned = 0,
    this.contextWindow = 50,
    this.createTime,
    this.updateTime,
    this.companionReplyCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      companionId: (json['companionId'] as num).toInt(),
      sceneMode: json['sceneMode'] as String? ?? 'daily',
      lastMessagePreview: json['lastMessagePreview'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'] as String)
          : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      pinned: (json['pinned'] as num?)?.toInt() ?? 0,
      contextWindow: (json['contextWindow'] as num?)?.toInt() ?? 50,
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.parse(json['updateTime'] as String)
          : null,
      companionReplyCount: (json['companionReplyCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'companionId': companionId,
    'sceneMode': sceneMode,
    'lastMessagePreview': lastMessagePreview,
    'lastMessageTime': lastMessageTime?.toIso8601String(),
    'unreadCount': unreadCount,
    'pinned': pinned,
    'contextWindow': contextWindow,
    'createTime': createTime?.toIso8601String(),
    'updateTime': updateTime?.toIso8601String(),
    'companionReplyCount': companionReplyCount,
  };
}
