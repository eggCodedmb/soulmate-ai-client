import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/models/user.dart';

/// 编辑个人信息页
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage>
    with SingleTickerProviderStateMixin {
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _nicknameFocus = FocusNode();
  late int _selectedGender;
  late AnimationController _saveAnimController;
  late Animation<double> _saveScale;
  User? _user;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _didChange = false; // 追踪整个编辑过程中是否有任何变更

  static const _genders = [
    {'value': 0, 'label': '未设置', 'icon': Icons.help_outline_rounded},
    {'value': 1, 'label': '男', 'icon': Icons.male_rounded},
    {'value': 2, 'label': '女', 'icon': Icons.female_rounded},
    {'value': 3, 'label': '非二元', 'icon': Icons.transgender_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _saveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _saveScale = Tween(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _saveAnimController, curve: Curves.easeInOut),
    );
    _loadUserInfo();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _birthdayController.dispose();
    _nicknameFocus.dispose();
    _saveAnimController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
    _didChange = true;
  }

  Future<void> _loadUserInfo() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final user = await apiService.getUserInfo();
      if (!mounted) return;
      setState(() {
        _user = user;
        _nicknameController.text = user.nickname;
        _selectedGender = user.gender;
        _birthdayController.text = user.birthday ?? '';
      });
    } catch (e) {
      debugPrint('加载用户信息失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _canSave =>
      _nicknameController.text.trim().isNotEmpty &&
      !_isSaving &&
      _hasChanges;

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);
    _saveAnimController.forward();

    try {
      final apiService = ref.read(apiServiceProvider);
      final updated = User(
        id: _user!.id,
        email: _user!.email,
        nickname: _nicknameController.text.trim(),
        avatarUrl: _user!.avatarUrl,
        gender: _selectedGender,
        birthday: _birthdayController.text.trim().isEmpty
            ? null
            : _birthdayController.text.trim(),
        guestFlag: _user!.guestFlag,
        status: _user!.status,
        lastLoginTime: _user!.lastLoginTime,
        createTime: _user!.createTime,
        updateTime: _user!.updateTime,
      );

      await apiService.updateUserInfo(updated);

      if (mounted) {
        context.pop(_didChange);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('个人信息已更新')),
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
        _saveAnimController.reverse();
      }
    }
  }

  Future<void> _pickBirthday() async {
    final initialDate = _birthdayController.text.isNotEmpty
        ? DateTime.tryParse(_birthdayController.text) ?? DateTime(2000)
        : DateTime(2000);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _birthdayController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
      _markChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Hero Header ──
                _buildSliverAppBar(context, isLight),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      children: [
                        // 昵称徽章
                        _buildNicknameBadge(context),
                        const SizedBox(height: 24),

                        // ── 基本信息卡片 ──
                        _buildSectionCard(
                          context,
                          icon: Icons.person_outline_rounded,
                          title: '基本信息',
                          children: [
                            _buildNicknameField(context),
                            const SizedBox(height: 20),
                            _buildGenderSelector(context),
                            const SizedBox(height: 20),
                            _buildBirthdayField(context),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── 个性签名卡片 ──
                        _buildSectionCard(
                          context,
                          icon: Icons.edit_note_rounded,
                          title: '个性签名',
                          children: [_buildBioField(context)],
                        ),
                        const SizedBox(height: 16),

                        // ── 账号信息卡片 ──
                        _buildSectionCard(
                          context,
                          icon: Icons.shield_outlined,
                          title: '账号信息',
                          children: [
                            _buildInfoTile(
                              context,
                              icon: Icons.email_outlined,
                              label: '邮箱',
                              value: _user?.email ?? '未绑定',
                            ),
                            _buildDivider(context),
                            _buildInfoTile(
                              context,
                              icon: Icons.calendar_today_outlined,
                              label: '注册时间',
                              value: _formatDate(_user?.createTime),
                            ),
                            _buildDivider(context),
                            _buildInfoTile(
                              context,
                              icon: _user?.guestFlag == 1
                                  ? Icons.person_outline
                                  : Icons.verified_user_outlined,
                              label: '账号类型',
                              value: _user?.guestFlag == 1 ? '游客账号' : '正式账号',
                              valueColor: _user?.guestFlag == 1
                                  ? AppColors.brandWarmPeach
                                  : AppColors.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // ── 保存按钮 ──
                        _buildSaveButton(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════════
  //  SliverAppBar + 头像
  // ══════════════════════════════════════════════

  Widget _buildSliverAppBar(BuildContext context, bool isLight) {
    final avatarUrl = _user?.avatarUrl;

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      stretch: true,
      backgroundColor: isLight ? AppColors.brandPink : const Color(0xFF1A0A10),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () {
          if (_hasChanges) {
            _showDiscardDialog(context);
          } else {
            context.pop();
          }
        },
      ),
      actions: [
        if (_hasChanges)
          TextButton(
            onPressed: _canSave ? _save : null,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('保存', style: TextStyle(color: Colors.white)),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLight
                  ? [AppColors.brandPink, AppColors.brandWarmPeach]
                  : [const Color(0xFF1A0A10), const Color(0xFF2D1520)],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 36),
                // 头像
                GestureDetector(
                  onTap: _isUploadingAvatar ? null : _showAvatarOptions,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _isUploadingAvatar
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : avatarUrl != null && avatarUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      getFullUrl(ref, avatarUrl),
                                      fit: BoxFit.cover,
                                      width: 100,
                                      height: 100,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person_rounded,
                                        size: 48,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                      ),
                      if (!_isUploadingAvatar)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: isLight
                                  ? AppColors.brandPink
                                  : AppColors.brandPinkDark,
                            ),
                          ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '更换头像',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  昵称徽章
  // ══════════════════════════════════════════════

  Widget _buildNicknameBadge(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.level1(context),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandPink, AppColors.brandLavender],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.badge_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nicknameController.text.isEmpty
                      ? '未设置昵称'
                      : _nicknameController.text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${_user?.id ?? '--'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.brandPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _user?.guestFlag == 1 ? '游客' : '免费版',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.brandPink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  卡片容器
  // ══════════════════════════════════════════════

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.level1(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  昵称输入
  // ══════════════════════════════════════════════

  Widget _buildNicknameField(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context, '昵称'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nicknameController,
          focusNode: _nicknameFocus,
          maxLength: 12,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: '给自己取个好听的名字',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            suffixIcon: _nicknameController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _nicknameController.clear();
                      _markChanged();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: cs.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.outline.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
          onChanged: (_) {
            _markChanged();
            setState(() {});
          },
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  性别选择器
  // ══════════════════════════════════════════════

  Widget _buildGenderSelector(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context, '性别'),
        const SizedBox(height: 10),
        Row(
          children: _genders.map((g) {
            final isSelected = _selectedGender == g['value'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedGender = g['value'] as int);
                  _markChanged();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                    right: g != _genders.last ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary.withOpacity(0.12)
                        : cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? cs.primary.withOpacity(0.5)
                          : cs.outline.withOpacity(0.1),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        g['icon'] as IconData,
                        size: 26,
                        color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        g['label'] as String,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isSelected
                              ? cs.primary
                              : cs.onSurfaceVariant,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
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

  // ══════════════════════════════════════════════
  //  生日选择
  // ══════════════════════════════════════════════

  Widget _buildBirthdayField(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasValue = _birthdayController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context, '生日'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickBirthday,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cake_outlined,
                  size: 22,
                  color: hasValue ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? _formatBirthday(_birthdayController.text) : '选择你的生日',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: hasValue
                          ? cs.onSurface
                          : cs.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                ),
                if (hasValue)
                  GestureDetector(
                    onTap: () {
                      setState(() => _birthdayController.clear());
                      _markChanged();
                    },
                    child: Icon(Icons.clear, size: 18, color: cs.onSurfaceVariant),
                  )
                else
                  Icon(Icons.arrow_forward_ios, size: 14, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  个性签名
  // ══════════════════════════════════════════════

  Widget _buildBioField(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextFormField(
      controller: _bioController,
      maxLines: 3,
      maxLength: 100,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: '写一句话介绍自己吧…',
        hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.5)),
        filled: true,
        fillColor: cs.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        counterStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      onChanged: (_) => _markChanged(),
    );
  }

  // ══════════════════════════════════════════════
  //  账号信息行
  // ══════════════════════════════════════════════

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: valueColor ?? cs.onSurface,
              fontWeight: valueColor != null ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  保存按钮
  // ══════════════════════════════════════════════

  Widget _buildSaveButton(BuildContext context) {
    return ScaleTransition(
      scale: _saveScale,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _canSave ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _hasChanges
                ? AppColors.brandPink
                : Theme.of(context).colorScheme.surfaceContainerLow,
            foregroundColor: _hasChanges
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
            elevation: _hasChanges ? 2 : 0,
            shadowColor: _hasChanges
                ? AppColors.brandPink.withOpacity(0.4)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _hasChanges ? Icons.check_rounded : Icons.edit_off_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hasChanges ? '保存修改' : '暂无修改',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  辅助方法
  // ══════════════════════════════════════════════

  Widget _buildLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '未知';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatBirthday(String raw) {
    if (raw.isEmpty) return '';
    try {
      final parts = raw.split('-');
      if (parts.length == 3) {
        return '${parts[0]}年${int.parse(parts[1])}月${int.parse(parts[2])}日';
      }
    } catch (_) {}
    return raw;
  }

  bool _isUploadingAvatar = false;

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

      // 用专用接口更新头像
      await apiService.updateAvatar(result.url);

      // 从服务端重新拉取最新数据
      final freshUser = await apiService.getUserInfo();

      setState(() {
        _user = freshUser;
        _hasChanges = false;
        _didChange = true;
      });

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
      final oldUrl = _user?.avatarUrl;
      if (oldUrl != null && oldUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(oldUrl);
          final filePath = uri.path.replaceFirst('/files/', '');
          await apiService.deleteFile(filePath);
        } catch (_) {
          // 删除旧文件失败不影响主流程
        }
      }

      // 用专用接口清空头像（传 null）
      await apiService.updateAvatar(null);

      // 从服务端重新拉取最新数据
      final freshUser = await apiService.getUserInfo();

      setState(() {
        _user = freshUser;
        _hasChanges = false;
        _didChange = true;
      });

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
              if (_user?.avatarUrl != null && _user!.avatarUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('移除头像', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _removeAvatar();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDiscardDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃修改？'),
        content: const Text('你有未保存的修改，确定要离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
  }
}
