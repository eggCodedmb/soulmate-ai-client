/// 长期记忆
class Memory {
  final int id;
  final int userId;
  final int companionId;
  final String category;
  final String title;
  final String content;
  final String? thought;
  final String? emotion;
  final int? sourceMessageId;
  final int importance;
  final String? vectorId;
  final int accessCount;
  final DateTime? lastAccessTime;
  final int userVisible;
  final int userEdited;
  final DateTime? createTime;
  final DateTime? updateTime;

  const Memory({
    required this.id,
    required this.userId,
    required this.companionId,
    required this.category,
    required this.title,
    required this.content,
    this.thought,
    this.emotion,
    this.sourceMessageId,
    this.importance = 5,
    this.vectorId,
    this.accessCount = 0,
    this.lastAccessTime,
    this.userVisible = 1,
    this.userEdited = 0,
    this.createTime,
    this.updateTime,
  });

  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      companionId: (json['companionId'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      thought: json['thought'] as String?,
      emotion: json['emotion'] as String?,
      sourceMessageId: (json['sourceMessageId'] as num?)?.toInt(),
      importance: (json['importance'] as num?)?.toInt() ?? 5,
      vectorId: json['vectorId'] as String?,
      accessCount: (json['accessCount'] as num?)?.toInt() ?? 0,
      lastAccessTime: json['lastAccessTime'] != null
          ? DateTime.parse(json['lastAccessTime'] as String)
          : null,
      userVisible: (json['userVisible'] as num?)?.toInt() ?? 1,
      userEdited: (json['userEdited'] as num?)?.toInt() ?? 0,
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.parse(json['updateTime'] as String)
          : null,
    );
  }

  Memory copyWith({
    int? id,
    int? userId,
    int? companionId,
    String? category,
    String? title,
    String? content,
    String? thought,
    String? emotion,
    int? sourceMessageId,
    int? importance,
    String? vectorId,
    int? accessCount,
    DateTime? lastAccessTime,
    int? userVisible,
    int? userEdited,
    DateTime? createTime,
    DateTime? updateTime,
  }) {
    return Memory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companionId: companionId ?? this.companionId,
      category: category ?? this.category,
      title: title ?? this.title,
      content: content ?? this.content,
      thought: thought ?? this.thought,
      emotion: emotion ?? this.emotion,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      importance: importance ?? this.importance,
      vectorId: vectorId ?? this.vectorId,
      accessCount: accessCount ?? this.accessCount,
      lastAccessTime: lastAccessTime ?? this.lastAccessTime,
      userVisible: userVisible ?? this.userVisible,
      userEdited: userEdited ?? this.userEdited,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'companionId': companionId,
    'category': category,
    'title': title,
    'content': content,
    'thought': thought,
    'emotion': emotion,
    'sourceMessageId': sourceMessageId,
    'importance': importance,
    'vectorId': vectorId,
    'accessCount': accessCount,
    'lastAccessTime': lastAccessTime?.toIso8601String(),
    'userVisible': userVisible,
    'userEdited': userEdited,
    'createTime': createTime?.toIso8601String(),
    'updateTime': updateTime?.toIso8601String(),
  };
}
