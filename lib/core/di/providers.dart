import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/websocket_service.dart';
import '../storage/database/app_database.dart';
import '../storage/local_storage.dart';

/// 安全存储Provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// 数据库Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// WebSocket服务Provider
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(service.dispose);
  return service;
});

/// 主题模式Provider（从本地存储读取已持久化的值）
final themeModeProvider = StateProvider<String>((ref) {
  return LocalStorage.themeMode; // 'system' / 'light' / 'dark'
});

/// 当前伴侣ID Provider
final currentPartnerIdProvider = StateProvider<String?>((ref) {
  return null;
});

/// 是否已登录Provider
final isLoggedInProvider = StateProvider<bool>((ref) {
  return false;
});

/// 消息通知状态 Provider
final messageNotifyProvider = StateProvider<bool>((ref) {
  return LocalStorage.messageNotify;
});

/// 主动关心状态 Provider
final proactiveCareProvider = StateProvider<bool>((ref) {
  return LocalStorage.proactiveCare;
});
