import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/providers.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';

/// 设置页
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with SingleTickerProviderStateMixin {
  String _themeMode = LocalStorage.themeMode;
  bool _messageNotify = LocalStorage.messageNotify;
  bool _proactiveCare = LocalStorage.proactiveCare;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF5F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            _buildAppBar(context, isDark),
            // 主内容
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  children: [
                    // 账号与安全
                    _buildSection(
                      context,
                      title: '账号与安全',
                      icon: Icons.security_rounded,
                      iconColor: const Color(0xFF4CAF50),
                      isDark: isDark,
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.lock_outline_rounded,
                          iconColor: const Color(0xFF2196F3),
                          title: '修改密码',
                          subtitle: '定期修改密码保障账号安全',
                          isDark: isDark,
                          onTap: () {
                            // TODO: 修改密码
                          },
                        ),
                        _buildMenuDivider(context, isDark),
                        _buildMenuItem(
                          context,
                          icon: Icons.email_outlined,
                          iconColor: const Color(0xFF9C27B0),
                          title: '绑定邮箱',
                          subtitle: '已绑定: user@example.com',
                          isDark: isDark,
                          onTap: () {
                            // TODO: 绑定邮箱
                          },
                        ),
                        _buildMenuDivider(context, isDark),
                        _buildMenuItem(
                          context,
                          icon: Icons.delete_forever_outlined,
                          iconColor: Colors.red,
                          title: '注销账号',
                          subtitle: '删除账号及所有数据',
                          titleColor: Colors.red,
                          isDark: isDark,
                          onTap: () => _showDeleteAccountConfirm(context, isDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 模型配置
                    _buildSection(
                      context,
                      title: '模型配置',
                      icon: Icons.smart_toy_outlined,
                      iconColor: const Color(0xFFFF9800),
                      isDark: isDark,
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.psychology_outlined,
                          iconColor: const Color(0xFFE91E63),
                          title: '当前模型',
                          subtitle: LocalStorage.modelName ?? 'GPT-4o',
                          isDark: isDark,
                          onTap: () {
                            // TODO: 切换模型
                          },
                        ),
                        _buildMenuDivider(context, isDark),
                        _buildMenuItem(
                          context,
                          icon: Icons.link_outlined,
                          iconColor: const Color(0xFF00BCD4),
                          title: '本地模型地址',
                          subtitle: LocalStorage.modelBaseUrl ?? '未配置',
                          isDark: isDark,
                          onTap: () => _showModelUrlDialog(context, isDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 通知设置
                    _buildSection(
                      context,
                      title: '通知设置',
                      icon: Icons.notifications_outlined,
                      iconColor: const Color(0xFFFF5722),
                      isDark: isDark,
                      children: [
                        _buildSwitchItem(
                          context,
                          icon: Icons.message_outlined,
                          iconColor: const Color(0xFF4CAF50),
                          title: '消息通知',
                          subtitle: '接收新消息通知',
                          value: _messageNotify,
                          isDark: isDark,
                          onChanged: (value) {
                            setState(() => _messageNotify = value);
                            LocalStorage.setMessageNotify(value);
                          },
                        ),
                        _buildMenuDivider(context, isDark),
                        _buildSwitchItem(
                          context,
                          icon: Icons.favorite_outline_rounded,
                          iconColor: const Color(0xFFE91E63),
                          title: '主动关心',
                          subtitle: 'AI伴侣会主动发起对话',
                          value: _proactiveCare,
                          isDark: isDark,
                          onChanged: (value) {
                            setState(() => _proactiveCare = value);
                            LocalStorage.setProactiveCare(value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 通用设置
                    _buildSection(
                      context,
                      title: '通用',
                      icon: Icons.tune_rounded,
                      iconColor: const Color(0xFF607D8B),
                      isDark: isDark,
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.dark_mode_outlined,
                          iconColor: const Color(0xFF673AB7),
                          title: '深色模式',
                          subtitle: _getThemeModeLabel(_themeMode),
                          isDark: isDark,
                          onTap: () => _showThemeModeDialog(context, isDark),
                        ),
                        _buildMenuDivider(context, isDark),
                        _buildMenuItem(
                          context,
                          icon: Icons.language_outlined,
                          iconColor: const Color(0xFF3F51B5),
                          title: '语言',
                          subtitle: '简体中文',
                          isDark: isDark,
                          onTap: () {
                            // TODO: 切换语言
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // 退出登录
                    _buildLogoutButton(context, isDark),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部导航栏
  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 22,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Text(
            '设置',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // 占位，保持标题居中
        ],
      ),
    );
  }

  /// 分组卡片
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: Colors.white.withOpacity(0.15), width: 1)
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分组标题
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.9) : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // 菜单项
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 菜单项
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isDark ? 0.12 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ??
                            (isDark ? Colors.white.withOpacity(0.9) : Colors.black),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.5)
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDark
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 开关菜单项
  Widget _buildSwitchItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(isDark ? 0.12 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.9) : Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.5)
                        : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // 自定义开关
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                gradient: value
                    ? const LinearGradient(
                        colors: [AppColors.brandPink, AppColors.brandLavender],
                      )
                    : null,
                color: value
                    ? null
                    : (isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: value
                      ? Colors.transparent
                      : (isDark
                          ? Colors.white.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.4)),
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 菜单分割线
  Widget _buildMenuDivider(BuildContext context, bool isDark) {
    return Divider(
      height: 1,
      indent: 68,
      endIndent: 20,
      color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.2),
    );
  }

  /// 退出登录按钮
  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.red.withOpacity(0.1)
            : Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.withOpacity(isDark ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLogoutConfirm(context, isDark),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: Colors.red.withOpacity(0.8),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  '退出登录',
                  style: TextStyle(
                    color: Colors.red.withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getThemeModeLabel(String mode) {
    switch (mode) {
      case 'system':
        return '跟随系统';
      case 'light':
        return '浅色模式';
      case 'dark':
        return '深色模式';
      default:
        return '跟随系统';
    }
  }

  /// 深色模式选择弹窗
  void _showThemeModeDialog(BuildContext context, bool isDark) {
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
            // 拖拽指示器
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
              icon: Icons.brightness_auto_rounded,
              title: '跟随系统',
              value: 'system',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildThemeOption(
              context,
              icon: Icons.light_mode_rounded,
              title: '浅色模式',
              value: 'light',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildThemeOption(
              context,
              icon: Icons.dark_mode_rounded,
              title: '深色模式',
              value: 'dark',
              isDark: isDark,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
  }) {
    final isSelected = _themeMode == value;

    return GestureDetector(
      onTap: () => _applyThemeMode(value),
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

  void _applyThemeMode(String mode) {
    setState(() => _themeMode = mode);
    LocalStorage.setThemeMode(mode);
    ref.read(themeModeProvider.notifier).state = mode;
    Navigator.pop(context);
  }

  /// 模型地址弹窗
  void _showModelUrlDialog(BuildContext context, bool isDark) {
    final controller = TextEditingController(text: LocalStorage.modelBaseUrl);

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
              // 拖拽指示器
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
                '本地模型地址',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              // 输入框
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'http://localhost:1234/v1',
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.3)
                          : Colors.grey[400],
                    ),
                    labelText: '模型地址',
                    labelStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.6)
                          : Colors.grey[600],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: Icon(
                      Icons.link_rounded,
                      color: isDark
                          ? Colors.white.withOpacity(0.5)
                          : Colors.grey[500],
                    ),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(height: 24),
              // 按钮
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
                          LocalStorage.setModelBaseUrl(controller.text);
                          Navigator.pop(context);
                          setState(() {});
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

  /// 退出登录确认弹窗
  void _showLogoutConfirm(BuildContext context, bool isDark) {
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
            // 拖拽指示器
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
            // 图标
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
            // 按钮
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
                        if (mounted) {
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
  void _showDeleteAccountConfirm(BuildContext context, bool isDark) {
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
            // 拖拽指示器
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
            // 图标
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
            // 按钮
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
}
