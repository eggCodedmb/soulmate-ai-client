import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';

/// 聊天页顶部导航栏组件
class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? companionName;
  final String? companionAvatarUrl;
  final int? companionId;

  const ChatAppBar({
    super.key,
    this.companionName,
    this.companionAvatarUrl,
    this.companionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF0D0D0F) : Colors.white;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
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
      titleSpacing: 0,
      title: Row(
        children: [
          const SizedBox(width: 8),
          _buildAppBarAvatar(context, ref, isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companionName ?? 'AI伴侣',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34C759),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '在线',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.more_horiz_rounded,
            color: isDark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.4),
          ),
          onPressed: () {
            if (companionId != null) {
              context.push('/partners/detail/$companionId');
            }
          },
        ),
      ],
    );
  }

  Widget _buildAppBarAvatar(BuildContext context, WidgetRef ref, bool isDark) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.brandPink.withValues(alpha: 0.85),
            AppColors.brandLavender.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPink.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: companionAvatarUrl != null && companionAvatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: getFullUrl(ref, companionAvatarUrl!),
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildAvatarFallback(38),
                errorWidget: (_, __, ___) => _buildAvatarFallback(38),
              )
            : _buildAvatarFallback(38),
      ),
    );
  }

  Widget _buildAvatarFallback(double size) {
    return Center(
      child: Icon(
        Icons.favorite_rounded,
        size: size * 0.45,
        color: Colors.white,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
