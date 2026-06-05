/// 消息
class Message {
  final int id;
  final int conversationId;
  final String senderType;
  final String content;
  final String contentType;
  final String? voiceUrl;
  final int? voiceDuration;
  final String? imageUrl;
  final String? emotionTag;
  final double? emotionScore;
  final int tokensUsed;
  final String? llmModel;
  final int readStatus;
  final DateTime? createTime;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.content,
    this.contentType = 'text',
    this.voiceUrl,
    this.voiceDuration,
    this.imageUrl,
    this.emotionTag,
    this.emotionScore,
    this.tokensUsed = 0,
    this.llmModel,
    this.readStatus = 0,
    this.createTime,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] as num).toInt(),
      conversationId: (json['conversationId'] as num).toInt(),
      senderType: json['senderType'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'text',
      voiceUrl: json['voiceUrl'] as String?,
      voiceDuration: (json['voiceDuration'] as num?)?.toInt(),
      imageUrl: json['imageUrl'] as String?,
      emotionTag: json['emotionTag'] as String?,
      emotionScore: (json['emotionScore'] as num?)?.toDouble(),
      tokensUsed: (json['tokensUsed'] as num?)?.toInt() ?? 0,
      llmModel: json['llmModel'] as String?,
      readStatus: (json['readStatus'] as num?)?.toInt() ?? 0,
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderType': senderType,
    'content': content,
    'contentType': contentType,
    'voiceUrl': voiceUrl,
    'voiceDuration': voiceDuration,
    'imageUrl': imageUrl,
    'emotionTag': emotionTag,
    'emotionScore': emotionScore,
    'tokensUsed': tokensUsed,
    'llmModel': llmModel,
    'readStatus': readStatus,
    'createTime': createTime?.toIso8601String(),
  };
}

/// SSE聊天响应（对齐后端 ChatResponse 字段）
class ChatResponse {
  final int? messageId;
  final int? conversationId;
  final String? content;
  final bool done;
  final String? emotionTag;
  final String? error;
  final int? tokensUsed;

  const ChatResponse({
    this.messageId,
    this.conversationId,
    this.content,
    this.done = false,
    this.emotionTag,
    this.error,
    this.tokensUsed,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      messageId: (json['messageId'] as num?)?.toInt(),
      conversationId: (json['conversationId'] as num?)?.toInt(),
      content: json['content'] as String?,
      done: json['done'] as bool? ?? false,
      emotionTag: json['emotionTag'] as String?,
      error: json['error'] as String?,
      tokensUsed: (json['tokensUsed'] as num?)?.toInt(),
    );
  }
}
