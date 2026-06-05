import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/providers.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/models/companion.dart';
import '../../shared/models/conversation.dart';

/// 首页 - 伴侣主页
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Companion? _currentCompanion;
  Conversation? _currentConversation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final companions = await apiService.getCompanionList();

      if (companions.isNotEmpty) {
        setState(() {
          _currentCompanion = companions.first;
        });

        // 获取或创建对话
        final conversations = await apiService.getConversationList();
        final existingConv = conversations.where(
          (c) => c.companionId == _currentCompanion!.id,
        );

        if (existingConv.isNotEmpty) {
          setState(() {
            _currentConversation = existingConv.first;
          });
        }
      }
    } catch (e) {
      debugPrint('加载数据失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _startChat() async {
    if (_currentCompanion == null) return;

    try {
      final apiService = ref.read(apiServiceProvider);

      // 如果没有对话，创建一个
      if (_currentConversation == null) {
        final conv = await apiService.createConversation(_currentCompanion!.id);
        setState(() {
          _currentConversation = conv;
        });
      }

      if (mounted) {
        context.push('/conversations/chat/${_currentConversation!.id.toString()}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建对话失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            // 氛围背景
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
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
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push('/profile/settings'),
                ),
              ],
            ),
            // 顶部状态栏
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getTimeGreeting(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '25°C',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // AI伴侣形象区
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: _startChat,
                child: Container(
                  height: 240,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 呼吸光晕效果
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandPink.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      // 伴侣头像
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.level2(context),
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 问候语卡片
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.level1(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentCompanion != null
                            ? '${_getTimeGreeting()}，${_currentCompanion!.name}想你了~'
                            : '${_getTimeGreeting()}，创建一个伴侣吧~',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentCompanion != null
                            ? '今天过得怎么样？有什么想聊的吗？'
                            : '点击下方按钮，开始你的AI伴侣之旅',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // 互动信息卡片区
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _buildInfoCard(
                      context,
                      icon: Icons.calendar_today_rounded,
                      title: '在一起的时光',
                      subtitle: _currentCompanion != null
                          ? '${DateTime.now().difference(_currentCompanion!.createTime ?? DateTime.now()).inDays} 天'
                          : '未创建',
                    ),
                    _buildInfoCard(
                      context,
                      icon: Icons.chat_bubble_rounded,
                      title: '上次聊天',
                      subtitle: _currentConversation?.lastMessagePreview ?? '暂无',
                    ),
                    _buildInfoCard(
                      context,
                      icon: Icons.emoji_emotions_rounded,
                      title: '今日情绪',
                      subtitle: '开心 😊',
                    ),
                    _buildInfoCard(
                      context,
                      icon: Icons.psychology_rounded,
                      title: '记忆碎片',
                      subtitle: '查看全部',
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // 快捷入口区
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildQuickAction(context, '💬 聊天', _startChat),
                    _buildQuickAction(context, '🎵 一起听歌', () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('功能开发中...')),
                      );
                    }),
                    _buildQuickAction(context, '📖 讲故事', () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('功能开发中...')),
                      );
                    }),
                    _buildQuickAction(context, '🎮 玩游戏', () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('功能开发中...')),
                      );
                    }),
                    _buildQuickAction(context, '🧘 一起冥想', () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('功能开发中...')),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '凌晨好';
    if (hour < 12) return '上午好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.level1(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
    );
  }
}

/// 对话列表页
class ConversationListPage extends ConsumerStatefulWidget {
  const ConversationListPage({super.key});

  @override
  ConsumerState<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends ConsumerState<ConversationListPage> {
  List<Conversation> _conversations = [];
  Map<int, Companion> _companionMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final conversations = await apiService.getConversationList();
      final companions = await apiService.getCompanionList();

      final companionMap = {for (var c in companions) c.id: c};

      setState(() {
        _conversations = conversations;
        _companionMap = companionMap;
      });
    } catch (e) {
      debugPrint('加载对话列表失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: 打开搜索
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final conv = _conversations[index];
                      final companion = _companionMap[conv.companionId];
                      return _buildConversationTile(context, conv, companion);
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
            Icons.chat_bubble_outline_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有聊天记录',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '去和伴侣打个招呼吧',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    Conversation conv,
    Companion? companion,
  ) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.favorite_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              companion?.name ?? '未知伴侣',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (companion != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                companion.relationshipType,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        conv.lastMessagePreview ?? '暂无消息',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conv.lastMessageTime),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (conv.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${conv.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        context.push('/conversations/chat/${conv.id.toString()}');
      },
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
    return '刚刚';
  }
}
