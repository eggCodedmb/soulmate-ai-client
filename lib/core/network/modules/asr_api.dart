import 'package:dio/dio.dart';

/// ASR 语音识别模块 API
mixin AsrMixin {
  Dio get dio;
  dynamic unwrap(Response<dynamic> response);

  /// 语音转文字
  ///
  /// 上传音频文件到 ASR 服务，返回识别出的文字。
  /// 支持格式：WAV, MP3, M4A, WEBM, OGG, FLAC（最大 25MB）
  Future<String> transcribeAudio(String audioFilePath) async {
    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(audioFilePath),
    });
    final response = await dio.post<dynamic>('/api/asr/transcribe', data: formData);
    final data = unwrap(response);
    return data as String? ?? '';
  }
}
