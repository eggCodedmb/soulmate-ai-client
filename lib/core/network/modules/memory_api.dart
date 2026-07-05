import 'package:dio/dio.dart';
import '../../../shared/models/memory.dart';
import '../../../shared/models/memory_stats.dart';

/// 记忆模块 API
mixin MemoryMixin {
  Dio get dio;
  dynamic unwrap(Response<dynamic> response);

  /// 获取记忆列表
  Future<List<Memory>> getMemoryList({
    int? companionId,
    String? category,
  }) async {
    final queryParams = <String, dynamic>{};
    if (companionId != null) queryParams['companionId'] = companionId;
    if (category != null) queryParams['category'] = category;

    final response = await dio.get<dynamic>(
      '/api/memory/list',
      queryParameters: queryParams,
    );
    final data = unwrap(response) as List<dynamic>;
    return data
        .map((e) => Memory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取记忆统计数据
  Future<MemoryStats> getMemoryStats({int? companionId}) async {
    final queryParams = <String, dynamic>{};
    if (companionId != null) queryParams['companionId'] = companionId;

    final response = await dio.get<dynamic>(
      '/api/memory/stats',
      queryParameters: queryParams,
    );
    final data = unwrap(response) as Map<String, dynamic>;
    return MemoryStats.fromJson(data);
  }

  /// 更新记忆
  Future<void> updateMemory(int id, Memory memory) async {
    final response = await dio.put<dynamic>('/api/memory/$id', data: memory.toJson());
    unwrap(response);
  }

  /// 删除记忆
  Future<void> deleteMemory(int id) async {
    final response = await dio.delete<dynamic>('/api/memory/$id');
    unwrap(response);
  }
}
