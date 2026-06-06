import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/models/memory.dart';

/// 记忆分类配置
class MemoryCategoryConfig {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const MemoryCategoryConfig({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<MemoryCategoryConfig> memoryCategories = [
  MemoryCategoryConfig(
    key: 'preference',
    label: '个人喜好',
    icon: Icons.favorite_rounded,
    color: AppColors.brandPink,
  ),
  MemoryCategoryConfig(
    key: 'personality',
    label: '性格特质',
    icon: Icons.psychology_rounded,
    color: AppColors.brandLavender,
  ),
  MemoryCategoryConfig(
    key: 'experience',
    label: '生活经历',
    icon: Icons.auto_stories_rounded,
    color: AppColors.brandWarmPeach,
  ),
  MemoryCategoryConfig(
    key: 'relationship',
    label: '情感关系',
    icon: Icons.people_rounded,
    color: Color(0xFF34C759),
  ),
  MemoryCategoryConfig(
    key: 'habit',
    label: '习惯偏好',
    icon: Icons.star_rounded,
    color: Color(0xFFFF9500),
  ),
  MemoryCategoryConfig(
    key: 'other',
    label: '其他',
    icon: Icons.lightbulb_rounded,
    color: Color(0xFF5AC8FA),
  ),
];

/// 根据分类 key 获取配置
MemoryCategoryConfig getCategoryConfig(String category) {
  return memoryCategories.firstWhere(
    (c) => c.key == category,
    orElse: () => memoryCategories.last,
  );
}

/// 记忆编辑底部弹窗
class MemoryEditSheet extends ConsumerStatefulWidget {
  final Memory memory;
  final ValueChanged<Memory>? onSaved;

  const MemoryEditSheet({
    super.key,
    required this.memory,
    this.onSaved,
  });

  /// 显示编辑弹窗
  static Future<void> show(
    BuildContext context,
    Memory memory, {
    ValueChanged<Memory>? onSaved,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemoryEditSheet(memory: memory, onSaved: onSaved),
    );
  }

  @override
  ConsumerState<MemoryEditSheet> createState() => _MemoryEditSheetState();
}

class _MemoryEditSheetState extends ConsumerState<MemoryEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _selectedCategory;
  late int _importance;
  late bool _userVisible;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memory.title);
    _contentController = TextEditingController(text: widget.memory.content);
    _selectedCategory = widget.memory.category;
    _importance = widget.memory.importance;
    _userVisible = widget.memory.userVisible == 1;

    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  void _onChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题和内容不能为空')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedMemory = widget.memory.copyWith(
        title: title,
        content: content,
        category: _selectedCategory,
        importance: _importance,
        userVisible: _userVisible ? 1 : 0,
        userEdited: 1,
      );

      final apiService = ref.read(apiServiceProvider);
      await apiService.updateMemory(widget.memory.id, updatedMemory);

      if (mounted) {
        widget.onSaved?.call(updatedMemory);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记忆已更新')),
        );
      }
    } on Exception catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            boxShadow: AppShadows.level2(context),
          ),
          child: Column(
            children: [
              // 拖拽手柄
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 标题栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.brandPink,
                            AppColors.brandLavender,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '编辑记忆',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '修改记忆的详细信息',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 内容区域
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
                  children: [
                    // 标题输入
                    _buildSectionLabel(context, '标题', Icons.title_rounded),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _titleController,
                      hint: '输入记忆标题',
                      maxLength: 50,
                    ),

                    const SizedBox(height: 24),

                    // 内容输入
                    _buildSectionLabel(context, '内容', Icons.notes_rounded),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _contentController,
                      hint: '输入记忆内容',
                      maxLines: 5,
                      maxLength: 500,
                    ),

                    const SizedBox(height: 24),

                    // 分类选择
                    _buildSectionLabel(context, '分类', Icons.category_rounded),
                    const SizedBox(height: 10),
                    _buildCategorySelector(context),

                    const SizedBox(height: 24),

                    // 重要度
                    _buildSectionLabel(context, '重要度', Icons.priority_high_rounded),
                    const SizedBox(height: 10),
                    _buildImportanceSlider(context),

                    const SizedBox(height: 24),

                    // 可见性
                    _buildVisibilitySwitch(context),

                    const SizedBox(height: 32),

                    // 保存按钮
                    SizedBox(
                      height: AppDimensions.buttonHeight,
                      child: ElevatedButton(
                        onPressed: _isSaving || !_hasChanges ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPink,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              colorScheme.surfaceContainerHighest,
                          disabledForegroundColor:
                              colorScheme.onSurfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _hasChanges
                                        ? Icons.check_rounded
                                        : Icons.edit_off_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _hasChanges ? '保存修改' : '无修改',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brandPink),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.brandPink, width: 1.5),
        ),
        counterStyle: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: memoryCategories.map((cat) {
        final isSelected = _selectedCategory == cat.key;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedCategory = cat.key;
              _hasChanges = true;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? cat.color.withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? cat.color
                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cat.icon,
                  size: 18,
                  color: isSelected ? cat.color : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  cat.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? cat.color
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImportanceSlider(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(10, (index) {
              final filled = index < _importance;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 22,
                  color: filled
                      ? _getImportanceColor(_importance)
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _getImportanceColor(_importance),
              inactiveTrackColor: colorScheme.surfaceContainerLow,
              thumbColor: _getImportanceColor(_importance),
              overlayColor: _getImportanceColor(_importance).withValues(alpha: 0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _importance.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (value) {
                setState(() {
                  _importance = value.round();
                  _hasChanges = true;
                });
              },
            ),
          ),
          Text(
            '重要度: $_importance / 10',
            style: theme.textTheme.labelMedium?.copyWith(
              color: _getImportanceColor(_importance),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getImportanceColor(int importance) {
    if (importance >= 8) return const Color(0xFFFF3B30);
    if (importance >= 6) return AppColors.brandPink;
    if (importance >= 4) return const Color(0xFFFF9500);
    return const Color(0xFF8E8E93);
  }

  Widget _buildVisibilitySwitch(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(
              _userVisible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              size: 20,
              color: _userVisible ? AppColors.brandPink : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Text(
              '记忆可见',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(
            _userVisible ? 'AI 可以在对话中使用此记忆' : 'AI 不会使用此记忆',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        value: _userVisible,
        activeThumbColor: AppColors.brandPink,
        onChanged: (value) {
          HapticFeedback.lightImpact();
          setState(() {
            _userVisible = value;
            _hasChanges = true;
          });
        },
      ),
    );
  }
}
