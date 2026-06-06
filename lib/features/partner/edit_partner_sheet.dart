import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/models/companion.dart';

/// 编辑伴侣页面（全屏）
class EditPartnerSheet extends ConsumerStatefulWidget {
  final Companion companion;
  final VoidCallback onSaved;

  const EditPartnerSheet({
    super.key,
    required this.companion,
    required this.onSaved,
  });

  /// 显示编辑伴侣页面
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
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  // 关系类型配置（Material Icons）
  static const List<Map<String, dynamic>> _relationships = [
    {'value': 'lover', 'label': '恋人', 'icon': Icons.favorite_rounded},
    {'value': 'friend', 'label': '挚友', 'icon': Icons.handshake_rounded},
    {'value': 'mentor', 'label': '导师', 'icon': Icons.school_rounded},
    {'value': 'confidant', 'label': '树洞', 'icon': Icons.park_rounded},
  ];

  // 性别配置（Material Icons）
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
    _nameController = TextEditingController(text: c.name);
    _descriptionController = TextEditingController(text: c.description ?? '');
    _selectedGender = c.gender;
    _selectedRelationship = c.relationshipType;
    _selectedPersonalities = List.from(c.personalityKeys);
    _selectedSpeakingStyle = c.speakingStyle;
    _currentAvatarUrl = c.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;
  bool get _hasChanges =>
      _nameController.text.trim() != widget.companion.name ||
      _descriptionController.text.trim() != (widget.companion.description ?? '') ||
      _selectedGender != widget.companion.gender ||
      _selectedRelationship != widget.companion.relationshipType ||
      _selectedSpeakingStyle != widget.companion.speakingStyle ||
      _currentAvatarUrl != widget.companion.avatarUrl ||
      !_listEquals(_selectedPersonalities, widget.companion.personalityKeys);

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

      // 用专用接口更新伴侣头像
      await apiService.updateCompanionAvatar(widget.companion.id, result.url);

      setState(() => _currentAvatarUrl = result.url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
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
      await apiService.updateCompanionAvatar(widget.companion.id, null);

      setState(() => _currentAvatarUrl = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像已移除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移除失败: $e')),
        );
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

  // ==================== 保存逻辑 ====================

  Future<void> _save() async {
    if (!_canSave || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final updated = Companion(
        id: widget.companion.id,
        userId: widget.companion.userId,
        name: _nameController.text.trim(),
        gender: _selectedGender,
        relationshipType: _selectedRelationship,
        personalityKeys: _selectedPersonalities,
        speakingStyle: _selectedSpeakingStyle,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        avatarUrl: _currentAvatarUrl,
        themeColor: widget.companion.themeColor,
        status: widget.companion.status,
        companionOrder: widget.companion.companionOrder,
        createTime: widget.companion.createTime,
        updateTime: widget.companion.updateTime,
      );

      await apiService.updateCompanion(widget.companion.id, updated);

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('伴侣信息已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
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

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          // Hero Header
          _buildSliverAppBar(isLight, scheme, personalityColors),
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
                _buildHeroAvatar(avatarUrl, colors, isLight, scheme),
                const SizedBox(height: 16),
                // 伴侣名字
                Text(
                  _nameController.text.isEmpty ? '未命名伴侣' : _nameController.text,
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
  ) {
    return GestureDetector(
      onTap: _isUploadingAvatar ? null : _showAvatarOptions,
      child: Stack(
        children: [
          // 呼吸光晕
          Container(
            width: 140,
            height: 140,
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
          // 头像主体
          Container(
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
                      ref.read(apiClientProvider).getFullUrl(avatarUrl),
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
          // 上传中遮罩
          if (_isUploadingAvatar)
            Container(
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
          // 相机角标
          if (!_isUploadingAvatar)
            Positioned(
              right: 4,
              bottom: 4,
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
        const SizedBox(height: 8),
        Row(
          children: _genders.map((gender) {
            final isSelected = _selectedGender == gender['value'];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: gender != _genders.last ? 8 : 0,
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = gender['value'] as int),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          gender['icon'] as IconData,
                          size: 18,
                          color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          gender['label'] as String,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
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
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: _relationships.map((rel) {
            final isSelected = _selectedRelationship == rel['value'];
            return GestureDetector(
              onTap: () => setState(() => _selectedRelationship = rel['value'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      rel['icon'] as IconData,
                      size: 20,
                      color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rel['label'] as String,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
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
                '保存修改',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
