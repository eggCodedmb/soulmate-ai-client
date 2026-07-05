import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/setting_tiles.dart';

/// LLM 模型提供商选项
const _llmProviders = [
  {
    'value': 'system',
    'title': '系统默认',
    'subtitle': '使用后端内置的 AI 模型（推荐）',
    'icon': Icons.dns_outlined,
  },
  {
    'value': 'openai',
    'title': 'OpenAI 协议',
    'subtitle': '兼容 OpenAI API 的云端或本地模型（如 Ollama、DeepSeek 等）',
    'icon': Icons.cloud_queue_rounded,
  },
];

/// LLM 提供商选择弹窗
void showLlmProviderDialog(
  BuildContext context, {
  required VoidCallback onSaved,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final current = LocalStorage.llmProviderType;

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
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '选择模型服务商',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(_llmProviders.length, (i) {
            final p = _llmProviders[i];
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < _llmProviders.length - 1 ? 12 : 0,
              ),
              child: _buildLlmProviderOption(
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

Widget _buildLlmProviderOption(
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
      await HapticFeedback.lightImpact();
      await LocalStorage.setLlmProviderType(value);
      if (context.mounted) {
        Navigator.pop(context);
      }
      onSaved();
    },
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFFF9800).withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFF9800)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(
                      0xFFFF9800,
                    ).withValues(alpha: isDark ? 0.2 : 0.1)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? const Color(0xFFFF9800)
                  : isDark
                  ? Colors.white.withValues(alpha: 0.6)
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
                        ? Colors.white.withValues(alpha: 0.5)
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
              color: Color(0xFFFF9800),
              size: 24,
            ),
        ],
      ),
    ),
  );
}

/// LLM 服务器地址弹窗
void showLlmUrlDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: LocalStorage.llmBaseUrl ?? '');
  bool isTesting = false;

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
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '服务器地址',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '填写 OpenAI 兼容 API 的 Base URL',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              SettingTextField(
                controller: controller,
                labelText: 'Base URL',
                hintText:
                    'https://api.openai.com/v1 或 http://localhost:11434/v1',
                prefixIcon: Icons.link_rounded,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: TextButton(
                        onPressed: isTesting
                            ? null
                            : () async {
                                final url = controller.text.trim();
                                if (url.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('请先填写服务器地址')),
                                  );
                                  return;
                                }
                                setSheetState(() => isTesting = true);
                                final ok = await _testLlmConnection(url);
                                setSheetState(() => isTesting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok ? '模型服务健康 ✓' : '模型服务不可用，请检查地址',
                                      ),
                                      backgroundColor: ok
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFE53935),
                                    ),
                                  );
                                }
                              },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        child: isTesting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                '测试健康',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : Colors.grey[700],
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          LocalStorage.setLlmBaseUrl(controller.text.trim());
                          Navigator.pop(context);
                          onSaved();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '保存',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 测试 LLM 服务器连接
Future<bool> _testLlmConnection(String baseUrl) async {
  try {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    final url = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final response = await dio.get<dynamic>('$url/health');
    return response.statusCode == 200;
  } on Object catch (e) {
    debugPrint('[LLM] 测试连接失败: $e');
    return false;
  }
}

/// LLM API Key 弹窗
void showLlmApiKeyDialog(
  BuildContext context, {
  required VoidCallback onSaved,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: LocalStorage.llmApiKey ?? '');

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
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'API Key',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '用于鉴权 OpenAI 协议云端模型服务',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SettingTextField(
              controller: controller,
              labelText: 'API Key',
              hintText: 'sk-...',
              prefixIcon: Icons.vpn_key_outlined,
              obscureText: true,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.grey[700],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        LocalStorage.setLlmApiKey(controller.text.trim());
                        Navigator.pop(context);
                        onSaved();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

/// LLM 模型名称弹窗
void showLlmModelDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: LocalStorage.llmModel ?? '');

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
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '模型名称',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '填写模型名称（如 gpt-4o、deepseek-chat、qwen2.5:7b）',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SettingTextField(
              controller: controller,
              labelText: '模型名称',
              hintText: 'gpt-4o / deepseek-chat / qwen2.5:7b',
              prefixIcon: Icons.smart_toy_outlined,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.grey[700],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        LocalStorage.setLlmModel(controller.text.trim());
                        Navigator.pop(context);
                        onSaved();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
