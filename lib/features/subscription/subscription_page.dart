import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/alipay_service.dart';
import '../../core/network/api_service.dart';
import '../../shared/models/subscription.dart';
import '../../shared/models/subscription_status.dart';
import 'payment_method_page.dart';
import 'payment_webview_page.dart';
import 'providers/subscription_providers.dart';
import 'subscription_terms_page.dart';

/// 订阅会员页
class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage>
    with SingleTickerProviderStateMixin {
  bool _isPaying = false;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);
    final statusAsync = ref.watch(subscriptionStatusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF5F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            _buildAppBar(context, isDark),
            // 主内容
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    ref.read(subscriptionPlansProvider.notifier).refresh(),
                    ref.read(currentSubscriptionProvider.notifier).refresh(),
                    ref.read(subscriptionStatusProvider.notifier).refresh(),
                  ]);
                },
                color: AppColors.brandPink,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // 区域 1: 当前订阅状态
                    _buildCurrentStatus(context, statusAsync, isDark),
                    const SizedBox(height: 24),
                    // 区域 2: 套餐选择
                    _buildPlanSection(context, plansAsync, subscriptionAsync, isDark),
                    const SizedBox(height: 24),
                    // 区域 3: 底部说明
                    _buildBottomNotes(context, isDark),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部导航栏
  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 22,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Text(
            '订阅会员',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // 占位，保持标题居中
        ],
      ),
    );
  }

  // ==================== 区域 1: 当前订阅状态 ====================

  Widget _buildCurrentStatus(
    BuildContext context,
    AsyncValue<SubscriptionStatus?> subscriptionAsync,
    bool isDark,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: subscriptionAsync.when(
        loading: () => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: CircularProgressIndicator(
              color: isDark ? AppColors.brandPink : colorScheme.primary,
              strokeWidth: 2.5,
            ),
          ),
        ),
        error: (e, _) => _buildFreeUserStatus(context, null, isDark),
        data: (status) {
          if (status == null || status.planCode == 'FREE') {
            return _buildFreeUserStatus(context, status, isDark);
          }
          return _buildSubscribedStatus(context, status, isDark);
        },
      ),
    );
  }

  /// 免费用户状态
  Widget _buildFreeUserStatus(BuildContext context, SubscriptionStatus? status, bool isDark) {
    final usedMessages = status?.todayUsedMessages ?? 0;
    final maxMessages = status?.maxDailyMessages ?? 50;
    final progress = maxMessages > 0 ? (usedMessages / maxMessages).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandPink, AppColors.brandLavender],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '免费版',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '升级会员解锁全部功能',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.5)
                        : Colors.black.withOpacity(0.4),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        // 消息额度进度条
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '今日消息额度',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.6)
                          : Colors.black.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '$usedMessages / $maxMessages 条',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.06),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.brandPink,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 升级提示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.brandPink.withOpacity(isDark ? 0.1 : 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.brandPink.withOpacity(isDark ? 0.2 : 0.15),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.rocket_launch_rounded,
                color: AppColors.brandPink,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '升级会员解锁无限消息、高级记忆等功能',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.8)
                        : Colors.black.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 已订阅用户状态
  Widget _buildSubscribedStatus(
    BuildContext context,
    SubscriptionStatus status,
    bool isDark,
  ) {
    final planName = status.planName ?? '未知套餐';
    final endDate = status.expireTime ?? DateTime.now();
    final dateStr =
        '${endDate.year}/${endDate.month.toString().padLeft(2, '0')}/${endDate.day.toString().padLeft(2, '0')}';
    final daysLeft = endDate.difference(DateTime.now()).inDays > 0 
        ? endDate.difference(DateTime.now()).inDays 
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ),
                borderRadius: BorderRadius.circular(16),
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
                  Row(
                    children: [
                      Text(
                        planName,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF4CAF50).withOpacity(isDark ? 0.4 : 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF4CAF50),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '生效中',
                              style: TextStyle(
                                color: const Color(0xFF4CAF50),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '还有 $daysLeft 天到期',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.5)
                          : Colors.black.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // 订阅信息卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.calendar_today_rounded,
                '到期时间',
                dateStr,
                isDark,
              ),
              const SizedBox(height: 12),
              Divider(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
                height: 1,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.mark_chat_read_rounded,
                '消息额度',
                status.maxDailyMessages == -1 
                    ? '无限量' 
                    : '剩余 ${status.remainingMessages} / ${status.maxDailyMessages}',
                isDark,
                valueColor: status.maxDailyMessages == -1 || (status.remainingMessages ?? 0) > 0
                    ? const Color(0xFF4CAF50)
                    : Colors.red,
              ),
              const SizedBox(height: 12),
              Divider(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
                height: 1,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.people_alt_rounded,
                '伴侣名额',
                status.maxCompanions == -1
                    ? '无限量'
                    : '已用 ${status.currentCompanions} / ${status.maxCompanions}',
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(
          icon,
          color: isDark
              ? Colors.white.withOpacity(0.5)
              : Colors.black.withOpacity(0.4),
          size: 18,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? Colors.white.withOpacity(0.6)
                : Colors.black.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ??
                (isDark ? Colors.white : Colors.black),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==================== 区域 2: 套餐选择 ====================

  Widget _buildPlanSection(
    BuildContext context,
    AsyncValue<List<SubscriptionPlan>> plansAsync,
    AsyncValue<UserSubscription?> subscriptionAsync,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择套餐',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '选择适合你的会员套餐',
          style: TextStyle(
            color: isDark
                ? Colors.white.withOpacity(0.5)
                : Colors.black.withOpacity(0.4),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        plansAsync.when(
          loading: () => Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: CircularProgressIndicator(
                color: isDark ? AppColors.brandPink : Theme.of(context).colorScheme.primary,
                strokeWidth: 2.5,
              ),
            ),
          ),
          error: (e, _) => Center(
            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  '加载失败，请下拉刷新',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.5)
                        : Colors.black.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          data: (plans) {
            // 按 displayOrder 排序，排除免费套餐
            final sortedPlans = plans
                .where((p) => p.planCode != 'FREE' && p.status == 1)
                .toList()
              ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

            final currentPlanId = subscriptionAsync.valueOrNull?.planId;
            // 获取当前套餐的 displayOrder，用于判断是否降级
            final currentPlanDisplayOrder = currentPlanId != null
                ? sortedPlans
                        .where((p) => p.id == currentPlanId)
                        .firstOrNull
                        ?.displayOrder ??
                    0
                : 0;
            // 推荐套餐: 中间档（Premium）
            final recommendedCode =
                sortedPlans.length >= 2 ? sortedPlans[1].planCode : null;

            return Column(
              children: sortedPlans.asMap().entries.map((entry) {
                final index = entry.key;
                final plan = entry.value;
                final isCurrent = plan.id == currentPlanId;
                // 判断是否降级：目标套餐 displayOrder <= 当前套餐 displayOrder
                final isDowngrade = currentPlanId != null &&
                    plan.displayOrder <= currentPlanDisplayOrder;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < sortedPlans.length - 1 ? 16 : 0,
                  ),
                  child: _buildPlanCard(
                    context,
                    plan,
                    index: index,
                    isRecommended: plan.planCode == recommendedCode,
                    isCurrent: isCurrent,
                    isDowngrade: isDowngrade && !isCurrent,
                    isDark: isDark,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    SubscriptionPlan plan, {
    int index = 0,
    bool isRecommended = false,
    bool isCurrent = false,
    bool isDowngrade = false,
    required bool isDark,
  }) {
    final benefits = _getPlanBenefits(context, plan);
    final isDisabled = isCurrent || isDowngrade;

    // 卡片渐变色
    final gradients = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)], // 蓝紫
      [const Color(0xFFf093fb), const Color(0xFFf5576c)], // 粉红（推荐）
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)], // 青蓝
    ];

    final gradientIndex = isRecommended ? 1 : (index % 2 == 0 ? 0 : 2);
    final gradient = gradients[gradientIndex];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isRecommended
            ? Border.all(
                color: AppColors.brandPink.withOpacity(isDark ? 0.4 : 0.3),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 背景装饰
            if (isRecommended)
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.brandPink.withOpacity(isDark ? 0.15 : 0.08),
                        AppColors.brandPink.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            // 内容
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 套餐名 + 推荐标签
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradient,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          plan.planName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  const Color(0xFFFFD700).withOpacity(isDark ? 0.4 : 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFD700),
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '推荐',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 价格
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${plan.priceMonthly.toInt()}',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '/月',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withOpacity(0.5)
                                : Colors.black.withOpacity(0.4),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 分割线
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          isDark
                              ? Colors.white.withOpacity(0.0)
                              : Colors.black.withOpacity(0.0),
                          isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.06),
                          isDark
                              ? Colors.white.withOpacity(0.0)
                              : Colors.black.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 权益列表
                  ...benefits.map((benefit) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(isDark ? 0.15 : 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Color(0xFF4CAF50),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                benefit,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.8)
                                      : Colors.black.withOpacity(0.7),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 28),
                  // 订阅按钮
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isDisabled || _isPaying
                          ? null
                          : () => _startPayment(context, plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: isDisabled
                              ? null
                              : LinearGradient(
                                  colors: gradient,
                                ),
                          color: isDisabled
                              ? (isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.05))
                              : null,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: _isPaying && !isDisabled
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isCurrent
                                      ? '当前套餐'
                                      : isDowngrade
                                          ? '不可降级'
                                          : '立即订阅',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDisabled
                                        ? (isDark
                                            ? Colors.white.withOpacity(0.3)
                                            : Colors.black.withOpacity(0.25))
                                        : Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 区域 3: 底部说明 ====================

  Widget _buildBottomNotes(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: isDark
                    ? Colors.white.withOpacity(0.4)
                    : Colors.black.withOpacity(0.3),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                '订阅须知',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.7)
                      : Colors.black.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '订阅将自动续费，到期前24小时自动扣款。如需取消，请在到期前至少24小时关闭自动续费。取消后可正常使用至到期日。',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withOpacity(0.4)
                  : Colors.black.withOpacity(0.35),
              fontSize: 12,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SubscriptionTermsPage(),
                ),
              );
            },
            child: Text(
              '《订阅服务条款》',
              style: TextStyle(
                color: AppColors.brandPink.withOpacity(isDark ? 0.7 : 0.6),
                fontSize: 12,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.brandPink.withOpacity(isDark ? 0.5 : 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 工具方法 ====================

  /// 根据套餐权益生成描述列表
  List<String> _getPlanBenefits(BuildContext context, SubscriptionPlan plan) {
    final benefits = <String>[];

    // 消息额度
    if (plan.maxDailyMessages == -1) {
      benefits.add('无限消息');
    } else {
      benefits.add('每日 ${plan.maxDailyMessages} 条消息');
    }

    // 伴侣数量
    if (plan.maxCompanions == -1) {
      benefits.add('无限伴侣');
    } else {
      benefits.add('最多 ${plan.maxCompanions} 个伴侣');
    }

    // 功能权益
    if (plan.voiceMessage == 1) benefits.add('语音消息');
    if (plan.voiceCall == 1) benefits.add('语音通话');
    if (plan.advancedMemory == 1) benefits.add('高级记忆');
    if (plan.customVoice == 1) benefits.add('自定义音色');
    if (plan.priorityResponse == 1) benefits.add('优先响应');

    return benefits;
  }

  /// 发起支付
  Future<void> _startPayment(
    BuildContext context,
    SubscriptionPlan plan,
  ) async {
    if (_isPaying) return;

    // 确认弹窗
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildPaymentConfirmSheet(ctx, plan),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _isPaying = true);

    try {
      final api = ref.read(apiServiceProvider);
      final payment = await api.createPayment(plan.id);

      if (!context.mounted) return;

      // 弹出支付方式选择页面
      final paymentChannel = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => PaymentMethodPage(
            plan: plan,
            orderNo: payment.orderNo,
          ),
        ),
      );

      if (paymentChannel == null || !context.mounted) {
        return;
      }

      // 目前仅支持支付宝
      if (paymentChannel != 'alipay') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('该支付方式暂未开放，敬请期待'),
              backgroundColor: Colors.orange.withOpacity(0.9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      // 检测支付方式：优先APP支付，降级为网页支付
      final alipayService = AlipayService();
      final payMode = await alipayService.getRecommendedPayMode();

      if (payMode == AlipayPayMode.app) {
        // 尝试唤起支付宝APP支付
        final launched = await alipayService.launchAlipayApp(payment.payForm);
        if (launched) {
          // 成功唤起支付宝APP，轮询订单状态
          if (context.mounted) {
            await _pollPaymentResult(context, payment.orderNo);
          }
          return;
        }
        // 唤起失败，降级为网页支付
        debugPrint('唤起支付宝APP失败，降级为网页支付');
      }

      // 打开支付宝 WebView（降级方案或未安装APP时）
      final orderNo = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewPage(
            payForm: payment.payForm,
            orderNo: payment.orderNo,
          ),
        ),
      );

      // 用户从支付页面返回，轮询订单状态
      if (orderNo != null && context.mounted) {
        await _pollPaymentResult(context, orderNo);
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getPaymentErrorMessage(e)),
            backgroundColor: Colors.red.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('网络异常，请检查网络后重试'),
            backgroundColor: Colors.red.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      debugPrint('支付创建异常: $e');
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  /// 获取支付错误的友好提示
  String _getPaymentErrorMessage(ApiException e) {
    switch (e.code) {
      case 1001:
        return '套餐不存在或已下架';
      case 1002:
        return '您已订阅该套餐，无需重复购买';
      case 1003:
        return '订单创建失败，请稍后重试';
      case 1004:
        return '支付渠道不可用，请选择其他支付方式';
      case 1005:
        return '支付金额异常，请联系客服';
      default:
        return '支付创建失败: ${e.message}';
    }
  }

  /// 支付确认底部弹窗
  Widget _buildPaymentConfirmSheet(BuildContext context, SubscriptionPlan plan) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示器
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // 标题
          Text(
            '确认订阅 ${plan.planName}',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          // 价格信息
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '¥${plan.priceMonthly.toInt()}',
                  style: const TextStyle(
                    color: AppColors.brandPink,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  ' /月',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.5)
                        : Colors.black.withOpacity(0.4),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 支付方式提示
          _buildPayModeHint(context, isDark),
          const SizedBox(height: 24),
          // 按钮
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.15)
                              : Colors.black.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '确认支付',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 支付方式提示
  Widget _buildPayModeHint(BuildContext context, bool isDark) {
    return FutureBuilder<bool>(
      future: AlipayService().isAlipayInstalled(),
      builder: (context, snapshot) {
        final isInstalled = snapshot.data ?? false;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isInstalled ? Icons.check_circle_outline : Icons.info_outline,
                color: isInstalled
                    ? const Color(0xFF4CAF50)
                    : Colors.orange.withOpacity(0.8),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isInstalled
                      ? '已检测到支付宝APP，将优先使用APP支付'
                      : '未检测到支付宝APP，将使用网页支付',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.6)
                        : Colors.black.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 轮询支付结果
  ///
  /// 使用指数退避策略：初始间隔2秒，最长间隔10秒，最多轮询30次（约2分钟）
  Future<void> _pollPaymentResult(
    BuildContext context,
    String orderNo,
  ) async {
    const maxAttempts = 30;
    const initialInterval = Duration(seconds: 2);
    const maxInterval = Duration(seconds: 10);
    const timeout = Duration(minutes: 2);

    final api = ref.read(apiServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stopwatch = Stopwatch()..start();

    // 显示加载弹窗
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: isDark ? AppColors.brandPink : Theme.of(context).colorScheme.primary,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                '正在确认支付...',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.7)
                      : Colors.black.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请勿关闭页面',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.4)
                      : Colors.black.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 使用指数退避策略轮询
    var paid = false;
    var attempts = 0;
    var currentInterval = initialInterval;

    while (attempts < maxAttempts && stopwatch.elapsed < timeout) {
      await Future<void>.delayed(currentInterval);
      attempts++;

      try {
        final order = await api.getPaymentStatus(orderNo);
        if (order.isPaid) {
          paid = true;
          break;
        }
        // 支付失败或已关闭
        if (order.paymentStatus == 2 || order.paymentStatus == 3) {
          break;
        }
      } on Exception catch (e) {
        debugPrint('轮询支付状态失败 (第${attempts}次): $e');
        // 查询失败继续重试，但增加间隔
      }

      // 指数退避，最大间隔10秒
      currentInterval = Duration(
        seconds: (currentInterval.inSeconds * 1.5).round().clamp(
              initialInterval.inSeconds,
              maxInterval.inSeconds,
            ),
      );
    }

    stopwatch.stop();

    // 关闭加载弹窗（使用 rootNavigator 确保关闭正确的对话框）
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    // 刷新订阅数据
    await ref.read(subscriptionPlansProvider.notifier).refresh();
    await ref.read(currentSubscriptionProvider.notifier).refresh();
    await ref.read(subscriptionStatusProvider.notifier).refresh();

    if (!context.mounted) return;

    if (paid) {
      _showSuccessDialog(context);
    } else {
      _showPaymentResultDialog(context, false);
    }
  }

  /// 显示支付结果对话框
  void _showPaymentResultDialog(BuildContext context, bool success) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                success ? Icons.check_circle : Icons.info_outline,
                color: success ? const Color(0xFF4CAF50) : Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                success ? '支付成功' : '支付未完成',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                success
                    ? '会员已生效，尽情享受吧！'
                    : '如果您已完成支付，系统可能需要一些时间处理。\n您可以在"我的订阅"中查看最新状态。',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.black.withOpacity(0.5),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('我知道了'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 支付成功弹窗
  void _showSuccessDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 成功图标
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '🎉 支付成功',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '会员已生效，尽情享受吧！',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.black.withOpacity(0.5),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '好的',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

