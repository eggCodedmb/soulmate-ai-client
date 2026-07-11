import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// 支付相关的弹窗组件集合
class PaymentDialogs {
  /// 统一的结果提示弹窗 (成功 / 失败)
  static void showResult(BuildContext context, bool success) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
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

  /// 支付成功的炫酷弹窗
  static void showSuccess(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
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

  /// 正在校验状态的加载弹窗 (带取消等待回调)
  static void showLoading(
    BuildContext context, {
    required VoidCallback onCancel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPink),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '正在确认支付结果...',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请稍候，系统正在校验订单状态',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      onCancel();
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text(
                      '取消等待',
                      style: TextStyle(
                        color: AppColors.brandPink,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
