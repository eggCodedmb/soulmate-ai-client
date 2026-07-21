import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../storage/secure_storage.dart';
import '../../routing/app_router.dart';

/// 认证拦截器 - JWT Token自动注入 + 过期自动跳转登录
class AuthInterceptor extends Interceptor {
  // ignore: unused_field
  final Dio _dio;
  static bool _isHandlingAuthFailure = false;

  AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 从安全存储获取Token
    final token = await SecureStorage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) async {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final code = data['code'] as int? ?? 0;
      // 1001: 未登录/过期, 1003: Token无效, 1004: Token已过期, 3001: 用户不存在/Token过期
      if (_isAuthErrorCode(code)) {
        await _handleAuthFailure();
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
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;
    int code = 0;
    if (data is Map<String, dynamic>) {
      code = data['code'] as int? ?? 0;
    }

    if (statusCode == 401 || _isAuthErrorCode(code)) {
      await _handleAuthFailure();
    }
    handler.next(err);
  }

  bool _isAuthErrorCode(int code) {
    return code == 1001 || code == 1003 || code == 1004 || code == 3001;
  }

  Future<void> _handleAuthFailure() async {
    await SecureStorage.clearTokens();

    if (_isHandlingAuthFailure) return;
    _isHandlingAuthFailure = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        context.go('/auth');
      }
      _isHandlingAuthFailure = false;
    });
  }
}

