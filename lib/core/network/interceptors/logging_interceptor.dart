import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 日志拦截器 - 仅Debug模式下打印请求/响应日志
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      print('┌──────────────────────────────────────────────');
      print('│ 🚀 REQUEST: ${options.method} ${options.uri}');
      print('│ Headers: ${options.headers}');
      if (options.data != null) {
        print('│ Body: ${options.data}');
      }
      print('└──────────────────────────────────────────────');
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      print('┌──────────────────────────────────────────────');
      print('│ ✅ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
      print('│ Data: ${response.data}');
      print('└──────────────────────────────────────────────');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print('┌──────────────────────────────────────────────');
      print('│ ❌ ERROR: ${err.response?.statusCode} ${err.requestOptions.uri}');
      print('│ Message: ${err.message}');
      if (err.response?.data != null) {
        print('│ Data: ${err.response?.data}');
      }
      print('└──────────────────────────────────────────────');
    }
    handler.next(err);
  }
}
