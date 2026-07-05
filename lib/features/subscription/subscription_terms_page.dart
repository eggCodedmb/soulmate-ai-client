import 'package:flutter/material.dart';

/// 订阅服务条款页面
class SubscriptionTermsPage extends StatelessWidget {
  const SubscriptionTermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF5F5F9),
      appBar: AppBar(
        title: const Text('订阅服务条款'),
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              '一、服务内容',
              'SoulMate AI 订阅会员服务（以下简称"本服务"）为用户提供以下增值功能：\n\n'
                  '1. 无限消息额度\n'
                  '2. 多个AI伴侣创建权限\n'
                  '3. 语音消息功能\n'
                  '4. 语音通话功能\n'
                  '5. 高级记忆功能\n'
                  '6. 自定义音色功能\n'
                  '7. 优先响应服务',
              isDark,
            ),
            _buildSection(
              context,
              '二、订阅与付费',
              '1. 订阅周期：本服务按月订阅，订阅周期为自然月。\n'
                  '2. 付费方式：支持支付宝等主流支付方式。\n'
                  '3. 自动续费：订阅将自动续费，到期前24小时自动扣款。\n'
                  '4. 价格说明：具体价格以应用内显示为准，我们保留调整价格的权利。',
              isDark,
            ),
            _buildSection(
              context,
              '三、取消订阅',
              '1. 用户可随时在"设置-订阅管理"中取消自动续费。\n'
                  '2. 取消后，当前订阅周期内的服务不受影响，到期后自动停止。\n'
                  '3. 取消操作需在到期前至少24小时完成，否则将扣取下一周期费用。',
              isDark,
            ),
            _buildSection(
              context,
              '四、退款政策',
              '1. 因本服务为虚拟商品，一般情况下不支持退款。\n'
                  '2. 如因系统故障导致重复扣款，我们将协助处理退款。\n'
                  '3. 退款申请需在扣款后7个工作日内提出。',
              isDark,
            ),
            _buildSection(
              context,
              '五、服务变更与终止',
              '1. 我们保留随时修改或终止本服务的权利。\n'
                  '2. 如服务终止，我们将提前30天通知用户。\n'
                  '3. 因不可抗力导致的服务中断，我们不承担责任。',
              isDark,
            ),
            _buildSection(
              context,
              '六、用户责任',
              '1. 用户应妥善保管账户信息。\n'
                  '2. 用户不得利用本服务进行违法违规活动。\n'
                  '3. 因用户自身原因导致的损失，由用户自行承担。',
              isDark,
            ),
            _buildSection(
              context,
              '七、隐私保护',
              '我们重视用户隐私，具体隐私政策请参阅《隐私政策》。',
              isDark,
            ),
            _buildSection(
              context,
              '八、条款更新',
              '我们可能会不定期更新本条款，更新后的条款将在应用内公布。继续使用本服务即表示同意更新后的条款。',
              isDark,
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                '最后更新日期：2024年1月',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.4)
                      : Colors.black.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.6),
              fontSize: 14,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}
