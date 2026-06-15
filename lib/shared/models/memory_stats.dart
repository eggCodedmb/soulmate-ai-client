/// 长期记忆统计信息
class MemoryStats {
  final int totalMemories;
  final double averageImportance;
  final int categoryCount;

  const MemoryStats({
    required this.totalMemories,
    required this.averageImportance,
    required this.categoryCount,
  });

  factory MemoryStats.fromJson(Map<String, dynamic> json) {
    return MemoryStats(
      totalMemories: (json['totalMemories'] as num?)?.toInt() ?? 0,
      averageImportance: (json['averageImportance'] as num?)?.toDouble() ?? 0.0,
      categoryCount: (json['categoryCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalMemories': totalMemories,
    'averageImportance': averageImportance,
    'categoryCount': categoryCount,
  };
}
