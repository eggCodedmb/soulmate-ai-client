import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../shared/models/message.dart';

/// 消息本地存储服务
class MessageLocalStorage {
  MessageLocalStorage._();
  static final MessageLocalStorage instance = MessageLocalStorage._();

  Database? _database;

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = join(appDir.path, 'soulmate_messages.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// 创建表
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY,
        conversation_id INTEGER NOT NULL,
        sender_type TEXT NOT NULL,
        content TEXT NOT NULL,
        content_type TEXT NOT NULL DEFAULT 'text',
        voice_url TEXT,
        voice_duration INTEGER,
        image_url TEXT,
        emotion_tag TEXT,
        emotion_score REAL,
        tokens_used INTEGER DEFAULT 0,
        llm_model TEXT,
        read_status INTEGER DEFAULT 0,
        create_time TEXT,
        cached_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_messages_conversation_id ON messages(conversation_id)',
    );
    await db.execute(
      'CREATE INDEX idx_messages_create_time ON messages(create_time)',
    );
  }

  /// 缓存消息列表
  Future<void> cacheMessages(int conversationId, List<Message> messages) async {
    final db = await database;
    final batch = db.batch();

    for (final message in messages) {
      batch.insert(
        'messages',
        _messageToMap(message),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 添加单条消息
  Future<void> insertMessage(Message message) async {
    final db = await database;
    await db.insert(
      'messages',
      _messageToMap(message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取对话的本地缓存消息
  Future<List<Message>> getMessages(
    int conversationId, {
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'create_time DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => _mapToMessage(map)).toList();
  }

  /// 获取对话的最早消息时间
  Future<DateTime?> getEarliestMessageTime(int conversationId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MIN(create_time) as earliest FROM messages WHERE conversation_id = ?',
      [conversationId],
    );

    if (result.isNotEmpty && result.first['earliest'] != null) {
      return DateTime.parse(result.first['earliest'] as String);
    }
    return null;
  }

  /// 获取对话的消息数量
  Future<int> getMessageCount(int conversationId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE conversation_id = ?',
      [conversationId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 删除对话的所有消息
  Future<void> clearMessages(int conversationId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  /// 删除单条消息
  Future<void> deleteMessage(int messageId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Message 转 Map
  Map<String, dynamic> _messageToMap(Message message) {
    return {
      'id': message.id,
      'conversation_id': message.conversationId,
      'sender_type': message.senderType,
      'content': message.content,
      'content_type': message.contentType,
      'voice_url': message.voiceUrl,
      'voice_duration': message.voiceDuration,
      'image_url': message.imageUrl,
      'emotion_tag': message.emotionTag,
      'emotion_score': message.emotionScore,
      'tokens_used': message.tokensUsed,
      'llm_model': message.llmModel,
      'read_status': message.readStatus,
      'create_time': message.createTime?.toIso8601String(),
    };
  }

  /// Map 转 Message
  Message _mapToMessage(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as int,
      conversationId: map['conversation_id'] as int,
      senderType: map['sender_type'] as String,
      content: map['content'] as String,
      contentType: map['content_type'] as String? ?? 'text',
      voiceUrl: map['voice_url'] as String?,
      voiceDuration: map['voice_duration'] as int?,
      imageUrl: map['image_url'] as String?,
      emotionTag: map['emotion_tag'] as String?,
      emotionScore: map['emotion_score'] as double?,
      tokensUsed: map['tokens_used'] as int? ?? 0,
      llmModel: map['llm_model'] as String?,
      readStatus: map['read_status'] as int? ?? 0,
      createTime: map['create_time'] != null
          ? DateTime.parse(map['create_time'] as String)
          : null,
    );
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
