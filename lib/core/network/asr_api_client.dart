import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
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

    if (config.providerType != 'sherpa_onnx' && !config.isCustomReady && !config.isMimo) {
      throw Exception('ASR 配置不完整，请检查服务器地址');
    }

    // 每次请求前重置，确保使用最新配置
    reset();

    switch (config.providerType) {
      case 'sherpa_onnx':
        return _transcribeSherpaOnnx(audioFilePath);
      case 'mimo':
        return _transcribeMimo(audioFilePath, config);
      case 'custom':
      default:
        return _transcribeWhisper(audioFilePath, config);
    }
  }

  /// 本地离线语音识别 (SenseVoice 模型)
  Future<String> _transcribeSherpaOnnx(String audioFilePath) async {
    return SherpaOnnxAsrService.decodeAudioFile(audioFilePath);
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

/// Sherpa-ONNX 离线识别器单例服务（驻留内存，规避每次重新加载 200MB+ 模型）
class SherpaOnnxAsrService {
  static sherpa_onnx.OfflineRecognizer? _recognizer;
  static String? _loadedModelPath;
  static bool _isInitializing = false;

  /// 预热 / 初始化识别器
  static Future<sherpa_onnx.OfflineRecognizer?> getRecognizer({
    String? modelPath,
    String? tokensPath,
  }) async {
    if (_recognizer != null) {
      return _recognizer;
    }

    if (_isInitializing) {
      while (_isInitializing) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (_recognizer != null) return _recognizer;
    }

    _isInitializing = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final targetModelPath = modelPath ?? '${dir.path}/models/sensevoice.onnx';
      final targetTokensPath = tokensPath ?? '${dir.path}/models/sensevoice-tokens.txt';

      if (!await File(targetModelPath).exists() || !await File(targetTokensPath).exists()) {
        return null;
      }

      sherpa_onnx.initBindings();

      final senseVoice = sherpa_onnx.OfflineSenseVoiceModelConfig(
        model: targetModelPath,
        language: 'auto',
        useInverseTextNormalization: true,
      );

      final modelConfig = sherpa_onnx.OfflineModelConfig(
        senseVoice: senseVoice,
        tokens: targetTokensPath,
        numThreads: 2,
        debug: false,
      );

      final config = sherpa_onnx.OfflineRecognizerConfig(
        model: modelConfig,
      );

      _recognizer = sherpa_onnx.OfflineRecognizer(config);
      _loadedModelPath = targetModelPath;
      debugPrint('[SherpaOnnxAsrService] 本地 SenseVoice ASR 识别器加载成功并已常驻内存');
      return _recognizer;
    } catch (e) {
      debugPrint('[SherpaOnnxAsrService] 识别器初始化失败: $e');
      return null;
    } finally {
      _isInitializing = false;
    }
  }

  /// 释放识别器资源
  static void dispose() {
    try {
      _recognizer?.free();
    } catch (_) {}
    _recognizer = null;
    _loadedModelPath = null;
  }

  /// 执行快速文本识别（复用常驻识别器）
  static Future<String> decodeAudioFile(String audioFilePath) async {
    final recognizer = await getRecognizer();
    if (recognizer == null) {
      throw Exception('本地 ASR 模型未找到。请前往「设置 → 离线模型管理」下载 SenseVoice 识别模型。');
    }

    final file = File(audioFilePath);
    final bytes = await file.readAsBytes();

    int sampleRate = 16000;
    Uint8List pcmBytes;

    if (audioFilePath.toLowerCase().endsWith('.wav') && bytes.length > 44) {
      final byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
      sampleRate = byteData.getUint32(24, Endian.little);
      int dataOffset = 44;
      for (int i = 12; i < bytes.length - 8; i++) {
        if (bytes[i] == 0x64 &&
            bytes[i + 1] == 0x61 &&
            bytes[i + 2] == 0x74 &&
            bytes[i + 3] == 0x61) {
          dataOffset = i + 8;
          break;
        }
      }
      pcmBytes = Uint8List.fromList(bytes.sublist(dataOffset));
    } else {
      pcmBytes = Uint8List.fromList(bytes);
    }

    final int16List = Int16List.view(
      pcmBytes.buffer,
      pcmBytes.offsetInBytes,
      pcmBytes.lengthInBytes ~/ 2,
    );
    final float32List = Float32List(int16List.length);
    for (int i = 0; i < int16List.length; i++) {
      float32List[i] = int16List[i] / 32768.0;
    }

    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: float32List, sampleRate: sampleRate);
      recognizer.decode(stream);

      final result = recognizer.getResult(stream);
      return result.text.trim();
    } finally {
      stream.free();
    }
  }
}
