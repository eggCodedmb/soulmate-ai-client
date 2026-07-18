import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/network/api_service.dart';
import '../../core/storage/local_storage.dart';
import '../../shared/models/user.dart';
import 'widgets/setting_tiles.dart';
import 'dialogs/llm_settings_dialogs.dart';
import 'dialogs/tts_settings_dialogs.dart';
import 'dialogs/asr_settings_dialogs.dart';
import 'dialogs/general_settings_dialogs.dart';
import 'model_download_page.dart';

/// 设置页
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with SingleTickerProviderStateMixin {
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

  String _llmProviderSubtitle() {
    switch (LocalStorage.llmProviderType) {
      case 'openai':
        return 'OpenAI 协议';
      default:
        return '系统默认';
    }
  }

  String _globalTtsSubtitle() {
    final profileName = LocalStorage.ttsGlobalProfileName;
    if (profileName == null || profileName.isEmpty) return '未配置，使用各角色独立设置';
    final lang = LocalStorage.ttsGlobalLanguage;
    final langLabel = lang == 'zh'
        ? '中文'
        : lang == 'en'
        ? 'English'
        : lang;
    return '$profileName · $langLabel';
  }

  String _ttsProfilesCountText() {
    final url = LocalStorage.ttsBaseUrl;
    if (url == null || url.isEmpty) return '请先配置 TTS 服务器';
    return '点击查看可用声音';
  }

  String _asrProviderSubtitle() {
    switch (LocalStorage.asrProviderType) {
      case 'sherpa_onnx':
        return 'Sherpa ONNX (本地离线)';
      case 'mimo':
        return 'Xiaomi MiMo (云端)';
      case 'custom':
        return '自定义接入 (Whisper API)';
      default:
        return '系统默认';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0F)
          : const Color(0xFFF5F5F9),
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
                    horizontal: 20,
                    vertical: 16,
                  ),
                  children: [
                    // 账号与安全
                    SettingSection(
                      title: '账号与安全',
                      icon: Icons.security_rounded,
                      iconColor: const Color(0xFF4CAF50),
                      children: [
                        SettingMenuItem(
                          icon: Icons.lock_outline_rounded,
                          iconColor: const Color(0xFF2196F3),
                          title: '修改密码',
                          subtitle: '定期修改密码保障账号安全',
                          onTap: () {
                            // TODO: 修改密码
                          },
                        ),
                        const SettingMenuDivider(),
                        SettingMenuItem(
                          icon: Icons.email_outlined,
                          iconColor: const Color(0xFF9C27B0),
                          title: '绑定邮箱',
                          subtitle: _isLoadingUser
                              ? '加载中...'
                              : (_userInfo?.email.isNotEmpty == true
                                    ? '已绑定: ${_userInfo!.email}'
                                    : '未绑定邮箱'),
                          onTap: () {
                            // TODO: 绑定邮箱
                          },
                        ),
                        const SettingMenuDivider(),
                        SettingMenuItem(
                          icon: Icons.delete_forever_outlined,
                          iconColor: Colors.red,
                          title: '注销账号',
                          subtitle: '删除账号及所有数据',
                          titleColor: Colors.red,
                          onTap: () => showDeleteAccountConfirmDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // LLM 模型配置
                    StatefulBuilder(
                      builder: (context, setStateSection) {
                        return SettingSection(
                          title: '模型配置',
                          icon: Icons.smart_toy_outlined,
                          iconColor: const Color(0xFFFF9800),
                          children: [
                            SettingMenuItem(
                              icon: Icons.psychology_outlined,
                              iconColor: const Color(0xFFE91E63),
                              title: '模型服务商',
                              subtitle: _llmProviderSubtitle(),
                              onTap: () => showLlmProviderDialog(
                                context,
                                onSaved: () => setStateSection(() {}),
                              ),
                            ),
                            if (LocalStorage.llmProviderType != 'system') ...[
                              const SettingMenuDivider(),
                              SettingMenuItem(
                                icon: Icons.link_outlined,
                                iconColor: const Color(0xFF00BCD4),
                                title: '服务器地址',
                                subtitle: LocalStorage.llmBaseUrl ?? '未配置',
                                onTap: () => showLlmUrlDialog(
                                  context,
                                  onSaved: () => setStateSection(() {}),
                                ),
                              ),
                              const SettingMenuDivider(),
                              SettingMenuItem(
                                icon: Icons.vpn_key_outlined,
                                iconColor: const Color(0xFFFF9800),
                                title: 'API Key',
                                subtitle:
                                    (LocalStorage.llmApiKey == null ||
                                        LocalStorage.llmApiKey!.isEmpty)
                                    ? '未配置（本地模型可留空）'
                                    : '已配置 (已隐藏)',
                                onTap: () => showLlmApiKeyDialog(
                                  context,
                                  onSaved: () => setStateSection(() {}),
                                ),
                              ),
                              const SettingMenuDivider(),
                              SettingMenuItem(
                                icon: Icons.smart_toy_outlined,
                                iconColor: const Color(0xFF4CAF50),
                                title: '模型名称',
                                subtitle: LocalStorage.llmModel ?? '未配置',
                                onTap: () => showLlmModelDialog(
                                  context,
                                  onSaved: () => setStateSection(() {}),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // TTS 语音配置
                    StatefulBuilder(
                      builder: (context, setStateSection) {
                        return SettingSection(
                          title: '语音合成 (TTS)',
                          icon: Icons.record_voice_over_outlined,
                          iconColor: const Color(0xFF7C4DFF),
                          children: [
                            SettingMenuItem(
                              icon: Icons.business_rounded,
                              iconColor: const Color(0xFF9C27B0),
                              title: 'TTS 服务商',
                              subtitle: LocalStorage.ttsProviderType == 'mimo'
                                  ? 'Xiaomi MiMo (云端)'
                                  : 'Voicebox (本地)',
                              onTap: () => showTtsProviderDialog(
                                context,
                                onSaved: () => setStateSection(() {}),
                              ),
                            ),
                            const SettingMenuDivider(),
                            SettingMenuItem(
                              icon: Icons.dns_outlined,
                              iconColor: const Color(0xFF7C4DFF),
                              title: 'TTS 服务器地址',
                              subtitle: LocalStorage.ttsBaseUrl ?? '未配置',
                              onTap: () => showTtsUrlDialog(
                                context,
                                ref,
                                onSaved: () => setStateSection(() {}),
                              ),
                            ),
                            if (LocalStorage.ttsProviderType == 'mimo') ...[
                              const SettingMenuDivider(),
                              SettingMenuItem(
                                icon: Icons.vpn_key_outlined,
                                iconColor: const Color(0xFFFF9800),
                                title: 'API Key',
                                subtitle:
                                    (LocalStorage.ttsApiKey == null ||
                                        LocalStorage.ttsApiKey!.isEmpty)
                                    ? '未配置'
                                    : '已配置 (已隐藏)',
                                onTap: () => showTtsApiKeyDialog(
                                  context,
                                  onSaved: () => setStateSection(() {}),
                                ),
                              ),
                              const SettingMenuDivider(),
                              SettingMenuItem(
                                icon: Icons.smart_toy_outlined,
                                iconColor: const Color(0xFF4CAF50),
                                title: '模型名称',
                                subtitle: LocalStorage.ttsModel,
                                onTap: () => showTtsModelDialog(
                                  context,
                                  onSaved: () => setStateSection(() {}),
                                ),
                              ),
                            ],
                            const SettingMenuDivider(),
                            SettingMenuItem(
                              icon: Icons.tune_rounded,
                              iconColor: const Color(0xFF00BCD4),
                              title: '默认声音配置',
                              subtitle: _globalTtsSubtitle(),
                              onTap: () => showGlobalTtsConfigDialog(
                                context,
                                ref,
                                onSaved: () => setStateSection(() {}),
                              ),
                            ),
                            const SettingMenuDivider(),
                            SettingMenuItem(
                              icon: Icons.volume_up_outlined,
                              iconColor: const Color(0xFFE91E63),
                              title: '声音档案管理',
                              subtitle: _ttsProfilesCountText(),
                              onTap: () => showTtsProfilesDialog(context, ref),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // ASR 语音识别
                    StatefulBuilder(
                      builder: (context, setStateSection) {
                        return SettingSection(
                          title: '语音识别 (ASR)',
                          icon: Icons.mic_outlined,
                          iconColor: const Color(0xFF009688),
                          children: [
                            SettingMenuItem(
                              icon: Icons.settings_input_antenna_outlined,
                              iconColor: const Color(0xFF009688),
                              title: 'ASR 服务商',
                              subtitle: _asrProviderSubtitle(),
                              onTap: () => showAsrProviderDialog(
                                context,
                                onSaved: () => setStateSection(() {}),
                              ),
                            ),
                            const SettingMenuDivider(),
                            SettingMenuItem(
                              icon: Icons.tune_rounded,
                              iconColor: const Color(0xFF00BCD4),
                              title: 'VAD 语音检测调优',
                              subtitle: '微调静音判定、检测阈值与噪声过滤',
                              onTap: () => showVadSettingsDialog(
                                context,
                                onSaved: () => setStateSection(() {}),
                              ),
                            ),
                            const SettingMenuDivider(),
                            SettingMenuItem(
                              icon: Icons.download_for_offline_rounded,
                              iconColor: const Color(0xFFFF9800),
                              title: '离线模型管理',
                              subtitle: '下载或部署本地 VAD、ASR 离线大模型',
                              onTap: () => Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) => const ModelDownloadPage(),
                                ),
                              ),
                            ),
                            if (LocalStorage.asrProviderType != 'system' && LocalStorage.asrProviderType != 'sherpa_onnx') ...[
                              const SettingMenuDivider(),
                              SettingMenuItem(
                                icon: Icons.dns_outlined,
                                iconColor: const Color(0xFF00BCD4),
                                title: '服务器地址',
                                subtitle: LocalStorage.asrBaseUrl ?? '未配置',
                                onTap: () => showAsrUrlDialog(
                                  context,
                                  onSaved: () => setStateSection(() {}),
                                ),
                              ),
                              const SettingMenuDivider(),
                              SettingMenuItem(
                                icon: Icons.vpn_key_outlined,
                                iconColor: const Color(0xFFFF9800),
                                title: 'API Key',
                                subtitle:
                                    (LocalStorage.asrApiKey == null ||
                                        LocalStorage.asrApiKey!.isEmpty)
                                    ? '未配置'
                                    : '已配置 (已隐藏)',
                                onTap: () => showAsrApiKeyDialog(
                                  context,
                                  onSaved: () => setStateSection(() {}),
                                ),
                              ),
                              const SettingMenuDivider(),
                              SettingMenuItem(
                                icon: Icons.smart_toy_outlined,
                                iconColor: const Color(0xFF4CAF50),
                                title: '模型名称',
                                subtitle: LocalStorage.asrModel,
                                onTap: () => showAsrModelDialog(
                                  context,
                                  onSaved: () => setStateSection(() {}),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // 服务器配置
                    StatefulBuilder(
                      builder: (context, setStateSection) {
                        return SettingSection(
                          title: '服务器配置',
                          icon: Icons.dns_outlined,
                          iconColor: const Color(0xFF2196F3),
                          children: [
                            SettingMenuItem(
                              icon: Icons.computer_rounded,
                              iconColor: const Color(0xFF4CAF50),
                              title: '服务器地址',
                              subtitle: LocalStorage.serverType == 'online'
                                  ? '线上服务 (https://hupokeji.top)'
                                  : '本地服务 (${LocalStorage.localServerUrl})',
                              onTap: () => showServerConfigDialog(
                                context,
                                onSaved: () => setStateSection(() {}),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // 通知设置
                    SettingSection(
                      title: '通知设置',
                      icon: Icons.notifications_outlined,
                      iconColor: const Color(0xFFFF5722),
                      children: [
                        Consumer(
                          builder: (context, ref, child) {
                            final messageNotify = ref.watch(
                              messageNotifyProvider,
                            );
                            return SettingSwitchItem(
                              icon: Icons.message_outlined,
                              iconColor: const Color(0xFF4CAF50),
                              title: '消息通知',
                              subtitle: '接收新消息通知',
                              value: messageNotify,
                              onChanged: (value) {
                                LocalStorage.setMessageNotify(value);
                                ref.read(messageNotifyProvider.notifier).state =
                                    value;
                              },
                            );
                          },
                        ),
                        const SettingMenuDivider(),
                        Consumer(
                          builder: (context, ref, child) {
                            final proactiveCare = ref.watch(
                              proactiveCareProvider,
                            );
                            return SettingSwitchItem(
                              icon: Icons.favorite_outline_rounded,
                              iconColor: const Color(0xFFE91E63),
                              title: '主动关心',
                              subtitle: 'AI伴侣会主动发起对话',
                              value: proactiveCare,
                              onChanged: (value) {
                                LocalStorage.setProactiveCare(value);
                                ref.read(proactiveCareProvider.notifier).state =
                                    value;
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 通用设置
                    SettingSection(
                      title: '通用',
                      icon: Icons.tune_rounded,
                      iconColor: const Color(0xFF607D8B),
                      children: [
                        Consumer(
                          builder: (context, ref, child) {
                            final themeMode = ref.watch(themeModeProvider);
                            return SettingMenuItem(
                              icon: Icons.dark_mode_outlined,
                              iconColor: const Color(0xFF673AB7),
                              title: '深色模式',
                              subtitle: _getThemeModeLabel(themeMode),
                              onTap: () => showThemeModeDialog(
                                context,
                                ref,
                                onSaved: () {},
                              ),
                            );
                          },
                        ),
                        const SettingMenuDivider(),
                        SettingMenuItem(
                          icon: Icons.language_outlined,
                          iconColor: const Color(0xFF3F51B5),
                          title: '语言',
                          subtitle: '简体中文',
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

  /// 退出登录按钮
  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showLogoutConfirmDialog(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: Colors.red.withValues(alpha: 0.8),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  '退出登录',
                  style: TextStyle(
                    color: Colors.red.withValues(alpha: 0.8),
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
}
