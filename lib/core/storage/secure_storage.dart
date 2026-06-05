import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全存储服务 - 存储敏感凭证（JWT Token、API Key等）
class SecureStorage {
  static const _storage = FlutterSecureStorage();

  // 存储键名
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';

  /// 保存Token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// 获取Token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// 保存Refresh Token
  static Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  /// 获取Refresh Token
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// 保存用户ID
  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  /// 获取用户ID
  static Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  /// 清除所有Token
  static Future<void> clearTokens() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
  }

  /// 清除所有存储
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// 检查是否已登录
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
