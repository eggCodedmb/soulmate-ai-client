import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/subscription.dart';
import '../../shared/widgets/membership_badge.dart';

/// 会员状态卡片组件
///
/// 用法：
/// ```dart
/// // 免费用户 — 显示升级入口
/// MembershipCard.free(onTap: () => context.push('/profile/subscription'))
///
/// // 会员用户 — 显示当前会员状态
/// MembershipCard.member(plan: plan, subscription: sub, onTap: ...)
/// ```
class MembershipCard extends StatelessWidget {
  final MemberTier tier;
  final String? planName;
  final DateTime? expireTime;
  final VoidCallback? onTap;

  const MembershipCard._({
    super.key,
    required this.tier,
    this.planName,
    this.expireTime,
    this.onTap,
  });

  /// 免费用户卡片（升级入口）
  factory MembershipCard.free({
    Key? key,
    VoidCallback? onTap,
  }) {
    return MembershipCard._(
      key: key,
      tier: MemberTier.free,
      onTap: onTap,
    );
  }

  /// 会员用户卡片
  factory MembershipCard.member({
    Key? key,
    required SubscriptionPlan plan,
    required UserSubscription subscription,
    VoidCallback? onTap,
  }) {
    return MembershipCard._(
      key: key,
      tier: MembershipBadge.tierFromCode(plan.planCode),
      planName: plan.planName,
      expireTime: subscription.endTime,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (tier == MemberTier.free) {
      return _buildFreeCard(context, isDark);
    }
    return _buildMemberCard(context, isDark);
  }

  // ==================== 免费用户卡片 ====================

  Widget _buildFreeCard(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF2D1520), const Color(0xFF1A1025)]
                : [AppColors.brandPink, AppColors.brandLavender],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandPink.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '升级会员',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '解锁更多伴侣 · 无限对话 · 高级记忆',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '立即升级',
                style: TextStyle(
                  color: isDark ? AppColors.brandPinkDark : AppColors.brandPink,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  // ==================== 会员卡片 ====================

  Widget _buildMemberCard(BuildContext context, bool isDark) {
    final config = _getTierConfig(isDark);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: config.gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: tier.index >= 2
              ? Border.all(
                  color: config.accentColor.withValues(alpha: 0.3),
                  width: 1.5,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: config.accentColor.withValues(alpha: 0.25 + tier.index * 0.05),
              blurRadius: 12.0 + tier.index * 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 等级图标
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                boxShadow: tier.index >= 2
                    ? [
                        BoxShadow(
                          color: config.accentColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(config.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          planName ?? '会员',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      MembershipBadge(tier: tier, compact: true),
                    ],
                  ),
                  if (expireTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '有效期至 ${_formatDate(expireTime!)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  _CardConfig _getTierConfig(bool isDark) {
    switch (tier) {
      case MemberTier.free:
        return _CardConfig(
          gradientColors: isDark
              ? [const Color(0xFF2D1520), const Color(0xFF1A1025)]
              : [AppColors.brandPink, AppColors.brandLavender],
          accentColor: AppColors.brandPink,
          icon: Icons.workspace_premium_rounded,
        );
      case MemberTier.basic:
        return _CardConfig(
          gradientColors: isDark
              ? [const Color(0xFF1C1C1E), const Color(0xFF0D0D0F)]
              : [const Color(0xFF5AC8FA), const Color(0xFF34C759)],
          accentColor: const Color(0xFF5AC8FA),
          icon: Icons.star_rounded,
        );
      case MemberTier.pro:
        return _CardConfig(
          gradientColors: isDark
              ? [const Color(0xFF1A1025), const Color(0xFF0D0D0F)]
              : [AppColors.brandLavender, const Color(0xFF818CF8)],
          accentColor: AppColors.brandLavender,
          icon: Icons.workspace_premium_rounded,
        );
      case MemberTier.premium:
        return _CardConfig(
          gradientColors: isDark
              ? [const Color(0xFF2D1520), const Color(0xFF1A0A10)]
              : [AppColors.brandPink, AppColors.brandLavender, AppColors.brandWarmPeach],
          accentColor: AppColors.brandWarmPeach,
          icon: Icons.diamond_rounded,
        );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

class _CardConfig {
  final List<Color> gradientColors;
  final Color accentColor;
  final IconData icon;

  const _CardConfig({
    required this.gradientColors,
    required this.accentColor,
    required this.icon,
  });
}
