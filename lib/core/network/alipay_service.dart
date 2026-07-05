import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 支付宝支付服务
///
/// 优先使用支付宝APP支付，未安装时降级为网页支付
class AlipayService {
  /// 检测是否安装支付宝APP
  Future<bool> isAlipayInstalled() async {
    try {
      final uri = Uri.parse('alipays://platformapi/startapp');
      return await canLaunchUrl(uri);
    } catch (e) {
      debugPrint('检测支付宝安装失败: $e');
      return false;
    }
  }

  /// 通过支付宝APP发起支付
  ///
  /// [payForm] 支付宝返回的支付表单HTML
  /// 返回 true 表示成功唤起支付宝APP
  Future<bool> launchAlipayApp(String payForm) async {
    try {
      // 从 payForm 中提取支付链接
      // 支付宝的 payForm 通常包含跳转链接
      final url = _extractPayUrl(payForm);
      if (url == null) {
        debugPrint('无法从 payForm 中提取支付链接');
        return false;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('唤起支付宝APP失败: $e');
      return false;
    }
  }

  /// 从 payForm 中提取支付URL
  ///
  /// 支付宝返回的 payForm 通常包含类似以下格式：
  /// - https://mapi.alipay.com/gateway.do?...
  /// - alipays://platformapi/startapp?...
  String? _extractPayUrl(String payForm) {
    if (payForm.isEmpty) return null;

    // 尝试提取 action 属性中的 URL
    final actionPattern = RegExp(r'action="([^"]+)"');
    final actionMatch = actionPattern.firstMatch(payForm);
    if (actionMatch != null) {
      return actionMatch.group(1);
    }

    // 尝试提取 href 属性中的 URL
    final hrefPattern = RegExp(r'href="([^"]+)"');
    final hrefMatch = hrefPattern.firstMatch(payForm);
    if (hrefMatch != null) {
      return hrefMatch.group(1);
    }

    // 尝试提取 alipays:// 协议链接
    final alipaysPattern = RegExp(r'(alipays://[^\s"<]+)');
    final alipaysMatch = alipaysPattern.firstMatch(payForm);
    if (alipaysMatch != null) {
      return alipaysMatch.group(1);
    }

    // 尝试提取 https://mapi.alipay.com 链接
    final mapiPattern = RegExp(r'(https://mapi\.alipay\.com[^\s"<]+)');
    final mapiMatch = mapiPattern.firstMatch(payForm);
    if (mapiMatch != null) {
      return mapiMatch.group(1);
    }

    return null;
  }

  /// 获取推荐的支付方式
  ///
  /// 优先返回 APP支付，否则返回网页支付
  Future<AlipayPayMode> getRecommendedPayMode() async {
    final isInstalled = await isAlipayInstalled();
    if (isInstalled) {
      return AlipayPayMode.app;
    }
    return AlipayPayMode.webview;
  }
}

/// 支付宝支付方式
enum AlipayPayMode {
  /// 通过支付宝APP支付
  app,

  /// 通过网页支付
  webview,
}
