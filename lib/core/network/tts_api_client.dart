import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/local_storage.dart';
import '../../shared/models/tts_config.dart';

/// TTS API 客户端 - 连接独立的 TTS 服务器
///
/// TTS 服务器提供声音档案管理和语音合成功能。
/// 基础地址通过 LocalStorage.ttsBaseUrl 配置。
class TtsApiClient {
  Dio? _dio;
  String? _currentBaseUrl;

  /// 获取或创建 Dio 实例，如果 base URL 变化则重新创建
  Dio? _getDio() {
    final baseUrl = LocalStorage.ttsBaseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    if (_dio == null || _currentBaseUrl != baseUrl) {
      _currentBaseUrl = baseUrl;
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      if (kDebugMode) {
        _dio!.interceptors.add(LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('[TTS] $obj'),
        ));
      }
    }
    return _dio;
  }

  /// TTS 服务器是否已配置
  bool get isConfigured {
    final url = LocalStorage.ttsBaseUrl;
    return url != null && url.isNotEmpty;
  }

  /// 获取所有声音档案
  Future<List<VoiceProfile>> getProfiles() async {
    final dio = _getDio();
    if (dio == null) {
      throw TtsApiException('TTS 服务器未配置，请在设置中配置 TTS 服务器地址');
    }

    try {
      final response = await dio.get('/profiles');
      final data = response.data as List<dynamic>;
      return data
          .map((e) => VoiceProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw TtsApiException(_formatError(e));
    }
  }

  /// 生成语音（非流式）- 返回音频数据
  ///
  /// 返回音频文件的字节数据，调用方需要写入临时文件后播放
  Future<Uint8List> generate(TtsGenerateRequest request) async {
    final dio = _getDio();
    if (dio == null) {
      throw TtsApiException('TTS 服务器未配置，请在设置中配置 TTS 服务器地址');
    }

    try {
      final response = await dio.post<List<int>>(
        '/generate',
        data: request.toJson(),
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (e) {
      throw TtsApiException(_formatError(e));
    }
  }

  /// 生成语音（流式）- 返回音频数据流
  ///
  /// 适用于长文本，逐步返回音频数据
  Stream<Uint8List> generateStream(TtsGenerateRequest request) async* {
    final dio = _getDio();
    if (dio == null) {
      throw TtsApiException('TTS 服务器未配置，请在设置中配置 TTS 服务器地址');
    }

    try {
      final response = await dio.post<ResponseBody>(
        '/generate/stream',
        data: request.toJson(),
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 300),
        ),
      );

      final stream = response.data!.stream;
      await for (final chunk in stream) {
        yield Uint8List.fromList(chunk);
      }
    } on DioException catch (e) {
      throw TtsApiException(_formatError(e));
    }
  }

  /// 测试 TTS 服务器连接
  Future<bool> testConnection() async {
    final dio = _getDio();
    if (dio == null) return false;

    try {
      await dio.get('/profiles');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 格式化错误信息
  String _formatError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接 TTS 服务器超时';
      case DioExceptionType.receiveTimeout:
        return 'TTS 服务器响应超时';
      case DioExceptionType.connectionError:
        return '无法连接 TTS 服务器，请检查地址是否正确';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        return 'TTS 服务器错误 ($statusCode)';
      default:
        return 'TTS 请求失败: ${e.message}';
    }
  }
}

/// TTS API 异常
class TtsApiException implements Exception {
  final String message;
  TtsApiException(this.message);

  @override
  String toString() => 'TtsApiException: $message';
}

/// TTS API 客户端 Provider
final ttsApiProvider = Provider<TtsApiClient>((ref) {
  return TtsApiClient();
});
