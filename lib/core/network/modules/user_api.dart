import 'package:dio/dio.dart';
import '../../../shared/models/user.dart';

/// 用户模块 API
mixin UserMixin {
  Dio get dio;
  dynamic unwrap(Response<dynamic> response);

  /// 获取用户信息
  Future<User> getUserInfo() async {
    final response = await dio.get<dynamic>('/api/user/info');
    return User.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  /// 更新用户信息
  Future<void> updateUserInfo(User user) async {
    final response = await dio.put<dynamic>('/api/user/info', data: user.toJson());
    unwrap(response);
  }

  /// 更新用户头像
  Future<void> updateAvatar(String? avatarUrl) async {
    final response = await dio.put<dynamic>(
      '/api/user/avatar',
      data: {'avatarUrl': avatarUrl},
    );
    unwrap(response);
  }

  /// 获取用户资料
  Future<UserProfile> getUserProfile() async {
    final response = await dio.get<dynamic>('/api/user/profile');
    return UserProfile.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  /// 更新用户资料
  Future<void> updateUserProfile(UserProfile profile) async {
    final response = await dio.put<dynamic>('/api/user/profile', data: profile.toJson());
    unwrap(response);
  }

  /// 获取用户设置
  Future<UserSettings> getUserSettings() async {
    final response = await dio.get<dynamic>('/api/user/settings');
    return UserSettings.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  /// 更新用户设置
  Future<void> updateUserSettings(UserSettings settings) async {
    final response = await dio.put<dynamic>('/api/user/settings', data: settings.toJson());
    unwrap(response);
  }
}
