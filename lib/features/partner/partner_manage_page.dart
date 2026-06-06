import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/models/companion.dart';
import '../../shared/models/conversation.dart';
import 'edit_partner_sheet.dart';

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
    EditPartnerSheet.showCreate(context, _loadCompanions);
  }
}


