import 'package:flutter/material.dart';

/// SoulMate AI 阴影配置
class AppShadows {
  /// 层级1阴影（卡片）
  static List<BoxShadow> level1(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isLight ? 0.05 : 0.2),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// 层级2阴影（弹窗）
  static List<BoxShadow> level2(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isLight ? 0.1 : 0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// 层级3阴影（悬浮）
  static List<BoxShadow> level3(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isLight ? 0.15 : 0.4),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ];
  }
}
