import 'dart:async';

/// 简化的数据库服务 - 使用内存存储
/// 后续可通过Drift替换为SQLite
class AppDatabase {
  final List<Map<String, dynamic>> _partners = [];
  final List<Map<String, dynamic>> _conversations = [];
  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _memories = [];

  final StreamController<List<Map<String, dynamic>>> _partnersController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _conversationsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _messagesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// 监听伴侣列表变化
  Stream<List<Map<String, dynamic>>> watchAllPartners() =>
      _partnersController.stream;

  /// 监听对话列表变化
  Stream<List<Map<String, dynamic>>> watchAllConversations() =>
      _conversationsController.stream;

  /// 监听消息变化
  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) =>
      _messagesController.stream.map(
        (messages) => messages
            .where((m) => m['conversationId'] == conversationId)
            .toList(),
      );

  /// 获取所有伴侣
  Future<List<Map<String, dynamic>>> getAllPartners() async =>
      List.unmodifiable(_partners);

  /// 插入伴侣
  Future<void> insertPartner(Map<String, dynamic> partner) async {
    _partners.removeWhere((p) => p['id'] == partner['id']);
    _partners.add(partner);
    _partnersController.add(List.unmodifiable(_partners));
  }

  /// 删除伴侣
  Future<void> deletePartner(String id) async {
    _partners.removeWhere((p) => p['id'] == id);
    _partnersController.add(List.unmodifiable(_partners));
  }

  /// 获取所有对话
  Future<List<Map<String, dynamic>>> getAllConversations() async =>
      List.unmodifiable(_conversations);

  /// 插入对话
  Future<void> insertConversation(Map<String, dynamic> conversation) async {
    _conversations.removeWhere((c) => c['id'] == conversation['id']);
    _conversations.add(conversation);
    _conversationsController.add(List.unmodifiable(_conversations));
  }

  /// 获取对话消息
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async =>
      _messages
          .where((m) => m['conversationId'] == conversationId)
          .toList()
        ..sort((a, b) => (b['timestamp'] as DateTime)
            .compareTo(a['timestamp'] as DateTime));

  /// 插入消息
  Future<void> insertMessage(Map<String, dynamic> message) async {
    _messages.removeWhere((m) => m['id'] == message['id']);
    _messages.add(message);
    _messagesController.add(List.unmodifiable(_messages));
  }

  /// 清空对话消息
  Future<void> clearMessages(String conversationId) async {
    _messages.removeWhere((m) => m['conversationId'] == conversationId);
    _messagesController.add(List.unmodifiable(_messages));
  }

  /// 获取记忆列表
  Future<List<Map<String, dynamic>>> getAllMemories({
    String? companionId,
    String? category,
  }) async {
    var memories = List<Map<String, dynamic>>.from(_memories);
    if (companionId != null) {
      memories = memories.where((m) => m['companionId'] == companionId).toList();
    }
    if (category != null) {
      memories = memories.where((m) => m['category'] == category).toList();
    }
    return memories;
  }

  /// 插入记忆
  Future<void> insertMemory(Map<String, dynamic> memory) async {
    _memories.removeWhere((m) => m['id'] == memory['id']);
    _memories.add(memory);
  }

  /// 删除记忆
  Future<void> deleteMemory(String id) async {
    _memories.removeWhere((m) => m['id'] == id);
  }

  /// 释放资源
  void close() {
    _partnersController.close();
    _conversationsController.close();
    _messagesController.close();
  }
}
