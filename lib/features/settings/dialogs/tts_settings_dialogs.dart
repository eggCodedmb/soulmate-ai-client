import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/tts_api_client.dart';
import '../widgets/setting_tiles.dart';

/// TTS 服务商选择弹窗
void showTtsProviderDialog(
  BuildContext context, {
  required VoidCallback onSaved,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final currentProvider = LocalStorage.ttsProviderType;

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
            '选择 TTS 服务商',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          _buildProviderOption(
            context,
            icon: Icons.dns_outlined,
            title: 'Voicebox (本地)',
            subtitle: '连接到本地运行的 Voicebox 语音服务器',
            value: 'voicebox',
            isSelected: currentProvider == 'voicebox',
            isDark: isDark,
            onSaved: onSaved,
          ),
          const SizedBox(height: 12),
          _buildProviderOption(
            context,
            icon: Icons.cloud_queue_rounded,
            title: 'Xiaomi MiMo (云端)',
            subtitle: '连接到小米云端 TTS 服务，音质逼真自然',
            value: 'mimo',
            isSelected: currentProvider == 'mimo',
            isDark: isDark,
            onSaved: onSaved,
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

Widget _buildProviderOption(
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
      await LocalStorage.setTtsProviderType(value);

      // 自动适配默认地址
      final currentUrl = LocalStorage.ttsBaseUrl;
      if (value == 'mimo') {
        if (currentUrl == null ||
            currentUrl.isEmpty ||
            currentUrl.contains('127.0.0.1') ||
            currentUrl.contains('localhost')) {
          await LocalStorage.setTtsBaseUrl(
            'https://token-plan-sgp.xiaomimimo.com/v1',
          );
        }
      } else if (value == 'voicebox') {
        if (currentUrl == null ||
            currentUrl.isEmpty ||
            currentUrl.contains('xiaomimimo.com')) {
          await LocalStorage.setTtsBaseUrl('http://127.0.0.1:17493');
        }
      }

      if (context.mounted) {
        Navigator.pop(context);
      }
      onSaved();
    },
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF7C4DFF).withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF7C4DFF)
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
                      0xFF7C4DFF,
                    ).withValues(alpha: isDark ? 0.2 : 0.1)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF7C4DFF)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.grey[600]),
              size: 22,
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
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.grey[700]),
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF7C4DFF),
              size: 22,
            ),
        ],
      ),
    ),
  );
}

/// TTS API Key 弹窗
void showTtsApiKeyDialog(
  BuildContext context, {
  required VoidCallback onSaved,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: LocalStorage.ttsApiKey ?? '');

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
              '配置 API Key',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '用于授权访问云端服务，Key 不会被公开',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SettingTextField(
              controller: controller,
              labelText: 'API Key',
              hintText: '输入您的 API Key',
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
                      onPressed: () async {
                        await LocalStorage.setTtsApiKey(controller.text.trim());
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                        onSaved();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C4DFF),
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

/// TTS 模型名称配置弹窗
void showTtsModelDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: LocalStorage.ttsModel);

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
              '配置模型名称',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '指定用于语音合成的模型名称',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SettingTextField(
              controller: controller,
              labelText: '模型名称',
              hintText: 'mimo-v2.5-tts',
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
                      onPressed: () async {
                        final model = controller.text.trim();
                        if (model.isNotEmpty) {
                          await LocalStorage.setTtsModel(model);
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                        onSaved();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C4DFF),
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

/// TTS 服务器地址弹窗
void showTtsUrlDialog(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback onSaved,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: LocalStorage.ttsBaseUrl ?? '');
  bool isTesting = false;
  bool? testResult;

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
                'TTS 服务器地址',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '配置独立的语音合成 service 地址',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              SettingTextField(
                controller: controller,
                labelText: 'TTS 服务地址',
                hintText: LocalStorage.ttsProviderType == 'mimo'
                    ? 'https://token-plan-sgp.xiaomimimo.com/v1'
                    : 'http://localhost:17493',
                prefixIcon: Icons.dns_outlined,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              if (testResult != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: testResult!
                        ? Colors.green.withValues(alpha: isDark ? 0.15 : 0.1)
                        : Colors.red.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        testResult!
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: testResult!
                            ? Colors.green.withValues(alpha: 0.8)
                            : Colors.red.withValues(alpha: 0.8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        testResult! ? '连接成功' : '连接失败，请检查地址',
                        style: TextStyle(
                          color: testResult!
                              ? Colors.green.withValues(alpha: 0.8)
                              : Colors.red.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  SizedBox(
                    height: 56,
                    child: TextButton(
                      onPressed: isTesting
                          ? null
                          : () async {
                              final url = controller.text.trim();
                              if (url.isEmpty) return;
                              setSheetState(() {
                                isTesting = true;
                                testResult = null;
                              });
                              final oldUrl = LocalStorage.ttsBaseUrl;
                              await LocalStorage.setTtsBaseUrl(url);
                              try {
                                final ttsApi = ref.read(ttsApiProvider);
                                final ok = await ttsApi.testConnection();
                                setSheetState(() {
                                  testResult = ok;
                                  isTesting = false;
                                });
                              } catch (_) {
                                setSheetState(() {
                                  testResult = false;
                                  isTesting = false;
                                });
                              }
                              await LocalStorage.setTtsBaseUrl(oldUrl);
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
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: isTesting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              '测试连接',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : Colors.grey[700],
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          LocalStorage.setTtsBaseUrl(controller.text.trim());
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

/// 全局 TTS 默认声音配置弹窗
void showGlobalTtsConfigDialog(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback onSaved,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final ttsApi = ref.read(ttsApiProvider);
  if (!ttsApi.isConfigured) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请先配置 TTS 服务器地址')));
    return;
  }

  // 当前选中值
  String? selectedProfileId = LocalStorage.ttsGlobalProfileId;
  String? selectedProfileName = LocalStorage.ttsGlobalProfileName;
  String selectedLanguage = LocalStorage.ttsGlobalLanguage;
  String selectedEngine = LocalStorage.ttsGlobalEngine;

  const languages = [
    {'value': 'zh', 'label': '中文'},
    {'value': 'en', 'label': 'English'},
    {'value': 'ja', 'label': '日本語'},
    {'value': 'ko', 'label': '한국어'},
  ];
  const engines = [
    {'value': 'qwen', 'label': 'Qwen'},
    {'value': 'vits', 'label': 'VITS'},
  ];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              Text(
                '默认声音配置',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '未单独配置声音的角色将使用此默认设置',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Text(
                      '选择声音',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.8)
                            : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder(
                      future: ttsApi.getProfiles(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '加载失败: ${snapshot.error}',
                              style: TextStyle(
                                color: Colors.red.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                          );
                        }
                        final profiles = snapshot.data ?? [];
                        if (profiles.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.grey)
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '暂无可用声音档案',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : Colors.grey[500],
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: profiles.map((profile) {
                            final isSelected = selectedProfileId == profile.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setSheetState(() {
                                    selectedProfileId = profile.id;
                                    selectedProfileName = profile.name;
                                    selectedLanguage = profile.language;
                                    selectedEngine = profile.defaultEngine;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(
                                            0xFF7C4DFF,
                                          ).withValues(alpha: 0.12)
                                        : (isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.05,
                                                )
                                              : Colors.grey.withValues(
                                                  alpha: 0.05,
                                                )),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF7C4DFF)
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.grey.withValues(
                                                    alpha: 0.2,
                                                  )),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(
                                                  0xFF7C4DFF,
                                                ).withValues(alpha: 0.15)
                                              : (isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.08,
                                                      )
                                                    : Colors.grey.withValues(
                                                        alpha: 0.1,
                                                      )),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.record_voice_over_outlined,
                                          size: 20,
                                          color: isSelected
                                              ? const Color(0xFF7C4DFF)
                                              : (isDark
                                                    ? Colors.white54
                                                    : Colors.grey[600]),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              profile.name,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? const Color(0xFF7C4DFF)
                                                    : (isDark
                                                          ? Colors.white
                                                          : Colors.black),
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF7C4DFF,
                                                    ).withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    profile.voiceTypeLabel,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: const Color(
                                                        0xFF7C4DFF,
                                                      ).withValues(alpha: 0.7),
                                                    ),
                                                  ),
                                                ),
                                                if (profile.personality !=
                                                        null &&
                                                    profile
                                                        .personality!
                                                        .isNotEmpty) ...[
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      profile.personality!,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            (isDark
                                                                    ? Colors
                                                                          .white
                                                                    : Colors
                                                                          .black)
                                                                .withValues(
                                                                  alpha: 0.4,
                                                                ),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF7C4DFF),
                                          size: 22,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // 语言选择
                    Text(
                      '默认语言',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.8)
                            : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: languages.map((lang) {
                        final isSelected = selectedLanguage == lang['value'];
                        return ChoiceChip(
                          label: Text(lang['label']!),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              HapticFeedback.lightImpact();
                              setSheetState(
                                () => selectedLanguage = lang['value']!,
                              );
                            }
                          },
                        );
                      }).toList(),
                    ),
                    if (LocalStorage.ttsProviderType != 'mimo') ...[
                      const SizedBox(height: 20),
                      // 引擎选择
                      Text(
                        '合成引擎',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: engines.map((eng) {
                          final isSelected = selectedEngine == eng['value'];
                          return ChoiceChip(
                            label: Text(eng['label']!),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                HapticFeedback.lightImpact();
                                setSheetState(
                                  () => selectedEngine = eng['value']!,
                                );
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // 保存按钮
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          LocalStorage.setTtsGlobalProfileId(selectedProfileId);
                          LocalStorage.setTtsGlobalProfileName(
                            selectedProfileName,
                          );
                          LocalStorage.setTtsGlobalLanguage(selectedLanguage);
                          LocalStorage.setTtsGlobalEngine(selectedEngine);
                          Navigator.pop(context);
                          onSaved();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('默认声音配置已保存')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C4DFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '保存配置',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 声音档案列表弹窗
void showTtsProfilesDialog(BuildContext context, WidgetRef ref) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final ttsApi = ref.read(ttsApiProvider);

  if (!ttsApi.isConfigured) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请先配置 TTS 服务器地址')));
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            Text(
              '可用声音档案',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder(
                future: ttsApi.getProfiles(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.withValues(alpha: 0.6),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '加载失败',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.grey[500],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final profiles = snapshot.data ?? [];
                  if (profiles.isEmpty) {
                    return Center(
                      child: Text(
                        '暂无可用声音',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.grey[500],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.brandPink.withValues(
                                  alpha: isDark ? 0.15 : 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.record_voice_over_outlined,
                                color: AppColors.brandPink,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.name,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF7C4DFF,
                                          ).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          profile.voiceTypeLabel,
                                          style: TextStyle(
                                            color: const Color(
                                              0xFF7C4DFF,
                                            ).withValues(alpha: 0.8),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        profile.language.toUpperCase(),
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.4,
                                                )
                                              : Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (profile.personality != null &&
                                      profile.personality!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      profile.personality!,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.5,
                                              )
                                            : Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
