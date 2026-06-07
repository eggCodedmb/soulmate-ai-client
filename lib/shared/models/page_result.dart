/// 分页结果包装类
class PageResult<T> {
  final List<T> records;
  final int total;
  final int page;
  final int size;

  const PageResult({
    required this.records,
    required this.total,
    required this.page,
    required this.size,
  });

  /// 是否还有更多数据
  bool get hasMore => records.length == size;

  /// 工厂方法：从 JSON 解析，需要提供 records 的解析函数
  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PageResult(
      records: (json['records'] as List<dynamic>)
          .map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      size: (json['size'] as num).toInt(),
    );
  }
}
