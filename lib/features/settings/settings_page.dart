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

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _themeMode = LocalStorage.themeMode;
  bool _messageNotify = LocalStorage.messageNotify;
  bool _proactiveCare = LocalStorage.proactiveCare;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 账号与安全
          _buildSectionHeader(context, '账号与安全'),
          _buildMenuItem(
            context,
            title: '修改密码',
            onTap: () {
              // TODO: 修改密码
            },
          ),
          _buildMenuItem(
            context,
            title: '绑定邮箱',
            subtitle: '已绑定: user@example.com',
            onTap: () {
              // TODO: 绑定邮箱
            },
          ),
          _buildMenuItem(
            context,
            title: '注销账号',
            titleColor: Colors.red,
            onTap: () {
              _showDeleteAccountConfirm(context);
            },
          ),
          const Divider(),

          // 模型配置
          _buildSectionHeader(context, '模型配置'),
          _buildMenuItem(
            context,
            title: '当前模型',
            subtitle: LocalStorage.modelName ?? 'GPT-4o',
            onTap: () {
              // TODO: 切换模型
            },
          ),
          _buildMenuItem(
            context,
            title: '本地模型地址',
            subtitle: LocalStorage.modelBaseUrl ?? '未配置',
            onTap: () {
              _showModelUrlDialog(context);
            },
          ),
          const Divider(),

          // 通知设置
          _buildSectionHeader(context, '通知设置'),
          SwitchListTile(
            title: const Text('消息通知'),
            subtitle: const Text('接收新消息通知'),
            value: _messageNotify,
            onChanged: (value) {
              setState(() {
                _messageNotify = value;
              });
              LocalStorage.setMessageNotify(value);
            },
          ),
          SwitchListTile(
            title: const Text('主动关心'),
            subtitle: const Text('AI伴侣会主动发起对话'),
            value: _proactiveCare,
            onChanged: (value) {
              setState(() {
                _proactiveCare = value;
              });
              LocalStorage.setProactiveCare(value);
            },
          ),
          const Divider(),

          // 通用设置
          _buildSectionHeader(context, '通用'),
          ListTile(
            title: const Text('深色模式'),
            subtitle: Text(_getThemeModeLabel(_themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showThemeModeDialog(context);
            },
          ),
          ListTile(
            title: const Text('语言'),
            subtitle: const Text('简体中文'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 切换语言
            },
          ),
          const Divider(),

          // 退出登录
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () {
                _showLogoutConfirm(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: titleColor),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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

  void _showThemeModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('深色模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('跟随系统'),
              value: 'system',
              groupValue: _themeMode,
              onChanged: (value) => _applyThemeMode(value!),
            ),
            RadioListTile<String>(
              title: const Text('浅色模式'),
              value: 'light',
              groupValue: _themeMode,
              onChanged: (value) => _applyThemeMode(value!),
            ),
            RadioListTile<String>(
              title: const Text('深色模式'),
              value: 'dark',
              groupValue: _themeMode,
              onChanged: (value) => _applyThemeMode(value!),
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

  void _showModelUrlDialog(BuildContext context) {
    final controller = TextEditingController(text: LocalStorage.modelBaseUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本地模型地址'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://localhost:1234/v1',
            labelText: '模型地址',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              LocalStorage.setModelBaseUrl(controller.text);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await SecureStorage.clearTokens();
              if (mounted) {
                context.go('/auth');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text('注销账号后，所有数据将被删除且无法恢复。确定要注销吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 注销账号
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('注销'),
          ),
        ],
      ),
    );
  }
}
