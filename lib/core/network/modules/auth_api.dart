import 'package:dio/dio.dart';
import '../api_service.dart';

/// 认证模块 API
mixin AuthMixin {
  Dio get dio;
  dynamic unwrap(Response<dynamic> response);

  /// 发送验证码
  Future<void> sendVerifyCode(Map<String, String> body) async {
    final response = await dio.post<dynamic>('/api/auth/send-code', data: body);
    unwrap(response); // 校验 code
  }

  /// 邮箱验证码登录
  Future<LoginResponse> login(LoginRequest request) async {
    final response = await dio.post<dynamic>('/api/auth/login', data: request.toJson());
    return LoginResponse.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  /// 游客登录
  Future<LoginResponse> guestLogin() async {
    final response = await dio.post<dynamic>('/api/auth/guest');
    return LoginResponse.fromJson(unwrap(response) as Map<String, dynamic>);
  }
}
