import 'package:dio/dio.dart';
import '../../../shared/models/subscription.dart';

/// 支付模块 API
mixin PaymentMixin {
  Dio get dio;
  dynamic unwrap(Response<dynamic> response);

  /// 创建支付订单
  ///
  /// [paymentChannel] 支付渠道: 'alipay'(支付宝) / 'wechat'(微信) / 'unionpay'(云闪付)
  Future<CreatePaymentResponse> createPayment(
    int planId, {
    String paymentChannel = 'alipay',
  }) async {
    final response = await dio.post<dynamic>(
      '/api/alipay/create',
      data: {'planId': planId, 'paymentChannel': paymentChannel},
    );
    return CreatePaymentResponse.fromJson(
      unwrap(response) as Map<String, dynamic>,
    );
  }

  /// 查询支付订单状态
  Future<PaymentOrder> getPaymentStatus(String orderNo) async {
    final response = await dio.get<dynamic>(
      '/api/alipay/status',
      queryParameters: {'orderNo': orderNo},
    );
    return PaymentOrder.fromJson(unwrap(response) as Map<String, dynamic>);
  }
}
