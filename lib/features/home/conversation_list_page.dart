import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/routing/app_router.dart';
import '../../shared/models/companion.dart';
import '../../shared/models/conversation.dart';

/// 对话列表页
class ConversationListPage extends ConsumerStatefulWidget {
  const ConversationListPage({super.key});

  @override
  ConsumerState<ConversationListPage> createState() =>
      _ConversationListPageState();
}

class _ConversationListPageState extends ConsumerState<ConversationListPage>
    with RouteAware {
  List<Conversation> _conversations = [];
  Map<int, Companion> _companionMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
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

  /// 从聊天页返回时自动刷新
  @override
  void didPopNext() {
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final results = await Future.wait([
        apiService.getConversationList(),
        apiService.getCompanionList(),
      ]);
      final conversations = results[0] as List<Conversation>;
      final companions = results[1] as List<Companion>;
      final companionMap = {for (var c in companions) c.id: c};

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _companionMap = companionMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载对话列表失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getCompanionName(int companionId) {
    return _companionMap[companionId]?.name ?? '未知伴侣';
  }

  String? _getCompanionAvatar(int companionId) {
    return _companionMap[companionId]?.avatarUrl;
  }

  List<String> _getCompanionPersonalities(int companionId) {
    return _companionMap[companionId]?.personalityKeys ?? [];
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF5F5F9),
      body: _isLoading
          ? _buildLoadingState(context, isDark)
          : _conversations.isEmpty
              ? _buildEmptyState(context, isDark)
              : _buildContent(context, isDark),
    );
  }

  // ==================== 加载状态 ====================

  Widget _buildLoadingState(BuildContext context, bool isDark) {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, isDark),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.brandPink.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '加载消息...',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 空状态 ====================

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, isDark),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brandPink.withValues(alpha: 0.12),
                        AppColors.brandLavender.withValues(alpha: 0.12),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 40,
                    color: AppColors.brandPink.withValues(alpha: 0.45),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(
                      begin: 1,
                      end: 1.06,
                      duration: 2500.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 24),
                Text(
                  '还没有消息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '去和伴侣打个招呼吧 💬',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 主内容 ====================

  Widget _buildContent(BuildContext context, bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: AppColors.brandPink,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          _buildSliverAppBar(context, isDark),
          // 统计信息
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                '共 ${_conversations.length} 个对话',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.4),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 300.ms)
                .slideX(begin: -0.05, end: 0, delay: 100.ms, duration: 300.ms),
          ),
          // 对话列表
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildConversationCard(
                    context,
                    _conversations[index],
                    index,
                    isDark,
                  );
                },
                childCount: _conversations.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== AppBar ====================

  Widget _buildSliverAppBar(BuildContext context, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF0D0D0F) : Colors.white;

    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor.withValues(alpha: 0.88),
              border: Border(
                bottom: BorderSide(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandPink, AppColors.brandLavender],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPink.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '消息',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 对话卡片 ====================

  Widget _buildConversationCard(
    BuildContext context,
    Conversation conv,
    int index,
    bool isDark,
  ) {
    final companionName = _getCompanionName(conv.companionId);
    final avatarUrl = _getCompanionAvatar(conv.companionId);
    final personalities = _getCompanionPersonalities(conv.companionId);
    final companion = _companionMap[conv.companionId];

    final personalityKey = personalities.isNotEmpty ? personalities.first : 'gentle';
    final pColors = AppColors.personalityColors[personalityKey] ??
        AppColors.personalityColors['gentle']!;
    final bgColor = isDark ? pColors.dark : pColors.light;

    final relLabels = {
      'lover': '恋人',
      'friend': '挚友',
      'mentor': '导师',
      'confidant': '树洞',
    };
    final relLabel = relLabels[companion?.relationshipType] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/conversations/chat/${conv.id.toString()}');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // 头像
              _buildAvatar(avatarUrl, bgColor, isDark),
              const SizedBox(width: 14),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名字 + 关系 + 时间
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            companionName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (relLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandPink.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              relLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.brandPink,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(conv.lastMessageTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 最后消息 + 未读数
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conv.lastMessagePreview ?? '暂无消息',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.45)
                                  : Colors.black.withValues(alpha: 0.4),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conv.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandPink,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brandPink.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: 60 * index),
            duration: 300.ms,
          )
          .slideY(
            begin: 0.06,
            end: 0,
            delay: Duration(milliseconds: 60 * index),
            duration: 300.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, Color bgColor, bool isDark) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgColor, bgColor.withValues(alpha: 0.5)],
        ),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: getFullUrl(ref, avatarUrl),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildAvatarFallback(),
                errorWidget: (_, __, ___) => _buildAvatarFallback(),
              )
            : _buildAvatarFallback(),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Center(
      child: Icon(
        Icons.favorite_rounded,
        size: 24,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }

  // ==================== 工具方法 ====================

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 7) {
      return '${time.month}/${time.day}';
    }
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
    return '刚刚';
  }
}
