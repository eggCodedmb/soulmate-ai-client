import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/di/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/setting_tiles.dart';

/// 服务器配置弹窗
void showServerConfigDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  var selectedType = LocalStorage.serverType;
  final controller = TextEditingController(text: LocalStorage.localServerUrl);

  showModalBottomSheet<void>(
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
                '服务器配置',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '切换 API 服务端地址（重启应用后生效）',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _buildServerTypeOption(
                context,
                title: '线上服务',
                subtitle: 'https://hupokeji.top',
                isSelected: selectedType == 'online',
                isDark: isDark,
                onTap: () {
                  setSheetState(() {
                    selectedType = 'online';
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildServerTypeOption(
                context,
                title: '本地服务',
                subtitle: selectedType == 'local' ? controller.text : '自定义本地服务器地址',
                isSelected: selectedType == 'local',
                isDark: isDark,
                onTap: () {
                  setSheetState(() {
                    selectedType = 'local';
                  });
                },
              ),
              if (selectedType == 'local') ...[
                const SizedBox(height: 20),
                SettingTextField(
                  controller: controller,
                  labelText: '本地服务器地址',
                  hintText: '例如 http://10.0.2.2:8000',
                  prefixIcon: Icons.lan_outlined,
                  keyboardType: TextInputType.url,
                ),
              ],
              const SizedBox(height: 32),
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
                          if (selectedType == 'local') {
                            final url = controller.text.trim();
                            if (url.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请先填写本地服务器地址')),
                              );
                              return;
                            }
                            await LocalStorage.setLocalServerUrl(url);
                          }
                          await LocalStorage.setServerType(selectedType);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('服务器配置已保存，请重启应用生效'),
                                backgroundColor: AppColors.brandPink,
                              ),
                            );
                            onSaved();
                          }
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
                          '确定',
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

Widget _buildServerTypeOption(
  BuildContext context, {
  required String title,
  required String subtitle,
  required bool isSelected,
  required bool isDark,
  required VoidCallback onTap,
}) {
  final themeColor = AppColors.brandPink;
  return GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? themeColor.withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? themeColor
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
                  ? themeColor.withValues(alpha: isDark ? 0.2 : 0.1)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              title == '线上服务' ? Icons.cloud_queue_rounded : Icons.computer_rounded,
              color: isSelected
                  ? themeColor
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.grey[600]),
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
            Icon(
              Icons.check_circle_rounded,
              color: themeColor,
              size: 24,
            ),
        ],
      ),
    ),
  );
}

/// 深色模式选择弹窗
void showThemeModeDialog(BuildContext context, WidgetRef ref, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final themeMode = ref.watch(themeModeProvider);

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
            '深色模式',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          _buildThemeOption(
            context,
            ref,
            themeMode: themeMode,
            icon: Icons.brightness_auto_rounded,
            title: '跟随系统',
            value: 'system',
            isDark: isDark,
            onSaved: onSaved,
          ),
          const SizedBox(height: 12),
          _buildThemeOption(
            context,
            ref,
            themeMode: themeMode,
            icon: Icons.light_mode_rounded,
            title: '浅色模式',
            value: 'light',
            isDark: isDark,
            onSaved: onSaved,
          ),
          const SizedBox(height: 12),
          _buildThemeOption(
            context,
            ref,
            themeMode: themeMode,
            icon: Icons.dark_mode_rounded,
            title: '深色模式',
            value: 'dark',
            isDark: isDark,
            onSaved: onSaved,
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

Widget _buildThemeOption(
  BuildContext context,
  WidgetRef ref, {
  required String themeMode,
  required IconData icon,
  required String title,
  required String value,
  required bool isDark,
  required VoidCallback onSaved,
}) {
  final isSelected = themeMode == value;

  return GestureDetector(
    onTap: () {
      LocalStorage.setThemeMode(value);
      ref.read(themeModeProvider.notifier).state = value;
      Navigator.pop(context);
      onSaved();
    },
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? AppColors.brandPink.withOpacity(0.15)
                : AppColors.brandPink.withOpacity(0.08))
            : (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.brandPink.withOpacity(isDark ? 0.5 : 0.3)
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
                  ? AppColors.brandPink.withOpacity(isDark ? 0.2 : 0.1)
                  : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? AppColors.brandPink
                  : (isDark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey[600]),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey[700]),
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (isSelected)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.brandPink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
        ],
      ),
    ),
  );
}

/// 退出登录确认弹窗
void showLogoutConfirmDialog(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(isDark ? 0.15 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.logout_rounded,
              color: Colors.red.withOpacity(0.8),
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '退出登录',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '确定要退出登录吗？',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey[600],
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 32),
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
                              ? Colors.white.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.7)
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
                      Navigator.pop(context);
                      await SecureStorage.clearTokens();
                      if (context.mounted) {
                        context.go('/auth');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '退出',
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
  );
}

/// 注销账号确认弹窗
void showDeleteAccountConfirmDialog(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(isDark ? 0.15 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.withOpacity(0.8),
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '注销账号',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '注销账号后，所有数据将被删除且无法恢复。',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey[600],
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '确定要注销吗？',
            style: TextStyle(
              color: Colors.red.withOpacity(0.8),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
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
                              ? Colors.white.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.7)
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
                      Navigator.pop(context);
                      // TODO: 注销账号
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '注销',
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
  );
}
