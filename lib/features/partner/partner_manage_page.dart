import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/models/companion.dart';
import '../../shared/models/conversation.dart';

/// 伴侣管理页
class PartnerManagePage extends ConsumerStatefulWidget {
  const PartnerManagePage({super.key});

  @override
  ConsumerState<PartnerManagePage> createState() => _PartnerManagePageState();
}

class _PartnerManagePageState extends ConsumerState<PartnerManagePage> {
  List<Companion> _companions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanions();
  }

  Future<void> _loadCompanions() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final companions = await apiService.getCompanionList();
      setState(() {
        _companions = companions;
      });
    } catch (e) {
      debugPrint('加载伴侣列表失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCompanion(int id) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.deleteCompanion(id);
      setState(() {
        _companions.removeWhere((c) => c.id == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('伴侣已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的伴侣'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreatePartner(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _companions.isEmpty
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: _loadCompanions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _companions.length,
                    itemBuilder: (context, index) {
                      return _buildPartnerCard(context, _companions[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_outline_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有伴侣',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 创建你的AI伴侣',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreatePartner(context),
            icon: const Icon(Icons.add),
            label: const Text('创建伴侣'),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCard(BuildContext context, Companion companion) {
    final personalityColors = AppColors.personalityColors;
    final personalityKey = companion.personalityKeys.isNotEmpty
        ? companion.personalityKeys.first
        : 'gentle';
    final colors = personalityColors[personalityKey] ?? personalityColors['gentle']!;

    final isLight = Theme.of(context).brightness == Brightness.light;

    final relationshipLabels = {
      'lover': '恋人',
      'friend': '挚友',
      'mentor': '导师',
      'confidant': '树洞',
    };

    final genderLabels = {1: '男', 2: '女', 3: '非二元'};

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => context.push('/partners/detail/${companion.id}'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.level1(context),
          ),
          child: Row(
            children: [
              // 头像
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      isLight ? colors.light : colors.dark,
                      (isLight ? colors.light : colors.dark).withOpacity(0.5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isLight ? colors.light : colors.dark).withOpacity(0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          companion.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isLight ? colors.light : colors.dark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            relationshipLabels[companion.relationshipType] ??
                                companion.relationshipType,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '性别：${genderLabels[companion.gender] ?? '未知'} | 性格：${companion.personalityKeys.join("、")}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '创建于 ${_formatDate(companion.createTime)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // 箭头指示
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '未知';
    return '${date.year}年${date.month}月${date.day}日';
  }

  void _startChat(Companion companion) async {
    try {
      final apiService = ref.read(apiServiceProvider);

      // 获取或创建对话
      final conversations = await apiService.getConversationList();
      final existingConv = conversations.where(
        (c) => c.companionId == companion.id,
      );

      Conversation conv;
      if (existingConv.isNotEmpty) {
        conv = existingConv.first;
      } else {
        conv = await apiService.createConversation(companion.id);
      }

      if (mounted) {
        context.push('/conversations/chat/${conv.id.toString()}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建对话失败: $e')),
        );
      }
    }
  }

  void _showDeleteConfirm(BuildContext context, Companion companion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除伴侣'),
        content: Text('确定要删除 ${companion.name} 吗？删除后将无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCompanion(companion.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showCreatePartner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _CreatePartnerSheet(
            scrollController: scrollController,
            onCreated: _loadCompanions,
          );
        },
      ),
    );
  }
}

/// 创建伴侣底部弹窗
class _CreatePartnerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onCreated;

  const _CreatePartnerSheet({
    required this.scrollController,
    required this.onCreated,
  });

  @override
  ConsumerState<_CreatePartnerSheet> createState() => _CreatePartnerSheetState();
}

class _CreatePartnerSheetState extends ConsumerState<_CreatePartnerSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _selectedGender = 2; // 默认女
  String _selectedRelationship = 'lover';
  String _selectedSpeakingStyle = 'casual';
  final List<String> _selectedPersonalities = [];
  bool _isCreating = false;

  final List<Map<String, dynamic>> _genders = [
    {'value': 1, 'label': '男', 'icon': Icons.male_rounded},
    {'value': 2, 'label': '女', 'icon': Icons.female_rounded},
    {'value': 3, 'label': '非二元', 'icon': Icons.transgender_rounded},
  ];

  final List<Map<String, dynamic>> _relationships = [
    {'value': 'lover', 'label': '恋人', 'icon': Icons.favorite_rounded},
    {'value': 'friend', 'label': '挚友', 'icon': Icons.handshake_rounded},
    {'value': 'mentor', 'label': '导师', 'icon': Icons.school_rounded},
    {'value': 'confidant', 'label': '树洞', 'icon': Icons.park_rounded},
  ];

  final List<Map<String, String>> _personalities = [
    {'value': 'gentle', 'label': '温柔'},
    {'value': 'lively', 'label': '活泼'},
    {'value': 'calm', 'label': '沉稳'},
    {'value': 'humorous', 'label': '幽默'},
    {'value': 'intellectual', 'label': '知性'},
    {'value': 'cool', 'label': '高冷'},
  ];

  final List<Map<String, String>> _speakingStyles = [
    {'value': 'casual', 'label': '日常口语'},
    {'value': 'formal', 'label': '正式礼貌'},
    {'value': 'cute', 'label': '软萌可爱'},
    {'value': 'cool', 'label': '简洁冷酷'},
    {'value': 'humorous', 'label': '幽默风趣'},
    {'value': 'poetic', 'label': '文艺诗意'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _canCreate() {
    return _nameController.text.isNotEmpty && _selectedPersonalities.isNotEmpty;
  }

  Future<void> _createPartner() async {
    if (!_canCreate() || _isCreating) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.createCompanion(
        CreateCompanionRequest(
          name: _nameController.text,
          gender: _selectedGender,
          relationshipType: _selectedRelationship,
          personalityKeys: _selectedPersonalities,
          speakingStyle: _selectedSpeakingStyle,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        ),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('伴侣创建成功！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: ListView(
        controller: widget.scrollController,
        children: [
          // 标题
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '创建伴侣',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // 形象区域
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primaryContainer,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.favorite_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 基础信息
          Text('基础信息', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          // 名字输入框
          TextFormField(
            controller: _nameController,
            maxLength: 12,
            decoration: const InputDecoration(
              hintText: '给TA取个名字吧',
              labelText: '伴侣名字',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // 性别选择
          Text('性别', style: Theme.of(context).textTheme.titleMedium),
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
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline.withOpacity(0.15),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            gender['icon'] as IconData,
                            size: 18,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            gender['label'] as String,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
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
          const SizedBox(height: 24),

          // 关系类型
          Text('关系类型', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2,
            children: _relationships.map((rel) {
              final isSelected = _selectedRelationship == rel['value'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRelationship = rel['value'] as String;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        rel['icon'] as IconData,
                        size: 20,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rel['label'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 性格特征
          Text('性格特征（最多选3个）', style: Theme.of(context).textTheme.titleMedium),
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
          const SizedBox(height: 24),

          // 说话风格
          Text('说话风格', style: Theme.of(context).textTheme.titleMedium),
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
          const SizedBox(height: 24),

          // 描述/人设
          Text('描述 / 人设', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: '描述你的伴侣人设、背景故事...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 32),

          // 创建按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _canCreate() && !_isCreating ? _createPartner : null,
              child: _isCreating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('创建伴侣'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
