import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/models/companion.dart';
import '../../shared/models/conversation.dart';
import '../../shared/widgets/soul_toast.dart';
import 'edit_partner_sheet.dart';

/// 伴侣详情页
class PartnerDetailPage extends ConsumerStatefulWidget {
  final String companionId;

  const PartnerDetailPage({super.key, required this.companionId});

  @override
  ConsumerState<PartnerDetailPage> createState() => _PartnerDetailPageState();
}

class _PartnerDetailPageState extends ConsumerState<PartnerDetailPage> {
  Companion? _companion;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanion();
  }

  Future<void> _loadCompanion() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final companion = await apiService.getCompanion(int.parse(widget.companionId));
      setState(() {
        _companion = companion;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载伴侣详情失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _startChat() async {
    if (_companion == null) return;

    try {
      final apiService = ref.read(apiServiceProvider);
      final conversations = await apiService.getConversationList();
      final existingConv = conversations.where(
        (c) => c.companionId == _companion!.id,
      );

      Conversation conv;
      if (existingConv.isNotEmpty) {
        conv = existingConv.first;
      } else {
        conv = await apiService.createConversation(_companion!.id);
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

  void _editCompanion() {
    if (_companion == null) return;
    EditPartnerSheet.show(context, _companion!, _loadCompanion);
  }

  void _deleteCompanion() {
    if (_companion == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除伴侣'),
        content: Text('确定要删除 ${_companion!.name} 吗？删除后将无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final apiService = ref.read(apiServiceProvider);
                await apiService.deleteCompanion(_companion!.id);
                if (mounted) {
                  SoulToast.success(context, '伴侣已删除');
                  context.pop();
                }
              } catch (e) {
                if (mounted) {
                  SoulToast.error(context, '删除失败: $e');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('伴侣详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_companion == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('伴侣详情')),
        body: const Center(child: Text('伴侣不存在')),
      );
    }

    final companion = _companion!;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final personalityColors = AppColors.personalityColors;
    final personalityKey = companion.personalityKeys.isNotEmpty
        ? companion.personalityKeys.first
        : 'gentle';
    final colors = personalityColors[personalityKey] ?? personalityColors['gentle']!;

    final relationshipLabels = {
      'lover': '恋人',
      'friend': '挚友',
      'mentor': '导师',
      'confidant': '树洞',
    };

    final genderLabels = {1: '男', 2: '女', 3: '非二元'};

    final speakingStyleLabels = {
      'casual': '日常口语',
      'formal': '正式礼貌',
      'cute': '软萌可爱',
      'cool': '简洁冷酷',
      'humorous': '幽默风趣',
      'poetic': '文艺诗意',
    };

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadCompanion,
        child: CustomScrollView(
          slivers: [
            // AppBar + Hero 头像
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editCompanion();
                        break;
                      case 'chat':
                        _startChat();
                        break;
                      case 'delete':
                        _deleteCompanion();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('编辑伴侣'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'chat',
                      child: ListTile(
                        leading: Icon(Icons.chat_outlined),
                        title: Text('开始聊天'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('删除伴侣', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
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
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 呼吸光晕
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isLight ? colors.light : colors.dark)
                                      .withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          // 头像
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  isLight ? colors.light : colors.dark,
                                  (isLight ? colors.light : colors.dark)
                                      .withOpacity(0.5),
                                ],
                              ),
                              boxShadow: AppShadows.level2(context),
                            ),
                            child: companion.avatarUrl != null &&
                                    companion.avatarUrl!.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      ref.read(apiClientProvider).getFullUrl(companion.avatarUrl!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _buildAvatarIcon(),
                                    ),
                                  )
                                : _buildAvatarIcon(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 名字 + 关系类型 badge
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      companion.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isLight ? colors.light : colors.dark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        relationshipLabels[companion.relationshipType] ??
                            companion.relationshipType,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 描述/人设
            if (companion.description != null &&
                companion.description!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildCard(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_stories_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '人设简介',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          companion.description!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 基础信息卡片
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '基础信息',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        context,
                        icon: Icons.person_outline_rounded,
                        label: '性别',
                        value: genderLabels[companion.gender] ?? '未知',
                      ),
                      if (companion.birthday != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          context,
                          icon: Icons.cake_outlined,
                          label: '生日',
                          value: _formatDate(companion.birthday),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        icon: Icons.record_voice_over_outlined,
                        label: '说话风格',
                        value: speakingStyleLabels[companion.speakingStyle] ??
                            companion.speakingStyle,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        icon: Icons.calendar_today_rounded,
                        label: '创建时间',
                        value: _formatDate(companion.createTime),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 性格特征卡片
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.psychology_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '性格特征',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (companion.personalityKeys.isEmpty)
                        Text(
                          '未设置',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: companion.personalityKeys.map((key) {
                            final pColors = personalityColors[key];
                            final pLabels = {
                              'gentle': '温柔',
                              'lively': '活泼',
                              'calm': '沉稳',
                              'humorous': '幽默',
                              'intellectual': '知性',
                              'cool': '高冷',
                            };
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: pColors != null
                                    ? (isLight ? pColors.light : pColors.dark)
                                    : Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                pLabels[key] ?? key,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 快捷操作按钮
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _startChat,
                          icon: const Icon(Icons.chat_rounded),
                          label: const Text('开始聊天'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _editCompanion,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('编辑资料'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 底部安全区（导航栏 + 安全区高度）
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 80,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarIcon() {
    return Center(
      child: Icon(
        Icons.favorite_rounded,
        size: 56,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.level1(context),
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '未知';
    return '${date.year}年${date.month}月${date.day}日';
  }
}
