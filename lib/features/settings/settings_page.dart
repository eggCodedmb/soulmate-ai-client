import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/providers.dart';
import '../../core/network/api_service.dart';
import '../../core/network/tts_api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';
import '../../shared/models/user.dart';

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
  User? _userInfo;
  bool _isLoadingUser = true;

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
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final api = ref.read(apiServiceProvider);
      final user = await api.getUserInfo();
      if (mounted) {
        setState(() {
          _userInfo = user;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
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
                          subtitle: _isLoadingUser
                              ? '加载中...'
                              : (_userInfo?.email.isNotEmpty == true
                                  ? '已绑定: ${_userInfo!.email}'
                                  : '未绑定邮箱'),
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
                    // LLM 模型配置
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
                          title: '模型服务商',
                          subtitle: _llmProviderSubtitle(),
                          isDark: isDark,
                          onTap: () => _showLlmProviderDialog(context, isDark),
                        ),
                        if (LocalStorage.llmProviderType != 'system') ...[
                          _buildMenuDivider(context, isDark),
                          _buildMenuItem(
                            context,
                            icon: Icons.link_outlined,
                            iconColor: const Color(0xFF00BCD4),
                            title: '服务器地址',
                            subtitle: LocalStorage.llmBaseUrl ?? '未配置',
                            isDark: isDark,
                            onTap: () => _showLlmUrlDialog(context, isDark),
                          ),
                          _buildMenuDivider(context, isDark),
                          _buildMenuItem(
                            context,
                            icon: Icons.vpn_key_outlined,
                            iconColor: const Color(0xFFFF9800),
                            title: 'API Key',
                            subtitle: (LocalStorage.llmApiKey == null || LocalStorage.llmApiKey!.isEmpty)
                                ? '未配置（本地模型可留空）'
                                : '已配置 (已隐藏)',
                            isDark: isDark,
                            onTap: () => _showLlmApiKeyDialog(context, isDark),
                          ),
                          _buildMenuDivider(context, isDark),
                          _buildMenuItem(
                            context,
                            icon: Icons.smart_toy_outlined,
                            iconColor: const Color(0xFF4CAF50),
                            title: '模型名称',
                            subtitle: LocalStorage.llmModel ?? '未配置',
                            isDark: isDark,
                            onTap: () => _showLlmModelDialog(context, isDark),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    // TTS 语音配置
                    _buildSection(
                      context,
                      title: '语音合成 (TTS)',
                      icon: Icons.record_voice_over_outlined,
                      iconColor: const Color(0xFF7C4DFF),
                      isDark: isDark,
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.business_rounded,
                          iconColor: const Color(0xFF9C27B0),
                          title: 'TTS 服务商',
                          subtitle: LocalStorage.ttsProviderType == 'mimo' ? 'Xiaomi MiMo (云端)' : 'Voicebox (本地)',
                          isDark: isDark,
                          onTap: () => _showTtsProviderDialog(context, isDark),
                        ),
                        _buildMenuDivider(context, isDark),
                        _buildMenuItem(
                          context,
                          icon: Icons.dns_outlined,
                          iconColor: const Color(0xFF7C4DFF),
                          title: 'TTS 服务器地址',
                          subtitle: LocalStorage.ttsBaseUrl ?? '未配置',
                          isDark: isDark,
                          onTap: () => _showTtsUrlDialog(context, isDark),
                        ),
                        if (LocalStorage.ttsProviderType == 'mimo') ...[
                          _buildMenuDivider(context, isDark),
                          _buildMenuItem(
                            context,
                            icon: Icons.vpn_key_outlined,
                            iconColor: const Color(0xFFFF9800),
                            title: 'API Key',
                            subtitle: (LocalStorage.ttsApiKey == null || LocalStorage.ttsApiKey!.isEmpty) ? '未配置' : '已配置 (已隐藏)',
                            isDark: isDark,
                            onTap: () => _showTtsApiKeyDialog(context, isDark),
                          ),
                          _buildMenuDivider(context, isDark),
                          _buildMenuItem(
                            context,
                            icon: Icons.smart_toy_outlined,
                            iconColor: const Color(0xFF4CAF50),
                            title: '模型名称',
                            subtitle: LocalStorage.ttsModel,
                            isDark: isDark,
                            onTap: () => _showTtsModelDialog(context, isDark),
                          ),
                        ],
                        _buildMenuDivider(context, isDark),
                        _buildMenuItem(
                          context,
                          icon: Icons.tune_rounded,
                          iconColor: const Color(0xFF00BCD4),
                          title: '默认声音配置',
                          subtitle: _globalTtsSubtitle(),
                          isDark: isDark,
                          onTap: () => _showGlobalTtsConfigDialog(context, isDark),
                        ),
                        _buildMenuDivider(context, isDark),
                        _buildMenuItem(
                          context,
                          icon: Icons.volume_up_outlined,
                          iconColor: const Color(0xFFE91E63),
                          title: '声音档案管理',
                          subtitle: _ttsProfilesCountText(),
                          isDark: isDark,
                          onTap: () => _showTtsProfilesDialog(context, isDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ASR 语音识别
                    _buildSection(
                      context,
                      title: '语音识别 (ASR)',
                      icon: Icons.mic_outlined,
                      iconColor: const Color(0xFF009688),
                      isDark: isDark,
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.settings_input_antenna_outlined,
                          iconColor: const Color(0xFF009688),
                          title: 'ASR 服务商',
                          subtitle: _asrProviderSubtitle(),
                          isDark: isDark,
                          onTap: () => _showAsrProviderDialog(context, isDark),
                        ),
                        if (LocalStorage.asrProviderType != 'system') ...[
                          _buildMenuDivider(context, isDark),
                          _buildMenuItem(
                            context,
                            icon: Icons.dns_outlined,
                            iconColor: const Color(0xFF00BCD4),
                            title: '服务器地址',
                            subtitle: LocalStorage.asrBaseUrl ?? '未配置',
                            isDark: isDark,
                            onTap: () => _showAsrUrlDialog(context, isDark),
                          ),
                          _buildMenuDivider(context, isDark),
                          _buildMenuItem(
                            context,
                            icon: Icons.vpn_key_outlined,
                            iconColor: const Color(0xFFFF9800),
                            title: 'API Key',
                            subtitle: (LocalStorage.asrApiKey == null || LocalStorage.asrApiKey!.isEmpty)
                                ? '未配置'
                                : '已配置 (已隐藏)',
                            isDark: isDark,
                            onTap: () => _showAsrApiKeyDialog(context, isDark),
                          ),
                          _buildMenuDivider(context, isDark),
                          _buildMenuItem(
                            context,
                            icon: Icons.smart_toy_outlined,
                            iconColor: const Color(0xFF4CAF50),
                            title: '模型名称',
                            subtitle: LocalStorage.asrModel,
                            isDark: isDark,
                            onTap: () => _showAsrModelDialog(context, isDark),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 服务器配置
                    _buildSection(
                      context,
                      title: '服务器配置',
                      icon: Icons.dns_outlined,
                      iconColor: const Color(0xFF2196F3),
                      isDark: isDark,
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.computer_rounded,
                          iconColor: const Color(0xFF4CAF50),
                          title: '服务器地址',
                          subtitle: LocalStorage.serverType == 'online'
                              ? '线上服务 (http://39.108.137.45)'
                              : '本地服务 (${LocalStorage.localServerUrl})',
                          isDark: isDark,
                          onTap: () => _showServerConfigDialog(context, isDark),
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

  /// 服务器配置弹窗
  void _showServerConfigDialog(BuildContext context, bool isDark) {
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
                // 线上服务选项
                _buildServerTypeOption(
                  context,
                  title: '线上服务',
                  subtitle: 'http://39.108.137.45',
                  isSelected: selectedType == 'online',
                  isDark: isDark,
                  onTap: () {
                    setSheetState(() {
                      selectedType = 'online';
                    });
                  },
                ),
                const SizedBox(height: 12),
                // 本地服务选项
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
                  _buildModernTextField(
                    controller: controller,
                    isDark: isDark,
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
                              setState(() {});
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

  /// 服务器选项卡片
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

  /// 现代化输入框（统一样式）
  Widget _buildModernTextField({
    required TextEditingController controller,
    required bool isDark,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 15,
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
          fontSize: 14,
        ),
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark ? Colors.white.withOpacity(0.25) : Colors.grey[400],
          fontSize: 14,
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: isDark ? Colors.white.withOpacity(0.4) : Colors.grey[500],
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.grey.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.5),
            width: 1.5,
          ),
        ),
      ),
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
  // ==================== LLM 模型配置 ====================

  String _llmProviderSubtitle() {
    switch (LocalStorage.llmProviderType) {
      case 'openai':
        return 'OpenAI 协议';
      default:
        return '系统默认';
    }
  }

  /// LLM 提供商选择弹窗
  void _showLlmProviderDialog(BuildContext context, bool isDark) {
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
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
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
  }) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await LocalStorage.setLlmProviderType(value);
        Navigator.pop(context);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF9800).withOpacity(isDark ? 0.15 : 0.08)
              : (isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF9800)
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
                    ? const Color(0xFFFF9800).withOpacity(isDark ? 0.2 : 0.1)
                    : (isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(0xFFFF9800)
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
                color: Color(0xFFFF9800),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  /// LLM 服务器地址弹窗
  void _showLlmUrlDialog(BuildContext context, bool isDark) {
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
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.3),
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
                        ? Colors.white.withOpacity(0.5)
                        : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                _buildModernTextField(
                  controller: controller,
                  isDark: isDark,
                  labelText: 'Base URL',
                  hintText: 'https://api.openai.com/v1 或 http://localhost:11434/v1',
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
                                        content: Text(ok ? '模型服务健康 ✓' : '模型服务不可用，请检查地址'),
                                        backgroundColor: ok ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                                      ),
                                    );
                                  }
                                },
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
                          child: isTesting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  '测试健康',
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
                            LocalStorage.setLlmBaseUrl(controller.text.trim());
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
      ),
    );
  }

  /// 测试 LLM 服务器连接
  Future<bool> _testLlmConnection(String baseUrl) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      // 去掉尾部斜杠
      final url = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      // OpenAI 协议健康检查: GET /health
      final response = await dio.get<dynamic>('$url/health');
      // 检查响应状态码
      return response.statusCode == 200;
    } on Object catch (e) {
      debugPrint('[LLM] 测试连接失败: $e');
      return false;
    }
  }

  /// LLM API Key 弹窗
  void _showLlmApiKeyDialog(BuildContext context, bool isDark) {
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
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
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
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _buildModernTextField(
                controller: controller,
                isDark: isDark,
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
                          LocalStorage.setLlmApiKey(controller.text);
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

  /// LLM 模型名称弹窗
  void _showLlmModelDialog(BuildContext context, bool isDark) {
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
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
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
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _buildModernTextField(
                controller: controller,
                isDark: isDark,
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
                          LocalStorage.setLlmModel(controller.text);
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

  // ==================== TTS 语音合成 ====================

  String _ttsProfilesCountText() {
    final url = LocalStorage.ttsBaseUrl;
    if (url == null || url.isEmpty) return '请先配置 TTS 服务器';
    return '点击查看可用声音';
  }

  String _globalTtsSubtitle() {
    final profileName = LocalStorage.ttsGlobalProfileName;
    if (profileName == null || profileName.isEmpty) return '未配置，使用各角色独立设置';
    final lang = LocalStorage.ttsGlobalLanguage;
    final langLabel = lang == 'zh' ? '中文' : lang == 'en' ? 'English' : lang;
    return '$profileName · $langLabel';
  }

  /// 全局 TTS 默认声音配置弹窗
  void _showGlobalTtsConfigDialog(BuildContext context, bool isDark) {
    final ttsApi = ref.read(ttsApiProvider);
    if (!ttsApi.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置 TTS 服务器地址')),
      );
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
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '默认声音配置',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 20, fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '未单独配置声音的角色将使用此默认设置',
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // 声音档案选择
                      Text(
                        '选择声音',
                        style: TextStyle(
                          color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                          fontSize: 14, fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder(
                        future: ttsApi.getProfiles(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          if (snapshot.hasError) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '加载失败: ${snapshot.error}',
                                style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 13),
                              ),
                            );
                          }
                          final profiles = snapshot.data ?? [];
                          if (profiles.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.grey).withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '暂无可用声音档案',
                                style: TextStyle(
                                  color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[500],
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
                                          ? const Color(0xFF7C4DFF).withOpacity(0.12)
                                          : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05)),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF7C4DFF)
                                            : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40, height: 40,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF7C4DFF).withOpacity(0.15)
                                                : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.1)),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.record_voice_over_outlined, size: 20,
                                            color: isSelected ? const Color(0xFF7C4DFF) : (isDark ? Colors.white54 : Colors.grey[600]),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                profile.name,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? const Color(0xFF7C4DFF)
                                                      : (isDark ? Colors.white : Colors.black),
                                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF7C4DFF).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      profile.voiceTypeLabel,
                                                      style: TextStyle(fontSize: 10, color: const Color(0xFF7C4DFF).withOpacity(0.7)),
                                                    ),
                                                  ),
                                                  if (profile.personality != null && profile.personality!.isNotEmpty) ...[
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        profile.personality!,
                                                        style: TextStyle(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check_circle, color: Color(0xFF7C4DFF), size: 22),
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
                          color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                          fontSize: 14, fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: languages.map((lang) {
                          final isSelected = selectedLanguage == lang['value'];
                          return ChoiceChip(
                            label: Text(lang['label']!),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                HapticFeedback.lightImpact();
                                setSheetState(() => selectedLanguage = lang['value']!);
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
                            color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                            fontSize: 14, fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: engines.map((eng) {
                            final isSelected = selectedEngine == eng['value'];
                            return ChoiceChip(
                              label: Text(eng['label']!),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  HapticFeedback.lightImpact();
                                  setSheetState(() => selectedEngine = eng['value']!);
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // 保存按钮
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            LocalStorage.setTtsGlobalProfileId(selectedProfileId);
                            LocalStorage.setTtsGlobalProfileName(selectedProfileName);
                            LocalStorage.setTtsGlobalLanguage(selectedLanguage);
                            LocalStorage.setTtsGlobalEngine(selectedEngine);
                            Navigator.pop(context);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('默认声音配置已保存')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C4DFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('保存配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  /// TTS 服务商选择弹窗
  void _showTtsProviderDialog(BuildContext context, bool isDark) {
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
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
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
            await LocalStorage.setTtsBaseUrl('https://token-plan-sgp.xiaomimimo.com/v1');
          }
        } else if (value == 'voicebox') {
          if (currentUrl == null ||
              currentUrl.isEmpty ||
              currentUrl.contains('xiaomimimo.com')) {
            await LocalStorage.setTtsBaseUrl('http://127.0.0.1:17493');
          }
        }

        Navigator.pop(context);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C4DFF).withOpacity(isDark ? 0.15 : 0.08)
              : (isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7C4DFF)
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
                    ? const Color(0xFF7C4DFF).withOpacity(isDark ? 0.2 : 0.1)
                    : (isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF7C4DFF)
                    : (isDark
                        ? Colors.white.withOpacity(0.6)
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
                              ? Colors.white.withOpacity(0.7)
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
                          ? Colors.white.withOpacity(0.4)
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
  void _showTtsApiKeyDialog(BuildContext context, bool isDark) {
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
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
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
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              _buildModernTextField(
                controller: controller,
                isDark: isDark,
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
                          await LocalStorage.setTtsApiKey(controller.text.trim());
                          Navigator.pop(context);
                          setState(() {});
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
  void _showTtsModelDialog(BuildContext context, bool isDark) {
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
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
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
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              _buildModernTextField(
                controller: controller,
                isDark: isDark,
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
                          final model = controller.text.trim();
                          if (model.isNotEmpty) {
                            await LocalStorage.setTtsModel(model);
                          }
                          Navigator.pop(context);
                          setState(() {});
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
  void _showTtsUrlDialog(BuildContext context, bool isDark) {
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
                  'TTS 服务器地址',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '配置独立的语音合成服务地址',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.5)
                        : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                // 输入框
                _buildModernTextField(
                  controller: controller,
                  isDark: isDark,
                  labelText: 'TTS 服务地址',
                  hintText: LocalStorage.ttsProviderType == 'mimo'
                      ? 'https://token-plan-sgp.xiaomimimo.com/v1'
                      : 'http://localhost:17493',
                  prefixIcon: Icons.dns_outlined,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                // 测试连接结果
                if (testResult != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: testResult!
                          ? Colors.green.withOpacity(isDark ? 0.15 : 0.1)
                          : Colors.red.withOpacity(isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          testResult! ? Icons.check_circle_outline : Icons.error_outline,
                          color: testResult!
                              ? Colors.green.withOpacity(0.8)
                              : Colors.red.withOpacity(0.8),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          testResult! ? '连接成功' : '连接失败，请检查地址',
                          style: TextStyle(
                            color: testResult!
                                ? Colors.green.withOpacity(0.8)
                                : Colors.red.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                // 按钮
                Row(
                  children: [
                    // 测试连接按钮
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
                                // 临时保存以测试连接
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
                                // 恢复旧值，等用户点保存
                                await LocalStorage.setTtsBaseUrl(oldUrl);
                              },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.3),
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
                                      ? Colors.white.withOpacity(0.7)
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
      ),
    );
  }

  /// 声音档案列表弹窗
  void _showTtsProfilesDialog(BuildContext context, bool isDark) {
    final ttsApi = ref.read(ttsApiProvider);

    if (!ttsApi.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置 TTS 服务器地址')),
      );
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
              // 拖拽指示器
              const SizedBox(height: 12),
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
              // 声音列表
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
                              color: Colors.red.withOpacity(0.6),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '加载失败',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withOpacity(0.4)
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
                                ? Colors.white.withOpacity(0.5)
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
                                ? Colors.white.withOpacity(0.06)
                                : Colors.grey.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.brandPink.withOpacity(isDark ? 0.15 : 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
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
                                        color: isDark ? Colors.white : Colors.black,
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
                                            color: const Color(0xFF7C4DFF).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            profile.voiceTypeLabel,
                                            style: TextStyle(
                                              color: const Color(0xFF7C4DFF).withOpacity(0.8),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          profile.language.toUpperCase(),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white.withOpacity(0.4)
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
                                              ? Colors.white.withOpacity(0.5)
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

  // ==================== ASR 语音识别 ====================

  String _asrProviderSubtitle() {
    switch (LocalStorage.asrProviderType) {
      case 'mimo':
        return 'Xiaomi MiMo (云端)';
      case 'custom':
        return '自定义接入 (Whisper API)';
      default:
        return '系统默认';
    }
  }

  /// ASR 提供商选择弹窗
  void _showAsrProviderDialog(BuildContext context, bool isDark) {
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
  }) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await LocalStorage.setAsrProviderType(value);
        Navigator.pop(context);
        setState(() {});
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
  void _showAsrUrlDialog(BuildContext context, bool isDark) {
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
              _buildModernTextField(
                controller: controller,
                isDark: isDark,
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
              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    await LocalStorage.setAsrBaseUrl(controller.text.trim());
                    Navigator.pop(context);
                    setState(() {});
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
  void _showAsrApiKeyDialog(BuildContext context, bool isDark) {
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
                _buildModernTextField(
                  controller: controller,
                  isDark: isDark,
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
                      Navigator.pop(context);
                      setState(() {});
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
  void _showAsrModelDialog(BuildContext context, bool isDark) {
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
              _buildModernTextField(
                controller: controller,
                isDark: isDark,
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
                    Navigator.pop(context);
                    setState(() {});
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
