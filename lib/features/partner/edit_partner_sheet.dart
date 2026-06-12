import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/network/tts_api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../shared/models/companion.dart';
import '../../shared/models/tts_config.dart';
import '../../shared/widgets/soul_toast.dart';

/// 伴侣编辑/创建页面（全屏）
///
/// 编辑模式：传入已有 [companion]
/// 创建模式：不传 [companion]，调用 [EditPartnerSheet.showCreate]
class EditPartnerSheet extends ConsumerStatefulWidget {
  /// 编辑模式时传入的伴侣对象，创建模式为 null
  final Companion? companion;

  /// 保存/创建成功后的回调
  final VoidCallback onSaved;

  const EditPartnerSheet({
    super.key,
    this.companion,
    required this.onSaved,
  });

  /// 编辑模式
  static void show(BuildContext context, Companion companion, VoidCallback onSaved) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPartnerSheet(
          companion: companion,
          onSaved: onSaved,
        ),
      ),
    );
  }

  /// 创建模式
  static void showCreate(BuildContext context, VoidCallback onCreated) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPartnerSheet(
          companion: null,
          onSaved: onCreated,
        ),
      ),
    );
  }

  @override
  ConsumerState<EditPartnerSheet> createState() => _EditPartnerSheetState();
}

class _EditPartnerSheetState extends ConsumerState<EditPartnerSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late int _selectedGender;
  late String _selectedRelationship;
  late List<String> _selectedPersonalities;
  late String _selectedSpeakingStyle;
  late String? _currentAvatarUrl;
  DateTime? _selectedBirthday;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  // TTS 相关状态
  late bool _ttsEnabled;
  late TtsConfig _ttsConfig;
  List<VoiceProfile>? _voiceProfiles;
  bool _isLoadingProfiles = false;
  String? _ttsError;

  /// 是否为创建模式
  bool get _isCreateMode => widget.companion == null;

  // 关系类型配置
  static const List<Map<String, dynamic>> _relationships = [
    {'value': 'lover', 'label': '恋人', 'icon': Icons.favorite_rounded},
    {'value': 'friend', 'label': '挚友', 'icon': Icons.handshake_rounded},
    {'value': 'mentor', 'label': '导师', 'icon': Icons.school_rounded},
    {'value': 'confidant', 'label': '树洞', 'icon': Icons.park_rounded},
  ];

  // 性别配置
  static const List<Map<String, dynamic>> _genders = [
    {'value': 1, 'label': '男', 'icon': Icons.male_rounded},
    {'value': 2, 'label': '女', 'icon': Icons.female_rounded},
    {'value': 3, 'label': '非二元', 'icon': Icons.transgender_rounded},
  ];

  // 性格特征配置
  static const List<Map<String, String>> _personalities = [
    {'value': 'gentle', 'label': '温柔'},
    {'value': 'lively', 'label': '活泼'},
    {'value': 'calm', 'label': '沉稳'},
    {'value': 'humorous', 'label': '幽默'},
    {'value': 'intellectual', 'label': '知性'},
    {'value': 'cool', 'label': '高冷'},
  ];

  // 说话风格配置
  static const List<Map<String, String>> _speakingStyles = [
    {'value': 'casual', 'label': '日常口语'},
    {'value': 'formal', 'label': '正式礼貌'},
    {'value': 'cute', 'label': '软萌可爱'},
    {'value': 'cool', 'label': '简洁冷酷'},
    {'value': 'humorous', 'label': '幽默风趣'},
    {'value': 'poetic', 'label': '文艺诗意'},
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.companion;
    _nameController = TextEditingController(text: c?.name ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    _selectedGender = c?.gender ?? 2; // 默认女
    _selectedRelationship = c?.relationshipType ?? 'lover';
    _selectedPersonalities = c != null ? List.from(c.personalityKeys) : [];
    _selectedSpeakingStyle = c?.speakingStyle ?? 'casual';
    _currentAvatarUrl = c?.avatarUrl;
    _selectedBirthday = c?.birthday;
    _ttsEnabled = c?.ttsConfig?.enabled ?? false;
    _ttsConfig = c?.ttsConfig ?? TtsConfig();

    // 加载声音档案列表
    _loadVoiceProfiles();
  }

  Future<void> _loadVoiceProfiles() async {
    final ttsApi = ref.read(ttsApiProvider);
    if (!ttsApi.isConfigured) return;

    setState(() => _isLoadingProfiles = true);
    try {
      final profiles = await ttsApi.getProfiles();
      if (mounted) {
        setState(() {
          _voiceProfiles = profiles;
          _isLoadingProfiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfiles = false;
          _ttsError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_nameController.text.trim().isEmpty) return false;
    // 创建模式需要至少选一个性格
    if (_isCreateMode && _selectedPersonalities.isEmpty) return false;
    return true;
  }

  bool get _hasChanges {
    if (_isCreateMode) return true;
    final c = widget.companion!;
    final currentTtsEnabled = c.ttsConfig?.enabled ?? false;
    return _nameController.text.trim() != c.name ||
        _descriptionController.text.trim() != (c.description ?? '') ||
        _selectedGender != c.gender ||
        _selectedRelationship != c.relationshipType ||
        _selectedSpeakingStyle != c.speakingStyle ||
        _currentAvatarUrl != c.avatarUrl ||
        _selectedBirthday != c.birthday ||
        _ttsEnabled != currentTtsEnabled ||
        (_ttsEnabled && _ttsConfig.profileId != c.ttsConfig?.profileId) ||
        !_listEquals(_selectedPersonalities, c.personalityKeys);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ==================== 头像上传逻辑 ====================

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final picker = ImagePicker();

    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);

      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.uploadFile(picked.path);

      if (_isCreateMode) {
        // 创建模式：只存本地 URL，创建伴侣时一起提交
        setState(() => _currentAvatarUrl = result.url);
      } else {
        // 编辑模式：用专用接口更新伴侣头像
        await apiService.updateCompanionAvatar(widget.companion!.id, result.url);
        setState(() => _currentAvatarUrl = result.url);
      }

      if (mounted) {
        SoulToast.success(context, '头像已更新');
      }
    } catch (e) {
      if (mounted) {
        SoulToast.error(context, '上传失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    if (_isCreateMode) {
      // 创建模式：直接清除本地 URL
      setState(() => _currentAvatarUrl = null);
      return;
    }

    setState(() => _isUploadingAvatar = true);

    try {
      final apiService = ref.read(apiServiceProvider);

      // 如果有旧头像，尝试删除服务端文件
      if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
        try {
          final uri = Uri.parse(_currentAvatarUrl!);
          final filePath = uri.path.replaceFirst('/files/', '');
          await apiService.deleteFile(filePath);
        } catch (_) {
          // 删除旧文件失败不影响主流程
        }
      }

      // 用专用接口清空伴侣头像
      await apiService.updateCompanionAvatar(widget.companion!.id, null);

      setState(() => _currentAvatarUrl = null);

      if (mounted) {
        SoulToast.info(context, '头像已移除');
      }
    } catch (e) {
      if (mounted) {
        SoulToast.error(context, '移除失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    '移除头像',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeAvatar();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 出生日期选择 ====================

  Future<void> _selectBirthday() async {
    final initialDate = _selectedBirthday ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  surface: Theme.of(context).colorScheme.surface,
                ),
          ),
          child: child!,
        );
      },
    );

    if (mounted && picked != null && picked != _selectedBirthday) {
      setState(() => _selectedBirthday = picked);
    }
  }

  // ==================== 保存逻辑 ====================

  Future<void> _save() async {
    if (!_canSave || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final apiService = ref.read(apiServiceProvider);

      if (_isCreateMode) {
        // 创建模式
        final ttsConfig = _ttsEnabled ? _ttsConfig.copyWith(enabled: true) : null;
        final newCompanion = await apiService.createCompanion(
          CreateCompanionRequest(
            name: _nameController.text.trim(),
            gender: _selectedGender,
            relationshipType: _selectedRelationship,
            personalityKeys: _selectedPersonalities,
            speakingStyle: _selectedSpeakingStyle,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            birthday: _selectedBirthday,
            ttsConfig: ttsConfig,
          ),
        );

        // 如果创建时选了头像，创建成功后需要更新头像
        // （createCompanion 不支持 avatarUrl 参数）
        if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
          try {
            await apiService.updateCompanionAvatar(newCompanion.id, _currentAvatarUrl);
          } catch (_) {
            // 头像更新失败不影响主流程
          }
        }
      } else {
        // 编辑模式
        final c = widget.companion!;
        final ttsConfig = _ttsEnabled ? _ttsConfig.copyWith(enabled: true) : null;
        final updated = Companion(
          id: c.id,
          userId: c.userId,
          name: _nameController.text.trim(),
          gender: _selectedGender,
          relationshipType: _selectedRelationship,
          personalityKeys: _selectedPersonalities,
          speakingStyle: _selectedSpeakingStyle,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          avatarUrl: _currentAvatarUrl,
          themeColor: c.themeColor,
          birthday: _selectedBirthday,
          status: c.status,
          companionOrder: c.companionOrder,
          ttsConfig: ttsConfig,
          createTime: c.createTime,
          updateTime: c.updateTime,
        );

        await apiService.updateCompanion(c.id, updated);
      }

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        SoulToast.success(
          context,
          _isCreateMode ? '伴侣创建成功！' : '伴侣信息已更新',
        );
      }
    } catch (e) {
      if (mounted) {
        SoulToast.error(context, '${_isCreateMode ? '创建' : '保存'}失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ==================== 构建方法 ====================

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final scheme = Theme.of(context).colorScheme;
    final personalityColors = AppColors.personalityColors;
    final apiClient = ref.watch(apiClientProvider);
    final ttsApi = ref.watch(ttsApiProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          // Hero Header
          _buildSliverAppBar(isLight, scheme, personalityColors, apiClient),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // 基础信息卡片
                  _buildSectionCard(
                    context,
                    icon: Icons.person_outline_rounded,
                    title: '基础信息',
                    children: [
                      _buildNameField(scheme),
                      const SizedBox(height: 20),
                      _buildGenderSelector(scheme),
                      const SizedBox(height: 20),
                      _buildBirthdayField(scheme),
                      const SizedBox(height: 20),
                      _buildRelationshipSelector(scheme, personalityColors, isLight),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 个性设定卡片
                  _buildSectionCard(
                    context,
                    icon: Icons.auto_awesome_rounded,
                    title: '个性设定',
                    children: [
                      _buildPersonalityChips(scheme, personalityColors, isLight),
                      const SizedBox(height: 20),
                      _buildSpeakingStyleDropdown(scheme),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 描述卡片
                  _buildSectionCard(
                    context,
                    icon: Icons.edit_note_rounded,
                    title: '描述 / 人设',
                    children: [
                      _buildDescriptionField(scheme),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 声音设置卡片
                  _buildSectionCard(
                    context,
                    icon: Icons.record_voice_over_outlined,
                    title: '声音设置',
                    children: [
                      _buildTtsToggle(scheme, isLight),
                      if (_ttsEnabled) ...[
                        const SizedBox(height: 20),
                        _buildVoiceProfilePicker(scheme, isLight, ttsApi),
                        if (_ttsConfig.profileId != null) ...[
                          const SizedBox(height: 20),
                          _buildTtsLanguageSelector(scheme),
                          if (LocalStorage.ttsProviderType != 'mimo') ...[
                            const SizedBox(height: 20),
                            _buildTtsEngineSelector(scheme),
                          ],
                        ],
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 保存按钮
                  _buildSaveButton(scheme),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Hero Header ====================

  Widget _buildSliverAppBar(
    bool isLight,
    ColorScheme scheme,
    Map<String, PersonalityColors> personalityColors,
    ApiClient apiClient,
  ) {
    final personalityKey = _selectedPersonalities.isNotEmpty
        ? _selectedPersonalities.first
        : 'gentle';
    final colors = personalityColors[personalityKey] ?? personalityColors['gentle']!;
    final avatarUrl = _currentAvatarUrl;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: isLight ? colors.light : colors.dark,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, color: scheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isLight ? colors.light : colors.dark,
                scheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                // 头像区域
                _buildHeroAvatar(avatarUrl, colors, isLight, scheme, apiClient),
                const SizedBox(height: 16),
                // 伴侣名字
                Text(
                  _nameController.text.isEmpty
                      ? (_isCreateMode ? '创建新伴侣' : '未命名伴侣')
                      : _nameController.text,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // 关系类型徽章
                _buildRelationshipBadge(scheme, personalityColors, isLight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroAvatar(
    String? avatarUrl,
    PersonalityColors colors,
    bool isLight,
    ColorScheme scheme,
    ApiClient apiClient,
  ) {
    return GestureDetector(
      onTap: _isUploadingAvatar ? null : _showAvatarOptions,
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 呼吸光晕
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isLight ? colors.light : colors.dark).withOpacity(0.5),
                  boxShadow: [
                    BoxShadow(
                      color: (isLight ? colors.light : colors.dark).withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            // 头像主体（居中于 140x140）
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 3,
                  ),
                  boxShadow: AppShadows.level2(context),
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? Image.network(
                          apiClient.getFullUrl(avatarUrl),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.favorite_rounded,
                            size: 48,
                            color: scheme.primary,
                          ),
                        )
                      : Icon(
                          Icons.favorite_rounded,
                          size: 48,
                          color: scheme.primary,
                        ),
                ),
              ),
            ),
            // 上传中遮罩
            if (_isUploadingAvatar)
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.4),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            // 相机角标（浮在头像右下角，不撑开布局）
            if (!_isUploadingAvatar)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.surface,
                      width: 2.5,
                    ),
                    boxShadow: AppShadows.level1(context),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 18,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipBadge(
    ColorScheme scheme,
    Map<String, PersonalityColors> personalityColors,
    bool isLight,
  ) {
    final rel = _relationships.firstWhere(
      (r) => r['value'] == _selectedRelationship,
      orElse: () => _relationships.first,
    );
    final personalityKey = _selectedPersonalities.isNotEmpty
        ? _selectedPersonalities.first
        : 'gentle';
    final colors = personalityColors[personalityKey] ?? personalityColors['gentle']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: (isLight ? colors.light : colors.dark).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rel['icon'] as IconData,
            size: 14,
            color: scheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            rel['label'] as String,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Section Card ====================

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.level1(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  // ==================== 基础信息 ====================

  Widget _buildNameField(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '伴侣名字',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          maxLength: 12,
          decoration: InputDecoration(
            hintText: '给TA取个名字吧',
            prefixIcon: Icon(Icons.edit_rounded, color: scheme.onSurfaceVariant),
            counterText: '',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildGenderSelector(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '性别',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _genders.map((gender) {
            final isSelected = _selectedGender == gender['value'];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: gender != _genders.last ? 10 : 0,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedGender = gender['value'] as int);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primary.withOpacity(0.08)
                            : scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : scheme.outline.withOpacity(0.12),
                          width: isSelected ? 1.8 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: scheme.primary.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            gender['icon'] as IconData,
                            size: 20,
                            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            gender['label'] as String,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBirthdayField(ColorScheme scheme) {
    final birthdayStr = _selectedBirthday != null
        ? '${_selectedBirthday!.year}年${_selectedBirthday!.month}月${_selectedBirthday!.day}日'
        : '设置出生日期';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '出生日期',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _selectBirthday,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outline.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      birthdayStr,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _selectedBirthday != null
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant.withOpacity(0.6),
                        fontWeight: _selectedBirthday != null ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: scheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelationshipSelector(
    ColorScheme scheme,
    Map<String, PersonalityColors> personalityColors,
    bool isLight,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '关系类型',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: _relationships.map((rel) {
            final isSelected = _selectedRelationship == rel['value'];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedRelationship = rel['value'] as String);
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary.withOpacity(0.08)
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? scheme.primary
                          : scheme.outline.withOpacity(0.12),
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: scheme.primary.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        rel['icon'] as IconData,
                        size: 22,
                        color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        rel['label'] as String,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==================== 个性设定 ====================

  Widget _buildPersonalityChips(
    ColorScheme scheme,
    Map<String, PersonalityColors> personalityColors,
    bool isLight,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '性格特征（最多选3个）',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _personalities.map((p) {
            final isSelected = _selectedPersonalities.contains(p['value']);
            return FilterChip(
              label: Text(p['label']!),
              selected: isSelected,
              onSelected: (selected) {
                HapticFeedback.lightImpact();
                setState(() {
                  if (selected) {
                    if (_selectedPersonalities.length < 3) {
                      _selectedPersonalities.add(p['value']!);
                    }
                  } else {
                    _selectedPersonalities.remove(p['value']);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSpeakingStyleDropdown(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '说话风格',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedSpeakingStyle,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: _speakingStyles.map((style) {
            return DropdownMenuItem(
              value: style['value'],
              child: Text(style['label']!),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedSpeakingStyle = value);
            }
          },
        ),
      ],
    );
  }

  // ==================== 描述 ====================

  Widget _buildDescriptionField(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '描述你的伴侣人设、背景故事...',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: '例如：一位来自古代的温柔诗人，喜欢在月下吟诵...',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  // ==================== 声音设置 ====================

  Widget _buildTtsToggle(ColorScheme scheme, bool isLight) {
    final hasGlobalDefault = LocalStorage.ttsGlobalProfileId != null;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '语音合成',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _ttsEnabled
                    ? 'AI回复将自动生成语音'
                    : (hasGlobalDefault
                        ? '关闭则使用全局默认声音'
                        : '开启后可为伴侣设置专属声音'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _ttsEnabled,
          onChanged: (value) {
            HapticFeedback.lightImpact();
            setState(() {
              _ttsEnabled = value;
              if (!value) {
                _ttsConfig = _ttsConfig.copyWith(enabled: false);
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildVoiceProfilePicker(ColorScheme scheme, bool isLight, dynamic ttsApi) {
    if (!ttsApi.isConfigured) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '请先在设置中配置 TTS 服务器地址',
                style: TextStyle(
                  color: scheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingProfiles) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_voiceProfiles == null || _voiceProfiles!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.voice_over_off_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              _ttsError ?? '暂无可用声音档案',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择声音',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...(_voiceProfiles!.map((profile) {
          final isSelected = _ttsConfig.profileId == profile.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _ttsConfig = _ttsConfig.copyWith(
                    profileId: profile.id,
                    profileName: profile.name,
                    engine: profile.defaultEngine,
                    language: profile.language,
                  );
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary.withOpacity(0.12)
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? scheme.primary
                        : scheme.outline.withOpacity(0.15),
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
                            ? scheme.primary.withOpacity(0.15)
                            : scheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.record_voice_over_outlined,
                        size: 20,
                        color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
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
                              color: isSelected ? scheme.primary : scheme.onSurface,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  profile.voiceTypeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: scheme.primary.withOpacity(0.7),
                                  ),
                                ),
                              ),
                              if (profile.personality != null &&
                                  profile.personality!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    profile.personality!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant.withOpacity(0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: scheme.primary, size: 22),
                  ],
                ),
              ),
            ),
          );
        })),
      ],
    );
  }

  Widget _buildTtsLanguageSelector(ColorScheme scheme) {
    const languages = [
      {'value': 'zh', 'label': '中文'},
      {'value': 'en', 'label': 'English'},
      {'value': 'ja', 'label': '日本語'},
      {'value': 'ko', 'label': '한국어'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '语音语言',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: languages.map((lang) {
            final isSelected = _ttsConfig.language == lang['value'];
            return ChoiceChip(
              label: Text(lang['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _ttsConfig = _ttsConfig.copyWith(language: lang['value']);
                  });
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTtsEngineSelector(ColorScheme scheme) {
    const engines = [
      {'value': 'qwen', 'label': 'Qwen'},
      {'value': 'vits', 'label': 'VITS'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '合成引擎',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: engines.map((eng) {
            final isSelected = (_ttsConfig.engine ?? 'qwen') == eng['value'];
            return ChoiceChip(
              label: Text(eng['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _ttsConfig = _ttsConfig.copyWith(engine: eng['value']);
                  });
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==================== 保存按钮 ====================

  Widget _buildSaveButton(ColorScheme scheme) {
    final isActive = _canSave && _hasChanges && !_isSaving;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isActive ? _save : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? scheme.primary : scheme.surfaceContainerLow,
          foregroundColor: isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : Text(
                _isCreateMode
                    ? '创建伴侣'
                    : (_hasChanges ? '保存修改' : '无修改'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
