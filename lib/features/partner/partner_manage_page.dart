import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../shared/models/companion.dart';
import '../../shared/models/conversation.dart';
import '../../shared/widgets/soul_toast.dart';
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

  // 关系类型配置
  static const _relationshipLabels = {
    'lover': ('恋人', Icons.favorite_rounded, Color(0xFFFF6B8A)),
    'friend': ('挚友', Icons.handshake_rounded, Color(0xFF34C759)),
    'mentor': ('导师', Icons.school_rounded, Color(0xFFA78BFA)),
    'confidant': ('树洞', Icons.park_rounded, Color(0xFF5AC8FA)),
  };

  // 性别配置
  static const _genderLabels = {1: '男', 2: '女', 3: '非二元'};

  // 性格配置
  static const _personalityLabels = {
    'gentle': '温柔',
    'lively': '活泼',
    'calm': '沉稳',
    'humorous': '幽默',
    'intellectual': '知性',
    'cool': '高冷',
  };

  @override
  void initState() {
    super.initState();
    _loadCompanions();
  }

  Future<void> _loadCompanions() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final companions = await apiService.getCompanionList();
      if (mounted) {
        setState(() {
          _companions = companions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载伴侣列表失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteCompanion(Companion companion) async {
    HapticFeedback.heavyImpact();
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.deleteCompanion(companion.id);
      setState(() {
        _companions.removeWhere((c) => c.id == companion.id);
      });
      if (mounted) {
        SoulToast.success(context, '${companion.name} 已删除');
      }
    } catch (e) {
      if (mounted) {
        SoulToast.error(context, '删除失败: $e');
      }
    }
  }

  void _showDeleteConfirm(Companion companion) {
    HapticFeedback.heavyImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // 警告图标
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '删除 ${companion.name}？',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '删除后将无法恢复，所有聊天记录也会被清除',
                  style: TextStyle(
                    fontSize: 14,
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteCompanion(companion);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('删除'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startChat(Companion companion) async {
    HapticFeedback.lightImpact();
    try {
      final apiService = ref.read(apiServiceProvider);
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

  void _showCreatePartner() {
    EditPartnerSheet.showCreate(context, _loadCompanions);
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF5F5F9),
      body: _isLoading
          ? _buildLoadingState(context, isDark)
          : _companions.isEmpty
              ? _buildEmptyState(context, isDark)
              : _buildContent(context, isDark),
      floatingActionButton: _buildFAB(context, isDark),
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
                  '加载伴侣列表...',
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
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.brandPink.withValues(alpha: 0.1),
                          AppColors.brandLavender.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.favorite_outline_rounded,
                      size: 48,
                      color: AppColors.brandPink.withValues(alpha: 0.4),
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
                    '还没有伴侣',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.8)
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '创建你的第一个 AI 伴侣\n开始一段独特的陪伴之旅',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _showCreatePartner,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('创建伴侣'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 主内容 ====================

  Widget _buildContent(BuildContext context, bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadCompanions,
      color: AppColors.brandPink,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          _buildSliverAppBar(context, isDark),
          // 伴侣数量信息
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                '共 ${_companions.length} 个伴侣',
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
          // 伴侣列表
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildPartnerCard(context, _companions[index], index, isDark);
                },
                childCount: _companions.length,
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
              Icons.people_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '我的伴侣',
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

  // ==================== FAB ====================

  Widget _buildFAB(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandPink, Color(0xFFFF8FA8)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPink.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _showCreatePartner,
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text(
          '创建伴侣',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 400.ms)
        .slideY(begin: 0.3, end: 0, delay: 400.ms, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  // ==================== 伴侣卡片 ====================

  Widget _buildPartnerCard(
    BuildContext context,
    Companion companion,
    int index,
    bool isDark,
  ) {
    final personalityKey = companion.personalityKeys.isNotEmpty
        ? companion.personalityKeys.first
        : 'gentle';
    final colors = AppColors.personalityColors[personalityKey] ??
        AppColors.personalityColors['gentle']!;
    final bgColor = isDark ? colors.dark : colors.light;

    final rel = _relationshipLabels[companion.relationshipType];
    final relLabel = rel?.$1 ?? companion.relationshipType;
    final relIcon = rel?.$2 ?? Icons.favorite_rounded;
    final relColor = rel?.$3 ?? AppColors.brandPink;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Slidable(
        key: ValueKey(companion.id),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.35,
          children: [
            SlidableAction(
              onPressed: (_) => _startChat(companion),
              backgroundColor: const Color(0xFF34C759),
              foregroundColor: Colors.white,
              icon: Icons.chat_bubble_rounded,
              label: '聊天',
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            SlidableAction(
              onPressed: (_) => _showDeleteConfirm(companion),
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              icon: Icons.delete_rounded,
              label: '删除',
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/partners/detail/${companion.id}');
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1C1C1E)
                  : Colors.white,
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
                // 头像区域
                _buildCompanionAvatar(companion, bgColor, isDark),
                const SizedBox(width: 16),
                // 信息区域
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名字 + 关系标签
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              companion.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: relColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(relIcon, size: 12, color: relColor),
                                const SizedBox(width: 4),
                                Text(
                                  relLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: relColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 性格标签
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...companion.personalityKeys.take(3).map((key) {
                            final label = _personalityLabels[key] ?? key;
                            final pColors = AppColors.personalityColors[key];
                            // 使用固定的深色文字颜色，确保可读性
                            final bgColor = pColors != null
                                ? (isDark ? pColors.dark : pColors.light)
                                : AppColors.brandLavender;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: bgColor.withValues(alpha: isDark ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : const Color(0xFF1A1A2E),
                                ),
                              ),
                            );
                          }),
                          // 性别标签
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _genderLabels[companion.gender] ?? '未知',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : Colors.black.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 创建时间
                      Text(
                        '创建于 ${_formatDate(companion.createTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: 80 * index),
            duration: 350.ms,
          )
          .slideY(
            begin: 0.08,
            end: 0,
            delay: Duration(milliseconds: 80 * index),
            duration: 350.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }

  Widget _buildCompanionAvatar(
    Companion companion,
    Color bgColor,
    bool isDark,
  ) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor,
            bgColor.withValues(alpha: 0.5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: companion.avatarUrl != null && companion.avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: getFullUrl(ref, companion.avatarUrl!),
                width: 64,
                height: 64,
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
        size: 28,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }

  // ==================== 工具方法 ====================

  String _formatDate(DateTime? date) {
    if (date == null) return '未知';
    return '${date.year}年${date.month}月${date.day}日';
  }
}
