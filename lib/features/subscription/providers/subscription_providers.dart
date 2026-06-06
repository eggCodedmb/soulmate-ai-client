import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_service.dart';
import '../../../shared/models/subscription.dart';

/// 套餐列表 Provider
final subscriptionPlansProvider =
    AsyncNotifierProvider<SubscriptionPlansNotifier, List<SubscriptionPlan>>(
  SubscriptionPlansNotifier.new,
);

class SubscriptionPlansNotifier extends AsyncNotifier<List<SubscriptionPlan>> {
  @override
  Future<List<SubscriptionPlan>> build() async {
    final api = ref.watch(apiServiceProvider);
    return api.getSubscriptionPlans();
  }

  /// 刷新套餐列表
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

/// 当前订阅 Provider
final currentSubscriptionProvider =
    AsyncNotifierProvider<CurrentSubscriptionNotifier, UserSubscription?>(
  CurrentSubscriptionNotifier.new,
);

class CurrentSubscriptionNotifier extends AsyncNotifier<UserSubscription?> {
  @override
  Future<UserSubscription?> build() async {
    final api = ref.watch(apiServiceProvider);
    try {
      return await api.getCurrentSubscription();
    } on Exception catch (_) {
      // 未订阅时接口可能返回空或异常，返回 null 表示免费用户
      return null;
    }
  }

  /// 刷新当前订阅
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}
