import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/message.dart';
import '../../../shared/models/tts_config.dart';
import 'tts_button.dart';

/// 消息气泡组件
class MessageBubble extends ConsumerWidget {
  final Message message;
  final String? companionAvatarUrl;
  final Color personalityColor;
  final bool isStreaming;
  final String messageKey;
  final TtsConfig? effectiveTtsConfig;
  final VoidCallback onLongPress;

  static const _emotionMap = {
    'happy': ('😊', '开心', Color(0xFF34C759)),
    'sad': ('😢', '难过', Color(0xFF5AC8FA)),
    'angry': ('😠', '生气', Color(0xFFFF3B30)),
    'surprised': ('😮', '惊讶', Color(0xFFFF9500)),
    'love': ('💕', '喜爱', AppColors.brandPink),
    'thinking': ('🤔', '思考', AppColors.brandLavender),
    'shy': ('😳', '害羞', Color(0xFFFFB88C)),
    'excited': ('🤩', '兴奋', Color(0xFFFF9500)),
  };

  const MessageBubble({
    required this.message,
    required this.personalityColor,
    required this.isStreaming,
    required this.messageKey,
    required this.onLongPress,
    super.key,
    this.companionAvatarUrl,
    this.effectiveTtsConfig,
  });

  String _cleanMessageContent(String content) {
    return content
        .replaceAll(RegExp('<command.*?>.*?</command>', dotAll: true), '')
        .replaceAll(RegExp(r'<command.*$', dotAll: true), '')
        .trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUser = message.senderType == 'user';

    return _MessageBubbleWrapper(
      isNew: message.id == 0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              _buildMessageAvatar(context, ref),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: onLongPress,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          gradient: isUser
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.brandPink,
                                    Color(0xFFFF8FA8),
                                  ],
                                )
                              : null,
                          color: isUser
                              ? null
                              : isDark
                              ? const Color(0xFF1C1C1E)
                              : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isUser ? 20 : 6),
                            bottomRight: Radius.circular(isUser ? 6 : 20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isUser
                                  ? AppColors.brandPink.withValues(alpha: 0.25)
                                  : Colors.black.withValues(
                                      alpha: isDark ? 0.12 : 0.04,
                                    ),
                              blurRadius: isUser ? 10 : 6,
                              offset: Offset(0, isUser ? 3 : 1),
                            ),
                          ],
                        ),
                        child: _buildMessageText(isUser, isDark),
                      ),
                    ),
                  ),

                  // 情绪标签（仅AI消息）
                  if (!isUser &&
                      message.emotionTag != null &&
                      message.emotionTag!.isNotEmpty)
                    _buildEmotionTag(message.emotionTag!, isDark),

                  // TTS 喇叭按钮（仅AI消息，流式完成且有TTS配置时显示）
                  if (!isUser && message.id > 0 && effectiveTtsConfig != null)
                    TtsButton(
                      message: message,
                      messageKey: messageKey,
                      effectiveTtsConfig: effectiveTtsConfig,
                    ),

                  const SizedBox(height: 4),
                  _buildMessageMeta(isUser, isDark),
                ],
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 10),
              _buildReadStatus(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageAvatar(BuildContext context, WidgetRef ref) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            personalityColor.withValues(alpha: 0.6),
            AppColors.brandPink.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: ClipOval(
        child: companionAvatarUrl != null && companionAvatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: getFullUrl(ref, companionAvatarUrl!),
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildAvatarFallback(30),
                errorWidget: (_, __, ___) => _buildAvatarFallback(30),
              )
            : _buildAvatarFallback(30),
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

  Widget _buildEmotionTag(String emotionTag, bool isDark) {
    final entry = _emotionMap[emotionTag];
    final emoji = entry?.$1 ?? '💭';
    final label = entry?.$2 ?? emotionTag;
    final color = entry?.$3 ?? AppColors.brandLavender;

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageMeta(bool isUser, bool isDark) {
    if (message.createTime == null) return const SizedBox.shrink();
    final time = message.createTime!;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        timeStr,
        style: TextStyle(
          fontSize: 11,
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Widget _buildReadStatus(bool isDark) {
    return Icon(
      message.readStatus == 1 ? Icons.done_all_rounded : Icons.done_rounded,
      size: 14,
      color: message.readStatus == 1
          ? AppColors.brandPink
          : isDark
          ? Colors.white.withValues(alpha: 0.2)
          : Colors.black.withValues(alpha: 0.2),
    );
  }

  Widget _buildMessageText(bool isUser, bool isDark) {
    final isStreamingThis = isStreaming && !isUser && message.id == 0;

    final textColor = isUser
        ? Colors.white
        : isDark
        ? Colors.white.withValues(alpha: 0.88)
        : const Color(0xFF1A1A2E);

    final cleanContent = _cleanMessageContent(message.content);

    if (!isStreamingThis) {
      return Text(
        cleanContent,
        style: TextStyle(fontSize: 15, height: 1.55, color: textColor),
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: cleanContent),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _BlinkingCursor(),
          ),
        ],
      ),
      style: TextStyle(fontSize: 15, height: 1.55, color: textColor),
    );
  }
}

/// 闪烁光标组件
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 18,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          color: AppColors.brandPink.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

/// 消息气泡进场动画包装器
class _MessageBubbleWrapper extends StatefulWidget {
  final Widget child;
  final bool isNew;

  const _MessageBubbleWrapper({required this.child, this.isNew = false});

  @override
  State<_MessageBubbleWrapper> createState() => _MessageBubbleWrapperState();
}

class _MessageBubbleWrapperState extends State<_MessageBubbleWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    _offset = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.isNew) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isNew) return widget.child;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
