import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            // 拦截 alipays:// 协议跳转（唤起支付宝 App）
            if (request.url.startsWith('alipays://')) {
              // 尝试跳转支付宝 App
              return NavigationDecision.navigate;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // 构建包含 payForm 的 HTML 并加载
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>支付</title>
  <style>
    body { margin: 0; padding: 20px; font-family: sans-serif; }
    .loading { text-align: center; padding: 40px; color: #666; }
  </style>
</head>
<body>
  <div class="loading">正在跳转支付宝...</div>
  ${widget.payForm}
  <script>
    // 自动提交表单
    var form = document.querySelector('form');
    if (form) {
      form.submit();
    }
  </script>
</body>
</html>
''';

    _controller.loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('支付'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // 关闭支付页面，返回订单号供上层轮询
            Navigator.of(context).pop(widget.orderNo);
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
