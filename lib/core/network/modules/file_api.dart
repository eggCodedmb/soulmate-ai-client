import 'package:dio/dio.dart';
import '../api_service.dart';

/// 文件上传模块 API
mixin FileMixin {
  Dio get dio;
  dynamic unwrap(Response<dynamic> response);

  /// 单文件上传
  Future<UploadResult> uploadFile(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await dio.post<dynamic>('/api/file/upload', data: formData);
    return UploadResult.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  /// 删除文件
  Future<void> deleteFile(String filePath) async {
    final response = await dio.delete<dynamic>(
      '/api/file/delete',
      queryParameters: {'filePath': filePath},
    );
    unwrap(response);
  }
}
