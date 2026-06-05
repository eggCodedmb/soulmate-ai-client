import 'package:dio/dio.dart';
import '../../storage/secure_storage.dart';

/// 认证拦截器 - JWT Token自动注入 + 过期自动刷新
class AuthInterceptor extends Interceptor {
  final Dio _dio;

  AuthInterceptor(this._dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 从安全存储获取Token
    final token = await SecureStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token过期，尝试刷新
      try {
        final refreshToken = await SecureStorage.getRefreshToken();
        if (refreshToken != null) {
          // TODO: 实现Token刷新逻辑
          // final response = await _dio.post('/api/auth/refresh', data: {'refreshToken': refreshToken});
          // await SecureStorage.saveToken(response.data['token']);
          // 重新发起请求
          // final retryResponse = await _dio.fetch(err.requestOptions);
          // return handler.resolve(retryResponse);
        }
      } catch (e) {
        // 刷新失败，清除Token并跳转登录
        await SecureStorage.clearTokens();
        // TODO: 跳转到登录页
      }
    }
    handler.next(err);
  }
}
