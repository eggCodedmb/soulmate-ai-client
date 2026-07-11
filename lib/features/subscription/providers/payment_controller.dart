import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tobias/tobias.dart' as tobias;
import '../../../core/network/api_service.dart';
import '../../../shared/models/subscription.dart';
import '../widgets/payment_dialogs.dart';
import 'subscription_providers.dart';

/// 支付逻辑控制器 Provider (管理是否正在支付的状态与业务逻辑)
final paymentControllerProvider = AutoDisposeNotifierProvider<PaymentController, bool>(
  PaymentController.new,
);

class PaymentController extends AutoDisposeNotifier<bool> {
  @override
  bool build() {
    return false; // 返回值代表 _isPaying 状态
  }

  /// 发起原生 APP 支付流程
  Future<void> startPayment(BuildContext context, SubscriptionPlan plan) async {
    if (state) return;
    state = true;

    try {
      final api = ref.read(apiServiceProvider);
      final payment = await api.createPayment(plan.id);

      if (!context.mounted) return;

      // 从 payForm 中提取 app_id 以判断是否为沙箱环境 (沙箱 App ID 通常以 9021 开头)
      final appIdRegExp = RegExp(r'app_id=([^&]+)');
      final match = appIdRegExp.firstMatch(payment.payForm);
      final appId = match?.group(1);
      final isSandbox = appId != null && appId.startsWith('9021');
      final payEnv = isSandbox ? tobias.AliPayEvn.sandbox : tobias.AliPayEvn.online;

      debugPrint('====================================');
      debugPrint('[支付宝支付参数日志]');
      debugPrint('payForm: ${payment.payForm}');
      debugPrint('parsedAppId: $appId');
      debugPrint('isSandbox: $isSandbox');
      debugPrint('payEnv: $payEnv');
      debugPrint('====================================');

      // 检测是否安装支付宝客户端
      final tobiasInstance = tobias.Tobias();
      final isInstalled = await tobiasInstance.isAliPayInstalled;
      
      // 如果是沙箱环境，即使没有安装支付宝客户端，SDK 也会自动拉起网页版沙箱支付，因此不需要强行拦截
      if (!isSandbox && !isInstalled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('未检测到支付宝客户端，请先安装'),
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

      // 调用支付宝原生 SDK 支付（payment.payForm 中存储的是订单签名串）
      final result = await tobiasInstance.pay(payment.payForm, evn: payEnv);
      final resultStatus = result['resultStatus']?.toString() ?? '';

      if (context.mounted) {
        if (resultStatus == '9000' || resultStatus == '8000' || resultStatus == '6004') {
          // 支付成功或处理中，启动轮询同步后台状态
          await pollPaymentResult(context, payment.orderNo);
        } else if (resultStatus == '6001') {
          // 用户取消支付，不显示大弹窗，仅提示 SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('支付已取消'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else {
          // 支付失败
          PaymentDialogs.showResult(context, false);
        }
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
      debugPrint('唤起原生支付宝SDK支付异常: $e');
      if (context.mounted) {
        PaymentDialogs.showResult(context, false);
      }
    } finally {
      state = false;
    }
  }

  /// 轮询支付结果，优化后的查询策略：首帧立即查询，后续以较短时间（1.5s起步，最长5s）退避轮询
  Future<void> pollPaymentResult(BuildContext context, String orderNo) async {
    const maxAttempts = 40;
    const initialInterval = Duration(milliseconds: 1500);
    const maxInterval = Duration(seconds: 5);
    const timeout = Duration(minutes: 2);

    final api = ref.read(apiServiceProvider);
    final stopwatch = Stopwatch()..start();
    var isCancelled = false;

    // 显示加载弹窗
    if (!context.mounted) return;
    PaymentDialogs.showLoading(context, onCancel: () {
      isCancelled = true;
    });

    var paid = false;
    var attempts = 0;
    var currentInterval = initialInterval;

    while (attempts < maxAttempts && stopwatch.elapsed < timeout) {
      if (isCancelled) break;

      // 首次不进行等待，立即向服务端发起查询（首帧查询）
      if (attempts > 0) {
        await Future<void>.delayed(currentInterval);
      }

      if (isCancelled) break;
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
      }

      // 退避算法增加等待时间，防止请求过于密集
      if (currentInterval < maxInterval) {
        currentInterval = Duration(
          milliseconds: (currentInterval.inMilliseconds * 1.4).toInt(),
        );
        if (currentInterval > maxInterval) {
          currentInterval = maxInterval;
        }
      }
    }

    stopwatch.stop();

    // 如果未被用户主动取消，则需要手动将加载弹窗关闭
    if (!isCancelled && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    // 刷新相关订阅数据
    await ref.read(subscriptionPlansProvider.notifier).refresh();
    await ref.read(currentSubscriptionProvider.notifier).refresh();
    await ref.read(subscriptionStatusProvider.notifier).refresh();

    if (!context.mounted) return;

    if (paid) {
      PaymentDialogs.showSuccess(context);
    } else if (!isCancelled) {
      PaymentDialogs.showResult(context, false);
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
        return e.message ?? '支付初始化失败，请稍后重试';
    }
  }
}
