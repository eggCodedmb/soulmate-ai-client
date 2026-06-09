import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/local_storage.dart';
import '../../shared/models/asr_config.dart';

/// ASR API 客户端
///
/// 支持两种服务商：
/// - **自定义接入 (custom)** — OpenAI Whisper API 格式
///   - POST {baseUrl}/v1/audio/transcriptions
///   - multipart/form-data
///   - Response: {"text": "..."}
///
/// - **小米 MiMo (mimo)** — Chat Completions 格式
///   - POST {baseUrl}/v1/chat/completions
///   - JSON body，音频 Base64 编码
///   - Response: {"choices":[{"message":{"content":"..."}}]}
class AsrApiClient {
  Dio? _dio;

  /// 从 LocalStorage 读取当前配置
  AsrConfig get asrConfig => AsrConfig(
        providerType: LocalStorage.asrProviderType,
        baseUrl: LocalStorage.asrBaseUrl,
        apiKey: LocalStorage.asrApiKey,
        model: LocalStorage.asrModel,
      );

  /// 构建 Dio 实例
  Dio get _client {
    if (_dio != null) return _dio!;

    final config = asrConfig;
    _dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl ?? '',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        headers: {
          if (config.apiKey != null && config.apiKey!.isNotEmpty)
            'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
      ),
    );

    return _dio!;
  }

  /// 重置 Dio 实例（配置变更后调用）
  void reset() {
    _dio?.close();
    _dio = null;
  }

  /// 语音转文字（根据 providerType 自动选择接口）
  Future<String> transcribe(String audioFilePath) async {
    final config = asrConfig;

    if (!config.isCustomReady && !config.isMimo) {
      throw Exception('ASR 配置不完整，请检查服务器地址');
    }

    // 每次请求前重置，确保使用最新配置
    reset();

    switch (config.providerType) {
      case 'mimo':
        return _transcribeMimo(audioFilePath, config);
      case 'custom':
      default:
        return _transcribeWhisper(audioFilePath, config);
    }
  }

  // ==================== 小米 MiMo ASR ====================

  /// 小米 mimo-v2.5-asr
  ///
  /// 请求格式：JSON，音频 Base64 编码
  /// 响应格式：Chat Completions（choices[0].message.content）
  Future<String> _transcribeMimo(
    String audioFilePath,
    AsrConfig config,
  ) async {
    final file = File(audioFilePath);
    final bytes = await file.readAsBytes();
    final base64Audio = base64Encode(bytes);

    // 根据文件扩展名确定 MIME 类型
    final ext = audioFilePath.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'wav' => 'audio/wav',
      'mp3' => 'audio/mpeg',
      _ => 'audio/wav',
    };

    final requestBody = {
      'model': config.model ?? 'mimo-v2.5-asr',
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_audio',
              'input_audio': {
                'data': 'data:$mimeType;base64,$base64Audio',
              },
            },
          ],
        },
      ],
      'asr_options': {
        'language': 'auto',
      },
    };

    try {
      final response = await _client.post<dynamic>(
        '/v1/chat/completions',
        data: requestBody,
      );

      final data = response.data;

      // Chat Completions 格式: {"choices":[{"message":{"content":"..."}}]}
      if (data is Map<String, dynamic>) {
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0] as Map<String, dynamic>;
          final msgContent = message['message'] as Map<String, dynamic>?;
          if (msgContent != null) {
            return msgContent['content'] as String? ?? '';
          }
        }
      }

      debugPrint('MiMo ASR 响应格式未知: $data');
      return '';
    } on DioException catch (e) {
      debugPrint('MiMo ASR 请求失败: ${e.type} ${e.message}');
      _throwSpecificError(e);
    }
  }

  // ==================== OpenAI Whisper API ====================

  /// OpenAI Whisper API 格式
  ///
  /// 请求格式：multipart/form-data
  /// 响应格式：{"text": "..."}
  Future<String> _transcribeWhisper(
    String audioFilePath,
    AsrConfig config,
  ) async {
    // Whisper 使用 multipart，需要单独的 Dio 实例（不设 Content-Type: json）
    reset();
    final whisperDio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl ?? '',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        headers: {
          if (config.apiKey != null && config.apiKey!.isNotEmpty)
            'Authorization': 'Bearer ${config.apiKey}',
        },
      ),
    );

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(audioFilePath),
      if (config.model != null && config.model!.isNotEmpty)
        'model': config.model,
    });

    try {
      final response = await whisperDio.post<dynamic>(
        '/v1/audio/transcriptions',
        data: formData,
      );

      final data = response.data;

      // OpenAI 标准: {"text": "..."}
      // 包装格式: {"code": 0, "data": {"text": "..."}}
      if (data is Map<String, dynamic>) {
        if (data.containsKey('text')) {
          return data['text'] as String? ?? '';
        }
        if (data.containsKey('data')) {
          final inner = data['data'];
          if (inner is Map<String, dynamic> && inner.containsKey('text')) {
            return inner['text'] as String? ?? '';
          }
          if (inner is String) return inner;
        }
      }

      debugPrint('Whisper ASR 响应格式未知: $data');
      return '';
    } on DioException catch (e) {
      debugPrint('Whisper ASR 请求失败: ${e.type} ${e.message}');
      _throwSpecificError(e);
    } finally {
      whisperDio.close();
    }
  }

  // ==================== 通用 ====================

  Never _throwSpecificError(DioException e) {
    if (e.response?.statusCode == 401) {
      throw Exception('ASR API Key 无效');
    }
    if (e.response?.statusCode == 429) {
      throw Exception('ASR 请求过于频繁，请稍后重试');
    }
    throw Exception('ASR 请求失败: ${e.message}');
  }
}
