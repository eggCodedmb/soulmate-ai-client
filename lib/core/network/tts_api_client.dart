import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/local_storage.dart';
import '../../shared/models/tts_config.dart';

/// TTS API 客户端 - 连接独立的 TTS 服务器或小米云端 TTS 服务
///
/// TTS 服务器提供声音档案管理和语音合成功能。
/// 基础地址通过 LocalStorage.ttsBaseUrl 配置。
class TtsApiClient {
  Dio? _dio;
  String? _currentBaseUrl;
  String? _currentProviderType;
  String? _currentApiKey;

  /// 小米 TTS 预设音色列表
  static final List<VoiceProfile> mimoPresetProfiles = [
    VoiceProfile(
      id: 'mimo_default',
      name: '默认音色',
      language: 'zh',
      voiceType: 'preset',
      defaultEngine: 'mimo',
      createdAt: '',
      updatedAt: '',
    ),
    VoiceProfile(
      id: '冰糖',
      name: '冰糖',
      language: 'zh',
      voiceType: 'preset',
      defaultEngine: 'mimo',
      createdAt: '',
      updatedAt: '',
    ),
    VoiceProfile(
      id: '茉莉',
      name: '茉莉',
      language: 'zh',
      voiceType: 'preset',
      defaultEngine: 'mimo',
      createdAt: '',
      updatedAt: '',
    ),
    VoiceProfile(
      id: '苏打',
      name: '苏打',
      language: 'zh',
      voiceType: 'preset',
      defaultEngine: 'mimo',
      createdAt: '',
      updatedAt: '',
    ),
    VoiceProfile(
      id: '白桦',
      name: '白桦',
      language: 'zh',
      voiceType: 'preset',
      defaultEngine: 'mimo',
      createdAt: '',
      updatedAt: '',
    ),
    VoiceProfile(
      id: 'Mia',
      name: 'Mia',
      language: 'en',
      voiceType: 'preset',
      defaultEngine: 'mimo',
      createdAt: '',
      updatedAt: '',
    ),
    VoiceProfile(
      id: 'Chloe',
      name: 'Chloe',
      language: 'en',
      voiceType: 'preset',
      defaultEngine: 'mimo',
      createdAt: '',
      updatedAt: '',
    ),
    VoiceProfile(
      id: 'Milo',
      name: 'Milo',
      language: 'en',
      voiceType: 'preset',
      defaultEngine: 'mimo',
      createdAt: '',
      updatedAt: '',
    ),
    VoiceProfile(
      id: 'Dean',
      name: 'Dean',
      language: 'en',
      voiceType: 'preset',
      defaultEngine: 'mimo',
      createdAt: '',
      updatedAt: '',
    ),
  ];

  /// 获取或创建 Dio 实例，如果配置变化则重新创建
  Dio? _getDio() {
    var baseUrl = LocalStorage.ttsBaseUrl;
    final providerType = LocalStorage.ttsProviderType;
    final apiKey = LocalStorage.ttsApiKey;

    if (providerType == 'official' && (baseUrl == null || baseUrl.isEmpty)) {
      baseUrl = LocalStorage.apiBaseUrl;
    }

    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }

    if (providerType == 'mimo' && (apiKey == null || apiKey.isEmpty)) {
      return null;
    }

    if (_dio == null ||
        _currentBaseUrl != baseUrl ||
        _currentProviderType != providerType ||
        _currentApiKey != apiKey) {
      _currentBaseUrl = baseUrl;
      _currentProviderType = providerType;
      _currentApiKey = apiKey;

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (providerType == 'mimo') {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
          headers: headers,
        ),
      );

      if (kDebugMode) {
        _dio!.interceptors.add(LogInterceptor(
          requestBody: true,
          responseBody: false, // 避免打印超长音频 Base64 数据
          logPrint: (obj) => debugPrint('[TTS] $obj'),
        ));
      }
    }
    return _dio;
  }

  /// TTS 服务器是否已配置
  bool get isConfigured {
    final type = LocalStorage.ttsProviderType;
    if (type == 'official' || type == 'system') return true;
    final url = LocalStorage.ttsBaseUrl;
    if (url == null || url.isEmpty) return false;
    if (type == 'mimo') {
      final apiKey = LocalStorage.ttsApiKey;
      return apiKey != null && apiKey.isNotEmpty;
    }
    return true;
  }

  /// 获取所有声音档案
  Future<List<VoiceProfile>> getProfiles() async {
    final type = LocalStorage.ttsProviderType;
    if (type == 'mimo' || type == 'official') {
      return mimoPresetProfiles;
    }

    if (type == 'system') {
      return [
        VoiceProfile(
          id: 'system_default',
          name: '手机系统默认音色',
          language: 'zh',
          voiceType: 'preset',
          defaultEngine: 'system',
          description: '使用手机设备原生离线 TTS 引擎朗读',
          createdAt: '',
          updatedAt: '',
        ),
      ];
    }

    final dio = _getDio();
    if (dio == null) {
      throw TtsApiException('TTS 服务器未配置，请在设置中配置 TTS 服务器地址');
    }

    try {
      final response = await dio.get<dynamic>('/profiles');
      final data = response.data as List<dynamic>;
      return data
          .map((e) => VoiceProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw TtsApiException(_formatError(e));
    }
  }

  /// 生成小米 TTS 语音（带重试机制）
  Future<Uint8List> generateMimo(TtsGenerateRequest request) async {
    final dio = _getDio();
    if (dio == null) {
      throw TtsApiException('TTS 服务器未配置，请在设置中配置 TTS 服务器地址');
    }

    final model = LocalStorage.ttsModel;
    final instruct = request.instruct != null && request.instruct!.isNotEmpty
        ? request.instruct
        : '用温柔的女声朗读';

    final requestData = {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': instruct,
        },
        {
          'role': 'assistant',
          'content': request.text,
        }
      ],
      'audio': {
        'format': 'wav',
        'voice': request.profileId,
      },
      'stream': false,
    };

    int retryCount = 0;
    const int maxRetries = 3;

    while (true) {
      try {
        final response = await dio.post<dynamic>(
          '/chat/completions',
          data: requestData,
        );

        final data = response.data as Map<String, dynamic>?;
        if (data == null) {
          throw TtsApiException('小米 TTS 返回空数据');
        }

        final choices = data['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) {
          throw TtsApiException('小米 TTS 返回 choices 为空');
        }

        final choice = choices[0] as Map<String, dynamic>?;
        if (choice == null) {
          throw TtsApiException('小米 TTS 返回 choice[0] 为空');
        }

        final message = choice['message'] as Map<String, dynamic>?;
        if (message == null) {
          throw TtsApiException('小米 TTS 返回 message 为空');
        }

        final audio = message['audio'] as Map<String, dynamic>?;
        if (audio == null) {
          throw TtsApiException('小米 TTS 返回 audio 为空');
        }

        final base64Data = audio['data'] as String?;
        if (base64Data == null || base64Data.isEmpty) {
          throw TtsApiException('小米 TTS 返回音频 Base64 为空');
        }

        return base64.decode(base64Data);
      } on DioException catch (e) {
        if (e.response?.statusCode == 429 && retryCount < maxRetries) {
          retryCount++;
          // 指数退避: 1s, 2s, 4s
          final delay = Duration(seconds: math.pow(2, retryCount - 1).toInt());
          debugPrint('[TTS] 触发 429 频率限制，将在 ${delay.inSeconds}秒后进行第 $retryCount 次重试...');
          await Future.delayed(delay);
          continue;
        }
        throw TtsApiException(_formatError(e));
      } on Object catch (e) {
        throw TtsApiException('小米 TTS 合成失败: $e');
      }
    }
  }

  /// 生成语音（非流式）- 返回音频数据
  ///
  /// 返回音频文件的字节数据，调用方需要写入临时文件后播放
  Future<Uint8List> generate(TtsGenerateRequest request) async {
    final providerType = LocalStorage.ttsProviderType;
    if (providerType == 'mimo') {
      return generateMimo(request);
    }

    if (providerType == 'system') {
      // 手机系统 TTS 使用设备原生引擎直接发声，不进行网络文件合成
      return Uint8List(0);
    }

    final dio = _getDio();
    if (dio == null) {
      throw TtsApiException('TTS 服务器未配置，请在设置中配置 TTS 服务器地址');
    }

    int retryCount = 0;
    const int maxRetries = 3;
    final endpoint = providerType == 'official' ? '/tts/generate' : '/generate';

    while (true) {
      try {
        final response = await dio.post<List<int>>(
          endpoint,
          data: request.toJson(),
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 120),
          ),
        );
        return Uint8List.fromList(response.data!);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 && providerType == 'official') {
          try {
            final altResp = await dio.post<List<int>>(
              '/generate',
              data: request.toJson(),
              options: Options(
                responseType: ResponseType.bytes,
                receiveTimeout: const Duration(seconds: 120),
              ),
            );
            return Uint8List.fromList(altResp.data!);
          } catch (_) {}
        }
        if (e.response?.statusCode == 429 && retryCount < maxRetries) {
          retryCount++;
          final delay = Duration(seconds: math.pow(2, retryCount - 1).toInt());
          debugPrint('[TTS] 触发 429 频率限制，将在 ${delay.inSeconds}秒后进行第 $retryCount 次重试...');
          await Future.delayed(delay);
          continue;
        }
        throw TtsApiException(_formatError(e));
      }
    }
  }

  /// 生成语音（流式）- 返回音频数据流
  ///
  /// 适用于长文本，逐步返回音频数据
  Stream<Uint8List> generateStream(TtsGenerateRequest request) async* {
    final providerType = LocalStorage.ttsProviderType;
    if (providerType == 'mimo') {
      final bytes = await generateMimo(request);
      yield bytes;
      return;
    }

    if (providerType == 'system') {
      // 手机系统 TTS 无需 HTTP 音频流
      return;
    }

    final dio = _getDio();
    if (dio == null) {
      throw TtsApiException('TTS 服务器未配置，请在设置中配置 TTS 服务器地址');
    }

    final endpoint = providerType == 'official' ? '/tts/generate/stream' : '/generate/stream';

    try {
      final response = await dio.post<ResponseBody>(
        endpoint,
        data: request.toJson(),
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 300),
        ),
      );

      final contentType = response.headers.value('content-type') ?? '';
      if (contentType.contains('application/json') ||
          contentType.contains('text/html') ||
          contentType.contains('text/plain')) {
        final responseData = await response.data!.stream.toList();
        final bytes = responseData.expand((x) => x).toList();
        final decodedStr = utf8.decode(bytes);
        if (contentType.contains('application/json')) {
          try {
            final map = json.decode(decodedStr) as Map<String, dynamic>;
            final errorMsg = map['message'] ?? map['error'] ?? 'API 错误';
            throw TtsApiException(errorMsg.toString());
          } catch (_) {
            throw TtsApiException(decodedStr);
          }
        } else {
          final cleanStr = decodedStr.length > 200
              ? '${decodedStr.substring(0, 200)}...'
              : decodedStr;
          throw TtsApiException('服务器返回错误 ($contentType): $cleanStr');
        }
      }

      final stream = response.data!.stream;
      await for (final chunk in stream) {
        yield Uint8List.fromList(chunk);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && providerType == 'system') {
        try {
          final bytes = await generate(request);
          yield bytes;
          return;
        } catch (_) {}
      }
      throw TtsApiException(_formatError(e));
    }
  }

  /// 测试 TTS 服务器连接
  Future<bool> testConnection() async {
    final providerType = LocalStorage.ttsProviderType;
    if (providerType == 'mimo') {
      try {
        final dummyRequest = TtsGenerateRequest(
          profileId: 'mimo_default',
          text: '测试连接',
          language: 'zh',
          instruct: '用温柔的声音朗读',
        );
        final bytes = await generateMimo(dummyRequest);
        return bytes.isNotEmpty;
      } on Object catch (e) {
        debugPrint('[TTS] 测试连接失败: $e');
        return false;
      }
    }

    final dio = _getDio();
    if (dio == null) return false;

    try {
      await dio.get<dynamic>('/profiles');
      return true;
    } on Object catch (_) {
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
        dynamic responseData = e.response?.data;

        // 如果是二进制字节流（如 Voicebox 接口报错），尝试解码为 String
        if (responseData is List<int>) {
          try {
            final decoded = utf8.decode(responseData);
            responseData = json.decode(decoded);
          } catch (_) {
            // 解码失败则忽略
          }
        } else if (responseData is String) {
          try {
            responseData = json.decode(responseData);
          } catch (_) {
            // 解析失败则忽略
          }
        }

        if (responseData is Map<String, dynamic>) {
          // 兼容 OpenAI 错误格式: {"error": {"message": "..."}}
          if (responseData['error'] is Map<String, dynamic>) {
            final errorDetail = responseData['error'] as Map<String, dynamic>;
            if (errorDetail['message'] != null) {
              return '${errorDetail['message']} ($statusCode)';
            }
          }
          // 兼容通用错误格式: {"message": "..."}
          if (responseData['message'] != null) {
            return '${responseData['message']} ($statusCode)';
          }
          // 兼容其他错误格式: {"error": "..."}
          if (responseData['error'] is String) {
            return '${responseData['error']} ($statusCode)';
          }
        }

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
