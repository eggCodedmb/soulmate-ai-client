import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// 会员等级
enum MemberTier {
  free,
  basic,
  pro,
  premium,
}

/// 会员等级标签组件
///
/// 用法：
/// ```dart
/// MembershipBadge(tier: MemberTier.pro)
/// MembershipBadge.fromPlanCode(planCode: 'basic_monthly')
/// ```
class MembershipBadge extends StatelessWidget {
  final MemberTier tier;
  final bool compact;

  const MembershipBadge({
    super.key,
    required this.tier,
    this.compact = false,
  });

  /// 从 planCode 自动识别等级
  factory MembershipBadge.fromPlanCode({
    Key? key,
    required String planCode,
    bool compact = false,
  }) {
    return MembershipBadge(
      key: key,
      tier: tierFromCode(planCode),
      compact: compact,
    );
  }

  /// 从 planCode 列表取最高等级
  factory MembershipBadge.fromPlanCodes({
    Key? key,
    required List<String> planCodes,
    bool compact = false,
  }) {
    var highest = MemberTier.free;
    for (final code in planCodes) {
      final t = tierFromCode(code);
      if (t.index > highest.index) highest = t;
    }
    return MembershipBadge(
      key: key,
      tier: highest,
      compact: compact,
    );
  }

  /// 从 planCode 识别会员等级
  static MemberTier tierFromCode(String code) {
    final lower = code.toLowerCase();
    if (lower.contains('premium') || lower.contains('ultimate') || lower.contains('尊享')) {
      return MemberTier.premium;
    }
    if (lower.contains('pro') || lower.contains('专业')) return MemberTier.pro;
    if (lower.contains('basic') || lower.contains('plus') || lower.contains('基础')) {
      return MemberTier.basic;
    }
    return MemberTier.free;
  }

  @override
  Widget build(BuildContext context) {
    if (tier == MemberTier.free) return const SizedBox.shrink();

    final config = _getConfig();
    final fontSize = compact ? 10.0 : 11.0;
    final hPad = compact ? 6.0 : 8.0;
    final vPad = compact ? 2.0 : 3.0;
    final iconSize = compact ? 10.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: config.gradientColors,
        ),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        boxShadow: tier == MemberTier.premium
            ? [
                BoxShadow(
                  color: config.accentColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: iconSize, color: Colors.white),
          SizedBox(width: compact ? 3 : 4),
          Text(
            config.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getConfig() {
    switch (tier) {
      case MemberTier.free:
        return const _BadgeConfig(
          gradientColors: [Color(0xFF8E8E93), Color(0xFF636366)],
          accentColor: Color(0xFF8E8E93),
          icon: Icons.person_rounded,
          label: '免费',
        );
      case MemberTier.basic:
        return const _BadgeConfig(
          gradientColors: [Color(0xFF5AC8FA), Color(0xFF34C759)],
          accentColor: Color(0xFF5AC8FA),
          icon: Icons.star_rounded,
          label: '基础会员',
        );
      case MemberTier.pro:
        return const _BadgeConfig(
          gradientColors: [AppColors.brandLavender, Color(0xFF818CF8)],
          accentColor: AppColors.brandLavender,
          icon: Icons.workspace_premium_rounded,
          label: '专业会员',
        );
      case MemberTier.premium:
        return const _BadgeConfig(
          gradientColors: [AppColors.brandPink, AppColors.brandLavender, AppColors.brandWarmPeach],
          accentColor: AppColors.brandWarmPeach,
          icon: Icons.diamond_rounded,
          label: '尊享会员',
        );
    }
  }
}

class _BadgeConfig {
  final List<Color> gradientColors;
  final Color accentColor;
  final IconData icon;
  final String label;

  const _BadgeConfig({
    required this.gradientColors,
    required this.accentColor,
    required this.icon,
    required this.label,
  });
}
