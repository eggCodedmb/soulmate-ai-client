import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../shared/models/subscription.dart';

/// 支付方式
enum PaymentMethod {
  alipay('alipay', '支付宝', Icons.account_balance_wallet_rounded, true),
  wechat('wechat', '微信支付', Icons.chat_bubble_rounded, false),
  unionpay('unionpay', '云闪付', Icons.credit_card_rounded, false);

  const PaymentMethod(this.channel, this.label, this.icon, this.available);

  final String channel;
  final String label;
  final IconData icon;
  final bool available;
}

/// 支付方式选择页面
class PaymentMethodPage extends StatefulWidget {
  /// 套餐信息
  final SubscriptionPlan plan;

  /// 订单号
  final String orderNo;

  const PaymentMethodPage({
    super.key,
    required this.orderNo,
    required this.plan,
  });

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  PaymentMethod _selected = PaymentMethod.alipay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择支付方式'),
      ),
      body: Column(
        children: [
          // 套餐信息摘要
          _buildOrderSummary(context),

          const SizedBox(height: AppDimensions.spacingMedium),

          // 支付方式列表
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMedium,
            ),
            child: Column(
              children: PaymentMethod.values
                  .map((method) => _buildPaymentOption(context, method))
                  .toList(),
            ),
          ),

          const Spacer(),

          // 底部说明
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMedium,
            ),
            child: Text(
              '支付即代表同意《订阅服务条款》',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),

          const SizedBox(height: AppDimensions.spacingMedium),

          // 确认支付按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingMedium,
                0,
                AppDimensions.paddingMedium,
                AppDimensions.paddingMedium,
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppDimensions.buttonHeight,
                child: ElevatedButton(
                  onPressed: _selected.available
                      ? () => Navigator.of(context).pop(_selected.channel)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        colorScheme.surfaceContainerHighest,
                  ),
                  child: Text(
                    _selected.available
                        ? '确认支付 ¥${widget.plan.priceMonthly.toInt()}'
                        : '暂未开放',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 订单摘要
  Widget _buildOrderSummary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppDimensions.paddingMedium),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandPink, AppColors.brandLavender],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plan.planName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '月费 ¥${widget.plan.priceMonthly.toInt()}/月',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Text(
            '¥${widget.plan.priceMonthly.toInt()}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.brandPink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  /// 单个支付方式选项
  Widget _buildPaymentOption(BuildContext context, PaymentMethod method) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selected == method;
    final isAvailable = method.available;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingSmall),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable
              ? () => setState(() => _selected = method)
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${method.label} 暂未开放，敬请期待'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(
                color: isSelected
                    ? AppColors.brandPink
                    : colorScheme.outline.withOpacity(0.2),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // 图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? _getIconBgColor(method).withOpacity(0.1)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                  child: Icon(
                    method.icon,
                    color: isAvailable
                        ? _getIconColor(method)
                        : colorScheme.onSurface.withOpacity(0.3),
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMedium),

                // 名称
                Expanded(
                  child: Text(
                    method.label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isAvailable
                              ? null
                              : colorScheme.onSurface.withOpacity(0.4),
                        ),
                  ),
                ),

                // 状态标签
                if (!isAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusFull),
                    ),
                    child: Text(
                      '即将开放',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),

                const SizedBox(width: AppDimensions.spacingSmall),

                // 选中指示
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected
                      ? AppColors.brandPink
                      : colorScheme.onSurface.withOpacity(0.3),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getIconColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.alipay:
        return const Color(0xFF1677FF);
      case PaymentMethod.wechat:
        return const Color(0xFF07C160);
      case PaymentMethod.unionpay:
        return const Color(0xFFE2231A);
    }
  }

  Color _getIconBgColor(PaymentMethod method) {
    return _getIconColor(method);
  }
}
