import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';

/// 支付宝支付 WebView 页面
///
/// 加载 payForm HTML，自动提交跳转支付宝收银台。
/// 用户完成支付或关闭页面后返回。
class PaymentWebViewPage extends StatefulWidget {
  /// 支付表单 HTML 内容
  final String payForm;

  /// 订单号
  final String orderNo;

  const PaymentWebViewPage({
    super.key,
    required this.payForm,
    required this.orderNo,
  });

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) async {
            final url = request.url;

            // 拦截 alipays:// 协议跳转（唤起支付宝 App）
            if (url.startsWith('alipays://')) {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              return NavigationDecision.prevent;
            }

            // 拦截 wechat:// 协议跳转（唤起微信 App）
            if (url.startsWith('weixin://') || url.startsWith('wechat://')) {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              return NavigationDecision.prevent;
            }

            // 拦截同步跳转地址 (支付宝网页支付付款成功后自动跳转回 returnUrl)
            if (url.contains('/api/payment/return') || url.contains('/api/alipay/return')) {
              Navigator.of(context).pop<PaymentWebViewResult>(PaymentWebViewResult.success);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      );

    // 对 payForm 进行安全过滤，防止 XSS 注入
    final safePayForm = _sanitizeHtml(widget.payForm);

    // 构建包含 payForm 的 HTML 并加载
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>支付</title>
  <style>
    body { margin: 0; padding: 20px; font-family: -apple-system, sans-serif; }
    .loading { text-align: center; padding: 40px; color: #666; }
    .error { text-align: center; padding: 40px; color: #e53935; }
  </style>
</head>
<body>
  <div class="loading">正在跳转支付...</div>
  $safePayForm
  <script>
    // 自动提交表单，延迟确保DOM加载完成
    setTimeout(function() {
      var form = document.querySelector('form');
      if (form) {
        form.submit();
      }
    }, 100);
  </script>
</body>
</html>
''';

    _controller.loadHtmlString(html);
  }

  /// 简单的 HTML 安全过滤，移除危险的 script 标签和事件处理器
  String _sanitizeHtml(String html) {
    if (html.isEmpty) return '';

    var sanitized = html;

    // 移除 <script> 标签及其内容（保留表单提交脚本）
    // 只移除包含危险内容的 script 标签
    final dangerousScriptPattern = RegExp(
      r'<script[^>]*>(?:(?!form\.submit|setTimeout)[\s\S])*?</script>',
      caseSensitive: false,
    );
    sanitized = sanitized.replaceAll(dangerousScriptPattern, '');

    // 移除内联事件处理器 (onclick, onload, onerror 等)
    final eventPattern = RegExp(
      r'''\bon\w+\s*=\s*(?:"[^"]*"|'[^']*')''',
      caseSensitive: false,
    );
    sanitized = sanitized.replaceAll(eventPattern, '');

    return sanitized;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showCancelConfirmDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('支付'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showCancelConfirmDialog,
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: AppColors.brandPink,
                ),
              ),
            if (_errorMessage != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _initWebView();
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCancelConfirmDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('请确认支付状态'),
        content: const Text('如果您已在弹出的支付窗口中付款，请点击“已完成支付”；如果已取消付款，请点击“稍后支付 / 取消”。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop<PaymentWebViewResult>(PaymentWebViewResult.close);
            },
            child: const Text(
              '稍后支付 / 取消',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop<PaymentWebViewResult>(PaymentWebViewResult.success);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPink,
              foregroundColor: Colors.white,
            ),
            child: const Text('已完成支付'),
          ),
        ],
      ),
    );
  }
}

/// 支付宝支付 WebView 页面返回结果
enum PaymentWebViewResult {
  /// 支付成功（拦截到同步回调或用户主动确认）
  success,

  /// 取消/关闭支付（用户放弃支付或关闭页面）
  close,
}
