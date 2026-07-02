import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../storage/secure_storage.dart';
import '../../routing/app_router.dart';

/// 认证拦截器 - JWT Token自动注入 + 过期自动刷新与跳转登录
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
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final code = data['code'] as int? ?? 0;
      // 1001: 未登录/过期, 1003: Token无效, 1004: Token已过期, 3001: 用户不存在/Token过期
      if (code == 1001 || code == 1003 || code == 1004 || code == 3001) {
        await SecureStorage.clearTokens();
        rootNavigatorKey.currentContext?.go('/auth');
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            message: data['message'] as String? ?? '登录状态已失效，请重新登录',
          ),
        );
        return;
      }
    }
    handler.next(response);
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
        rootNavigatorKey.currentContext?.go('/auth');
      }
    }
    handler.next(err);
  }
}
