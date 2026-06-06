import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/models/subscription.dart';
import 'payment_method_page.dart';
import 'payment_webview_page.dart';
import 'providers/subscription_providers.dart';

/// 订阅会员页
class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  bool _isPaying = false;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅会员'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(subscriptionPlansProvider.notifier).refresh(),
            ref.read(currentSubscriptionProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          children: [
            // 区域 1: 当前订阅状态
            _buildCurrentStatus(context, subscriptionAsync),
            const SizedBox(height: AppDimensions.spacingLarge),
            // 区域 2: 套餐选择
            _buildPlanSection(context, plansAsync, subscriptionAsync),
            const SizedBox(height: AppDimensions.spacingXLarge),
            // 区域 3: 底部说明
            _buildBottomNotes(context),
            const SizedBox(height: AppDimensions.spacingXLarge),
          ],
        ),
      ),
    );
  }

  // ==================== 区域 1: 当前订阅状态 ====================

  Widget _buildCurrentStatus(
    BuildContext context,
    AsyncValue<UserSubscription?> subscriptionAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        boxShadow: AppShadows.level1(context),
      ),
      child: subscriptionAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (e, _) => _buildFreeUserStatus(context),
        data: (subscription) {
          if (subscription == null) return _buildFreeUserStatus(context);
          return _buildSubscribedStatus(context, subscription);
        },
      ),
    );
  }

  /// 免费用户状态
  Widget _buildFreeUserStatus(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              color: colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Text(
              '免费版',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        Text(
          '每日消息额度',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppDimensions.spacingXSmall),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                child: LinearProgressIndicator(
                  value: 0.3,
                  minHeight: 8,
                  backgroundColor: colorScheme.outline.withOpacity(0.15),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Text(
              '9 / 30 条',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        Text(
          '升级会员解锁无限消息',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.brandPink,
              ),
        ),
      ],
    );
  }

  /// 已订阅用户状态
  Widget _buildSubscribedStatus(
    BuildContext context,
    UserSubscription subscription,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final planName = _getPlanNameById(subscription.planId);
    final endDate = subscription.endTime;
    final dateStr =
        '${endDate.year}/${endDate.month.toString().padLeft(2, '0')}/${endDate.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.brandPink,
              size: 28,
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Text(
              planName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Text(
                '生效中',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              '到期时间: $dateStr',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        Row(
          children: [
            Icon(
              Icons.autorenew_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              subscription.autoRenew == 1 ? '自动续费已开启' : '自动续费已关闭',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== 区域 2: 套餐选择 ====================

  Widget _buildPlanSection(
    BuildContext context,
    AsyncValue<List<SubscriptionPlan>> plansAsync,
    AsyncValue<UserSubscription?> subscriptionAsync,
  ) {
    return plansAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text('加载失败，请下拉刷新'),
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
        // 推荐套餐: 中间档（Premium）
        final recommendedCode = sortedPlans.length >= 2
            ? sortedPlans[1].planCode
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择套餐',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            ...sortedPlans.map((plan) => Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
                  child: _buildPlanCard(
                    context,
                    plan,
                    isRecommended: plan.planCode == recommendedCode,
                    isCurrent: plan.id == currentPlanId,
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    SubscriptionPlan plan, {
    bool isRecommended = false,
    bool isCurrent = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final benefits = _getPlanBenefits(context, plan);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: isRecommended
            ? Border.all(
                color: AppColors.brandPink,
                width: 1.5,
              )
            : null,
        boxShadow: AppShadows.level1(context),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 套餐名 + 价格
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.planName,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const Spacer(),
                    Text(
                      '¥${plan.priceMonthly.toInt()}',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.brandPink,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '/月',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                // 权益列表
                ...benefits.map((benefit) => Padding(
                      padding: const EdgeInsets.only(
                          bottom: AppDimensions.spacingSmall),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              benefit,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: AppDimensions.spacingMedium),
                // 订阅按钮
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: isCurrent || _isPaying
                        ? null
                        : () => _startPayment(context, plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isRecommended ? AppColors.brandPink : null,
                      foregroundColor:
                          isRecommended ? Colors.white : null,
                    ),
                    child: _isPaying && !isCurrent
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isCurrent ? '当前套餐' : '立即订阅'),
                  ),
                ),
              ],
            ),
          ),
          // 推荐 badge
          if (isRecommended)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.brandPink, AppColors.brandLavender],
                  ),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(AppDimensions.radiusMedium),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  '推荐',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== 区域 3: 底部说明 ====================

  Widget _buildBottomNotes(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          '订阅将自动续费，到期前24小时自动扣款。如需取消，请在到期前至少24小时关闭自动续费。取消后可正常使用至到期日。',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        GestureDetector(
          onTap: () {
            // TODO: 跳转订阅条款页面
          },
          child: Text(
            '《订阅服务条款》',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
          ),
        ),
      ],
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

  /// 根据 planId 推断套餐名（当没有套餐列表数据时的降级方案）
  String _getPlanNameById(int planId) {
    // 通常 planId 1=FREE, 2=BASIC, 3=PREMIUM, 4=ULTIMATE
    const names = {1: '免费版', 2: '基础版', 3: '高级版', 4: '尊享版'};
    return names[planId] ?? '会员';
  }

  /// 发起支付
  Future<void> _startPayment(
    BuildContext context,
    SubscriptionPlan plan,
  ) async {
    if (_isPaying) return;

    // 确认弹窗
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('订阅 ${plan.planName}'),
        content: Text('月费 ¥${plan.priceMonthly.toInt()}/月'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认支付'),
          ),
        ],
      ),
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
        // 用户取消选择
        return;
      }

      // 目前仅支持支付宝，其他渠道提示暂未开放
      if (paymentChannel != 'alipay') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('该支付方式暂未开放，敬请期待')),
          );
        }
        return;
      }

      // 打开支付宝 WebView
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
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('支付创建失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  /// 轮询支付结果
  Future<void> _pollPaymentResult(
    BuildContext context,
    String orderNo,
  ) async {
    final api = ref.read(apiServiceProvider);

    // 显示加载弹窗
    if (!context.mounted) return;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ));

    // 最多轮询 10 次，每次间隔 2 秒
    var paid = false;
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        final order = await api.getPaymentStatus(orderNo);
        if (order.isPaid) {
          paid = true;
          break;
        }
      } on Exception catch (_) {
        // 查询失败继续重试
      }
    }

    // 关闭加载弹窗
    if (context.mounted) Navigator.of(context).pop();

    // 刷新订阅数据
    await ref.read(subscriptionPlansProvider.notifier).refresh();
    await ref.read(currentSubscriptionProvider.notifier).refresh();

    if (!context.mounted) return;

    if (paid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 支付成功，会员已生效！'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未检测到支付成功，请稍后查看或重试'),
        ),
      );
    }
  }
}
