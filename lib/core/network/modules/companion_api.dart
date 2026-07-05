import 'package:dio/dio.dart';
import '../../../shared/models/companion.dart';
import '../api_service.dart';

/// AI伴侣模块 API
mixin CompanionMixin {
  Dio get dio;
  dynamic unwrap(Response<dynamic> response);

  /// 创建伴侣
  Future<Companion> createCompanion(CreateCompanionRequest request) async {
    final response = await dio.post<dynamic>('/api/companion', data: request.toJson());
    return Companion.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  /// 获取伴侣列表
  Future<List<Companion>> getCompanionList() async {
    final response = await dio.get<dynamic>('/api/companion/list');
    final data = unwrap(response) as List<dynamic>;
    return data
        .map((e) => Companion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取伴侣详情
  Future<Companion> getCompanion(int id) async {
    final response = await dio.get<dynamic>('/api/companion/$id');
    return Companion.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  /// 更新伴侣
  Future<void> updateCompanion(int id, Companion companion) async {
    final response = await dio.put<dynamic>('/api/companion/$id', data: companion.toJson());
    unwrap(response);
  }

  /// 更新伴侣头像
  Future<void> updateCompanionAvatar(int id, String? avatarUrl) async {
    final response = await dio.put<dynamic>(
      '/api/companion/$id/avatar',
      data: {'avatarUrl': avatarUrl},
    );
    unwrap(response);
  }

  /// 删除伴侣
  Future<void> deleteCompanion(int id) async {
    final response = await dio.delete<dynamic>('/api/companion/$id');
    unwrap(response);
  }

  /// 删除单条消息
  Future<void> deleteMessage(int messageId) async {
    final response = await dio.delete<dynamic>('/api/message/$messageId');
    unwrap(response);
  }
}
