import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// API客户端配置 - 支持主备地址自动切换
class ApiClient {
  // 主备服务器地址
  static const String primaryBaseUrl = 'http://192.168.2.240:8080';
  static const String fallbackBaseUrl = 'https://cupid-discard-ritzy.ngrok-free.dev';
  static const String apiPrefix = '/api';

  // 超时配置
  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 10);

  late final Dio _dio;
  bool _usingFallback = false;
  int _consecutiveFailures = 0;
  static const int _maxFailures = 3; // 连续失败3次后切换

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: primaryBaseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ),
    );

    // 添加拦截器
    _dio.interceptors.addAll([
      AuthInterceptor(_dio),
      if (kDebugMode) LoggingInterceptor(),
      _RetryInterceptor(this),
    ]);
  }

  Dio get dio => _dio;
  bool get isUsingFallback => _usingFallback;
  String get currentHost => Uri.parse(currentBaseUrl).host;
  String get currentBaseUrl => _usingFallback ? fallbackBaseUrl : primaryBaseUrl;

  /// 将相对路径转为完整URL（用于图片等静态资源）
  String getFullUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$currentBaseUrl${path.startsWith('/') ? '' : '/'}$path';
  }

  /// 切换到备用地址
  void switchToFallback() {
    if (!_usingFallback) {
      _usingFallback = true;
      _consecutiveFailures = 0;
      _dio.options.baseUrl = fallbackBaseUrl;
      if (kDebugMode) {
        print('🔄 切换到备用服务器: $fallbackBaseUrl');
      }
    }
  }

  /// 切换回主地址
  void switchToPrimary() {
    if (_usingFallback) {
      _usingFallback = false;
      _consecutiveFailures = 0;
      _dio.options.baseUrl = primaryBaseUrl;
      if (kDebugMode) {
        print('🔄 切换回主服务器: $primaryBaseUrl');
      }
    }
  }

  /// 记录请求失败
  void recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _maxFailures) {
      switchToFallback();
    }
  }

  /// 记录请求成功
  void recordSuccess() {
    _consecutiveFailures = 0;
    // 如果当前使用备用地址，定期尝试恢复主地址
    if (_usingFallback) {
      _tryRestorePrimary();
    }
  }

  /// 尝试恢复主地址（异步，不阻塞当前请求）
  Future<void> _tryRestorePrimary() async {
    try {
      final testDio = Dio(BaseOptions(
        baseUrl: primaryBaseUrl,
        connectTimeout: const Duration(seconds: 3),
        headers: {
          'ngrok-skip-browser-warning': 'true',
        },
      ));
      await testDio.get('$apiPrefix/health');
      switchToPrimary();
    } catch (_) {
      // 主地址仍然不可用，继续使用备用地址
    }
  }
}

/// 重试拦截器 - 处理超时和网络错误，触发地址切换
class _RetryInterceptor extends Interceptor {
  final ApiClient _client;

  _RetryInterceptor(this._client);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 连接超时或连接错误时记录失败
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      _client.recordFailure();

      // 如果还没切换到备用地址，且是连接错误，尝试用备用地址重试
      if (!_client.isUsingFallback &&
          err.type == DioExceptionType.connectionError) {
        _client.switchToFallback();
        // 用备用地址重新发起请求
        _retryWithFallback(err.requestOptions).then(
          (response) => handler.resolve(response),
          onError: (e) => handler.next(err),
        );
        return;
      }
    }

    handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _client.recordSuccess();
    handler.next(response);
  }

  Future<Response> _retryWithFallback(RequestOptions options) async {
    options.baseUrl = ApiClient.fallbackBaseUrl;
    return _client.dio.fetch(options);
  }
}

/// API客户端Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

/// Dio Provider
final dioProvider = Provider<Dio>((ref) {
  return ref.watch(apiClientProvider).dio;
});

/// 获取完整URL的工具方法（拼接base URL）
String getFullUrl(WidgetRef ref, String path) {
  final apiClient = ref.read(apiClientProvider);
  return apiClient.getFullUrl(path);
}
