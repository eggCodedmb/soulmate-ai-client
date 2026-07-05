import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/local_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// API客户端配置 - 仅保留主服务器地址
class ApiClient {
  // 服务器地址
  static const String primaryBaseUrl = 'http://39.108.137.45';
  static const String apiPrefix = '/api';

  // 超时配置
  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 10);

  late final Dio _dio;

  ApiClient() {
    final String baseUrlStr = LocalStorage.serverType == 'online'
        ? primaryBaseUrl
        : LocalStorage.localServerUrl;

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrlStr,
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
    ]);
  }

  Dio get dio => _dio;
  String get currentHost => Uri.parse(currentBaseUrl).host;
  String get currentBaseUrl => LocalStorage.serverType == 'online'
      ? primaryBaseUrl
      : LocalStorage.localServerUrl;

  /// 将相对路径转为完整URL（用于图片等静态资源）
  String getFullUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final baseUrl = currentBaseUrl;
    return '$baseUrl${path.startsWith('/') ? '' : '/'}$path';
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
