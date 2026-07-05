import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/storage/local_storage.dart';
import '../widgets/setting_tiles.dart';

/// ASR 提供商选项
const _asrProviders = [
  {
    'value': 'system',
    'title': '系统默认',
    'subtitle': '使用后端内置的语音识别服务',
    'icon': Icons.dns_outlined,
  },
  {
    'value': 'mimo',
    'title': 'Xiaomi MiMo',
    'subtitle': '小米云端 ASR 服务（mimo-v2.5-asr）',
    'icon': Icons.auto_awesome_rounded,
  },
  {
    'value': 'custom',
    'title': '自定义接入',
    'subtitle': '接入第三方 ASR 服务（OpenAI Whisper API 格式）',
    'icon': Icons.cloud_queue_rounded,
  },
];

/// ASR 提供商选择弹窗
void showAsrProviderDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final current = LocalStorage.asrProviderType;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '选择 ASR 服务商',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(_asrProviders.length, (i) {
            final p = _asrProviders[i];
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < _asrProviders.length - 1 ? 12 : 0,
              ),
              child: _buildAsrProviderOption(
                context,
                icon: p['icon'] as IconData,
                title: p['title'] as String,
                subtitle: p['subtitle'] as String,
                value: p['value'] as String,
                isSelected: current == p['value'],
                isDark: isDark,
                onSaved: onSaved,
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

Widget _buildAsrProviderOption(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required String value,
  required bool isSelected,
  required bool isDark,
  required VoidCallback onSaved,
}) {
  return GestureDetector(
    onTap: () async {
      HapticFeedback.lightImpact();
      await LocalStorage.setAsrProviderType(value);
      if (context.mounted) {
        Navigator.pop(context);
      }
      onSaved();
    },
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF009688).withOpacity(isDark ? 0.15 : 0.08)
            : (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF009688)
              : (isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF009688).withOpacity(isDark ? 0.2 : 0.1)
                  : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF009688)
                  : isDark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.5)
                        : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF009688),
              size: 24,
            ),
        ],
      ),
    ),
  );
}

/// ASR 服务器地址弹窗
void showAsrUrlDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: LocalStorage.asrBaseUrl ?? '');

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ASR 服务器地址',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '填写 ASR 服务的 Base URL（不含路径）',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SettingTextField(
              controller: controller,
              labelText: LocalStorage.asrProviderType == 'mimo'
                  ? 'MiMo API 地址'
                  : 'Base URL',
              hintText: LocalStorage.asrProviderType == 'mimo'
                  ? 'https://token-plan-sgp.xiaomimimo.com/v1'
                  : 'https://api.groq.com',
              prefixIcon: Icons.dns_outlined,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  await LocalStorage.setAsrBaseUrl(controller.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  onSaved();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '保存',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

/// ASR API Key 弹窗
void showAsrApiKeyDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: LocalStorage.asrApiKey ?? '');
  bool obscure = true;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'ASR API Key',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '用于鉴权第三方 ASR 服务',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              SettingTextField(
                controller: controller,
                labelText: 'API Key',
                hintText: 'sk-...',
                prefixIcon: Icons.vpn_key_outlined,
                obscureText: obscure,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                    color: isDark
                        ? Colors.white.withOpacity(0.4)
                        : Colors.grey[500],
                    size: 20,
                  ),
                  onPressed: () {
                    setSheetState(() => obscure = !obscure);
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    await LocalStorage.setAsrApiKey(controller.text.trim());
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                    onSaved();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '保存',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

/// ASR 模型名称弹窗
void showAsrModelDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: LocalStorage.asrModel);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ASR 模型名称',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '指定用于语音识别的模型',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SettingTextField(
              controller: controller,
              labelText: '模型名称',
              hintText: LocalStorage.asrProviderType == 'mimo'
                  ? 'mimo-v2.5-asr'
                  : 'whisper-large-v3-turbo',
              prefixIcon: Icons.smart_toy_outlined,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  await LocalStorage.setAsrModel(controller.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  onSaved();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '保存',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
