import 'package:dio/dio.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_status.dart';

/// 订阅模块 API
mixin SubscriptionMixin {
  Dio get dio;
  dynamic unwrap(Response<dynamic> response);

  /// 获取套餐列表
  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    final response = await dio.get<dynamic>('/api/subscription/plans');
    final data = unwrap(response) as List<dynamic>;
    return data
        .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取当前订阅
  Future<UserSubscription?> getCurrentSubscription() async {
    final response = await dio.get<dynamic>('/api/subscription/current');
    final data = unwrap(response);
    if (data == null) return null;
    return UserSubscription.fromJson(data as Map<String, dynamic>);
  }

  /// 获取用户当前额度状态
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    final response = await dio.get<dynamic>('/api/subscription/status');
    return SubscriptionStatus.fromJson(unwrap(response) as Map<String, dynamic>);
  }
}
