import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/models/companion.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/memory.dart';

/// 首页 - 伴侣主页
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with RouteAware {
  Companion? _currentCompanion;
  List<Companion> _companions = [];
  List<Conversation> _conversations = [];
  List<Memory> _memories = [];
  bool _isLoading = true;

  // 关系类型中文映射
  static const _relationshipLabels = {
    'lover': '恋人',
    'friend': '挚友',
    'mentor': '导师',
    'confidant': '树洞',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// 从子页面返回时自动刷新
  @override
  void didPopNext() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);

      // 并行加载用户信息、伴侣列表、对话列表
      final results = await Future.wait([
        apiService.getUserInfo(),
        apiService.getCompanionList(),
        apiService.getConversationList(),
      ]);

      final companions = results[1] as List<Companion>;
      final conversations = results[2] as List<Conversation>;

      Companion? companion;
      List<Memory> memories = [];

      if (companions.isNotEmpty) {
        companion = companions.first;
        // 加载当前伴侣的记忆
        try {
          memories =
              await apiService.getMemoryList(companionId: companion.id);
        } catch (_) {
          // 记忆加载失败不影响主页
        }
      }

      if (mounted) {
        setState(() {
          _currentCompanion = companion;
          _companions = companions;
          _conversations = conversations;
          _memories = memories;
        });
      }
    } catch (e) {
      debugPrint('加载首页数据失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  Future<void> _startChat() async {
    if (_currentCompanion == null) return;

    try {
      final apiService = ref.read(apiServiceProvider);

      // 查找或创建对话
      final existingConv = _conversations.where(
        (c) => c.companionId == _currentCompanion!.id,
      );

      Conversation conv;
      if (existingConv.isNotEmpty) {
        conv = existingConv.first;
      } else {
        conv = await apiService.createConversation(_currentCompanion!.id);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandPink),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.brandPink,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // 渐变头部 + 伴侣形象
            _buildHeroHeader(context),

            // 快捷聊天入口
            _buildChatEntryCard(context),

            // 互动数据统计
            _buildStatsRow(context),

            // 最近记忆
            if (_memories.isNotEmpty) _buildRecentMemories(context),

            // 最近对话
            if (_conversations.isNotEmpty)
              _buildRecentConversations(context),

            // 快捷操作网格
            _buildQuickActions(context),

            // 底部留白
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanionSelector(BuildContext context) {
    if (_companions.length <= 1) return const SizedBox.shrink();

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _companions.length,
        itemBuilder: (context, index) {
          final companion = _companions[index];
          final isSelected = companion.id == _currentCompanion?.id;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () async {
                if (isSelected) return;
                await HapticFeedback.lightImpact();

                var memories = <Memory>[];
                try {
                  final apiService = ref.read(apiServiceProvider);
                  memories =
                      await apiService.getMemoryList(companionId: companion.id);
                } catch (_) {
                  // 容错处理
                }

                if (mounted) {
                  setState(() {
                    _currentCompanion = companion;
                    _memories = memories;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.brandPink : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.brandPink.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: ClipOval(
                  child: Opacity(
                    opacity: isSelected ? 1.0 : 0.65,
                    child: companion.avatarUrl != null &&
                            companion.avatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: getFullUrl(ref, companion.avatarUrl!),
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                _buildPlaceholderAvatar(companion.name),
                            errorWidget: (_, __, ___) =>
                                _buildPlaceholderAvatar(companion.name),
                          )
                        : _buildPlaceholderAvatar(companion.name),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderAvatar(String name) {
    return Container(
      width: 36,
      height: 36,
      color: AppColors.brandPink.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: const TextStyle(
            color: AppColors.brandPink,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ==================== 头部区域 ====================

  Widget _buildHeroHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final companion = _currentCompanion;

    // 根据伴侣性格选择主题色
    final personalityKey = companion?.personalityKeys.isNotEmpty == true
        ? companion!.personalityKeys.first
        : 'gentle';
    final personalityColor =
        AppColors.personalityColors[personalityKey] ?? AppColors.personalityColors['gentle']!;
    final bgColor = isDark ? personalityColor.dark : personalityColor.light;

    return SliverAppBar(
      expandedHeight: 385,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 渐变背景
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1A1025),
                          bgColor.withValues(alpha: 0.3),
                        ]
                      : [
                          AppColors.brandPink.withValues(alpha: 0.15),
                          bgColor,
                        ],
                ),
              ),
            ),

            // 毛玻璃效果
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),

            // 内容
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部状态栏
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getTimeGreeting(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.settings_outlined,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => context.push('/profile/settings'),
                        ),
                      ],
                    ),

                    // 伴侣选择栏
                    _buildCompanionSelector(context),

                    // 伴侣头像区域
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 头像 + 呼吸光晕
                            _buildCompanionAvatar(context, companion),

                            const SizedBox(height: 12),

                            // 问候语
                            Text(
                              companion != null
                                  ? '${_getTimeGreeting()}，${companion.name}想你了~'
                                  : '${_getTimeGreeting()}，创建一个伴侣吧~',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 8),

                            // 关系标签
                            if (companion != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandPink.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _relationshipLabels[companion.relationshipType] ??
                                      companion.relationshipType,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: AppColors.brandPink,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                                    .animate()
                                    .fadeIn(delay: 300.ms, duration: 400.ms)
                                    .scale(
                                      begin: const Offset(0.8, 0.8),
                                      delay: 300.ms,
                                      duration: 400.ms,
                                      curve: Curves.easeOutBack,
                                    ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanionAvatar(BuildContext context, Companion? companion) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 根据伴侣性格选择光晕颜色
    final personalityKey = companion?.personalityKeys.isNotEmpty == true
        ? companion!.personalityKeys.first
        : 'gentle';
    final personalityColor =
        AppColors.personalityColors[personalityKey] ?? AppColors.personalityColors['gentle']!;
    final isDark = theme.brightness == Brightness.dark;
    final glowColor = isDark
        ? AppColors.brandPinkDark.withValues(alpha: 0.3)
        : AppColors.brandPink.withValues(alpha: 0.25);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.05),
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOut,
      onEnd: () {
        // 通过 setState 触发重建来循环动画
        if (mounted) setState(() {});
      },
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 30,
                  spreadRadius: 8 * scale,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 3,
          ),
          boxShadow: AppShadows.level2(context),
        ),
        child: ClipOval(
          child: companion?.avatarUrl != null &&
                  companion!.avatarUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: getFullUrl(ref, companion.avatarUrl!),
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildAvatarPlaceholder(
                    context,
                    personalityColor: isDark
                        ? personalityColor.dark
                        : personalityColor.light,
                  ),
                  errorWidget: (_, __, ___) => _buildAvatarPlaceholder(
                    context,
                    personalityColor: isDark
                        ? personalityColor.dark
                        : personalityColor.light,
                  ),
                )
              : _buildAvatarPlaceholder(
                  context,
                  personalityColor:
                      isDark ? personalityColor.dark : personalityColor.light,
                ),
        ),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(
          begin: 1,
          end: 1.05,
          duration: 2500.ms,
          curve: Curves.easeInOut,
        );
  }

  Widget _buildAvatarPlaceholder(
    BuildContext context, {
    required Color personalityColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandPink.withValues(alpha: 0.2),
            personalityColor.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.favorite_rounded,
          size: 64,
          color: AppColors.brandPink.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  // ==================== 快捷聊天入口 ====================

  Widget _buildChatEntryCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final companion = _currentCompanion;

    if (companion == null) {
      // 无伴侣时引导创建
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GestureDetector(
            onTap: () => context.push('/partners'),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.brandPink.withValues(alpha: 0.1),
                    AppColors.brandLavender.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.brandPink.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.brandPink, AppColors.brandLavender],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '创建你的 AI 伴侣',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '开始一段独特的陪伴之旅',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0, delay: 100.ms, duration: 400.ms),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GestureDetector(
          onTap: _startChat,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.level1(context),
            ),
            child: Row(
              children: [
                // 渐变图标
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brandPink, AppColors.brandWarmPeach],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '想和${companion.name}聊点什么？',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点击开始对话',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandPink.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.brandPink,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms)
            .slideY(begin: 0.1, end: 0, delay: 100.ms, duration: 400.ms),
      ),
    );
  }

  // ==================== 数据统计 ====================

  Widget _buildStatsRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final companion = _currentCompanion;

    final days = companion?.createTime != null
        ? DateTime.now().difference(companion!.createTime!).inDays
        : 0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.level1(context),
          ),
          child: Row(
            children: [
              _buildStatItem(
                context,
                icon: Icons.calendar_today_rounded,
                value: '$days',
                label: '在一起天数',
                color: AppColors.brandPink,
              ),
              _buildStatDivider(context),
              _buildStatItem(
                context,
                icon: Icons.psychology_rounded,
                value: '${_memories.length}',
                label: '条记忆',
                color: AppColors.brandLavender,
              ),
              _buildStatDivider(context),
              _buildStatItem(
                context,
                icon: Icons.chat_bubble_rounded,
                value: '${_conversations.length}',
                label: '次对话',
                color: AppColors.brandWarmPeach,
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(begin: 0.08, end: 0, delay: 200.ms, duration: 400.ms),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }

  // ==================== 最近记忆 ====================

  Widget _buildRecentMemories(BuildContext context) {
    final theme = Theme.of(context);

    // 只显示最近 5 条记忆
    final recentMemories = _memories.take(5).toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '最近记忆',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/profile/memories'),
                    child: Text(
                      '查看全部',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.brandPink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recentMemories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildMemoryCard(context, recentMemories[index], index);
                },
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: 300.ms, duration: 400.ms)
          .slideY(begin: 0.06, end: 0, delay: 300.ms, duration: 400.ms),
    );
  }

  Widget _buildMemoryCard(BuildContext context, Memory memory, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 分类颜色
    final categoryColors = {
      'personal_info': AppColors.brandLavender,
      'shared_experience': AppColors.brandWarmPeach,
      'preference': AppColors.brandPink,
      'habit': const Color(0xFFFF9500),
    };
    final categoryIcons = {
      'personal_info': Icons.info_outline_rounded,
      'shared_experience': Icons.auto_stories_rounded,
      'preference': Icons.favorite_rounded,
      'habit': Icons.star_rounded,
    };

    final color = categoryColors[memory.category] ?? AppColors.brandPink;
    final icon = categoryIcons[memory.category] ?? Icons.lightbulb_rounded;

    return GestureDetector(
      onTap: () => context.push('/profile/memories'),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.level1(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分类图标 + 重要度
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                // 重要度星星
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final filled = i < (memory.importance / 2).ceil();
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 12,
                      color: filled
                          ? const Color(0xFFFF9500)
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 标题
            Text(
              memory.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // 内容预览
            Expanded(
              child: Text(
                memory.content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 最近对话 ====================

  Widget _buildRecentConversations(BuildContext context) {
    final theme = Theme.of(context);

    // 只显示最近 2 条对话
    final recentConvs = _conversations.take(2).toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                '最近对话',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...recentConvs.map(
              (conv) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildConversationPreview(context, conv),
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: 400.ms, duration: 400.ms)
          .slideY(begin: 0.06, end: 0, delay: 400.ms, duration: 400.ms),
    );
  }

  Widget _buildConversationPreview(BuildContext context, Conversation conv) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 根据对话的 companionId 找到对应的伴侣
    final companion = _conversations.isNotEmpty
        ? _findCompanionById(conv.companionId)
        : _currentCompanion;

    return GestureDetector(
      onTap: () =>
          context.push('/conversations/chat/${conv.id.toString()}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.level1(context),
        ),
        child: Row(
          children: [
            // 头像
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandPink, AppColors.brandLavender],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          companion?.name ?? '对话',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (conv.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandPink,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conv.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conv.lastMessagePreview ?? '暂无消息',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // 时间
            Text(
              _formatTime(conv.lastMessageTime),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 根据伴侣ID查找伴侣
  Companion? _findCompanionById(int? companionId) {
    if (companionId == null) return _currentCompanion;
    try {
      return _companions.firstWhere((c) => c.id == companionId);
    } catch (_) {
      return _currentCompanion;
    }
  }

  // ==================== 快捷操作 ====================

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final companion = _currentCompanion;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                '快捷操作',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildActionCard(
                  context,
                  icon: Icons.chat_bubble_rounded,
                  label: '开始聊天',
                  gradientColors: const [
                    AppColors.brandPink,
                    AppColors.brandWarmPeach,
                  ],
                  onTap: _startChat,
                ),
                _buildActionCard(
                  context,
                  icon: Icons.psychology_rounded,
                  label: '记忆管理',
                  gradientColors: const [
                    AppColors.brandLavender,
                    Color(0xFF818CF8),
                  ],
                  onTap: () => context.push('/profile/memories'),
                ),
                _buildActionCard(
                  context,
                  icon: Icons.people_rounded,
                  label: '伴侣详情',
                  gradientColors: const [
                    Color(0xFF34C759),
                    Color(0xFF30D158),
                  ],
                  onTap: () {
                    if (companion != null) {
                      context.push('/partners/detail/${companion.id}');
                    } else {
                      context.push('/partners');
                    }
                  },
                ),
                _buildActionCard(
                  context,
                  icon: Icons.settings_rounded,
                  label: '设置',
                  gradientColors: const [
                    Color(0xFF8E8E93),
                    Color(0xFF636366),
                  ],
                  onTap: () => context.push('/profile/settings'),
                ),
              ],
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: 500.ms, duration: 400.ms)
          .slideY(begin: 0.06, end: 0, delay: 500.ms, duration: 400.ms),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.level1(context),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 工具方法 ====================

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '凌晨好';
    if (hour < 12) return '上午好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
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
