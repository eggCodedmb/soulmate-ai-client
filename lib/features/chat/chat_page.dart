import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_service.dart';
import '../../shared/models/message.dart';

/// 聊天详情页
class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatPage({super.key, required this.conversationId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isTyping = false;
  bool _isLoading = true;
  bool _hasText = false;
  int? _companionId;
  String? _companionName;
  String? _companionAvatarUrl;
  late final int _conversationId;

  @override
  void initState() {
    super.initState();
    _conversationId = int.parse(widget.conversationId);
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final apiService = ref.read(apiServiceProvider);

      final conversations = await apiService.getConversationList();
      final conv = conversations.firstWhere(
        (c) => c.id == _conversationId,
        orElse: () => throw Exception('对话不存在'),
      );
      _companionId = conv.companionId;

      final companion = await apiService.getCompanion(conv.companionId);
      _companionName = companion.name;
      _companionAvatarUrl = companion.avatarUrl;

      final messages = await apiService.getMessages(
        _conversationId,
        size: 50,
      );

      setState(() {
        _messages.clear();
        _messages.addAll(messages);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载消息失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载消息失败: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _companionId == null) return;

    // 乐观插入用户消息
    final tempMessage = Message(
      id: 0,
      conversationId: _conversationId,
      senderType: 'user',
      content: content,
      createTime: DateTime.now(),
    );

    setState(() {
      _messages.insert(0, tempMessage);
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final apiService = ref.read(apiServiceProvider);

      // 显示打字指示器
      setState(() => _isTyping = true);

      // 调用同步端点（保存用户消息 + AI回复，返回AI回复）
      final aiReply = await apiService.sendMessage(
        SendMessageRequest(
          conversationId: _conversationId,
          companionId: _companionId!,
          content: content,
        ),
      );

      setState(() => _isTyping = false);

      // 插入AI回复（用户消息之后）
      setState(() {
        _messages.insert(1, aiReply);
      });
      _scrollToBottom();

      // 从服务器刷新获取权威数据
      await _refreshMessages();
    } catch (e) {
      debugPrint('发送消息失败: $e');
      setState(() => _isTyping = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }

  /// 从服务器重新加载消息（不显示loading状态）
  Future<void> _refreshMessages() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final messages = await apiService.getMessages(
        _conversationId,
        size: 50,
      );
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });
    } catch (e) {
      debugPrint('刷新消息失败: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== UI 构建 ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkSurface : const Color(0xFFF8F9FE),
      appBar: _buildAppBar(context, isDark),
      body: _isLoading
          ? _buildLoadingState(context)
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState(context, isDark)
                      : _buildMessageList(context, isDark),
                ),
                if (_isTyping) _buildTypingIndicator(context, isDark),
                _buildInputBar(context, isDark),
              ],
            ),
    );
  }

  /// 毛玻璃 AppBar
  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkSurface : Colors.white)
                  .withOpacity(0.85),
              border: Border(
                bottom: BorderSide(
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                ),
              ),
            ),
          ),
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          const SizedBox(width: 4),
          _buildCompanionAvatar(context, isDark),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _companionName ?? 'AI伴侣',
                style: GoogleFonts.notoSansSc(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightOnSurface,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '在线',
                    style: GoogleFonts.notoSansSc(
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.more_horiz_rounded,
            color: isDark ? Colors.white70 : AppColors.lightOnSurfaceVariant,
          ),
          onPressed: () => _showChatOptions(context),
        ),
      ],
    );
  }

  /// 伴侣头像
  Widget _buildCompanionAvatar(BuildContext context, bool isDark,
      {double size = 36}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.brandPink.withOpacity(0.8),
            AppColors.brandLavender.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPink.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _companionAvatarUrl != null
          ? ClipOval(
              child: Image.network(
                _companionAvatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarIcon(size),
              ),
            )
          : _avatarIcon(size),
    );
  }

  Widget _avatarIcon(double size) {
    return Center(
      child: Icon(
        Icons.favorite_rounded,
        size: size * 0.45,
        color: Colors.white,
      ),
    );
  }

  /// 加载状态
  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.brandPink.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '加载中...',
            style: GoogleFonts.notoSansSc(
              fontSize: 14,
              color: AppColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.brandPink.withOpacity(0.15),
                  AppColors.brandLavender.withOpacity(0.15),
                ],
              ),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: AppColors.brandPink,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '开始和${_companionName ?? 'TA'}聊天吧',
            style: GoogleFonts.notoSansSc(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : AppColors.lightOnSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '发送一条消息开启对话 💬',
            style: GoogleFonts.notoSansSc(
              fontSize: 13,
              color: AppColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 消息列表
  Widget _buildMessageList(BuildContext context, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final showDateSeparator = _shouldShowDateSeparator(index);

        return _MessageBubbleWrapper(
          isNew: message.id == 0,
          child: Column(
            children: [
              if (showDateSeparator)
                _buildDateSeparator(message.createTime, isDark),
              _buildMessageBubble(context, message, isDark),
            ],
          ),
        );
      },
    );
  }

  /// 是否显示日期分隔符
  bool _shouldShowDateSeparator(int index) {
    if (index >= _messages.length - 1) return true;

    final current = _messages[index];
    final older = _messages[index + 1];

    if (current.createTime == null || older.createTime == null) return false;

    final currentDate = current.createTime!;
    final olderDate = older.createTime!;

    return currentDate.day != olderDate.day ||
        currentDate.month != olderDate.month ||
        currentDate.year != olderDate.year;
  }

  /// 日期分隔符
  Widget _buildDateSeparator(DateTime? dateTime, bool isDark) {
    if (dateTime == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final date = dateTime;
    String label;

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = '今天';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = '昨天';
    } else if (now.difference(date).inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      label = weekdays[date.weekday - 1];
    } else {
      label = '${date.month}月${date.day}日';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: GoogleFonts.notoSansSc(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
            ),
          ),
        ],
      ),
    );
  }

  /// 消息气泡
  Widget _buildMessageBubble(
      BuildContext context, Message message, bool isDark) {
    final isUser = message.senderType == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _buildCompanionAvatar(context, isDark, size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () => _showMessageOptions(context, message),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                              colors: [
                                AppColors.brandPink,
                                Color(0xFFFF8FA8),
                              ],
                            )
                          : null,
                      color: isUser
                          ? null
                          : isDark
                              ? AppColors.darkSurfaceContainerHighest
                              : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 6),
                        bottomRight: Radius.circular(isUser ? 6 : 20),
                      ),
                      boxShadow: isUser
                          ? [
                              BoxShadow(
                                color: AppColors.brandPink.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(isDark ? 0.15 : 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Text(
                      message.content,
                      style: GoogleFonts.notoSansSc(
                        fontSize: 15,
                        height: 1.5,
                        color: isUser
                            ? Colors.white
                            : isDark
                                ? Colors.white.withOpacity(0.9)
                                : AppColors.lightOnSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _buildMessageMeta(message, isUser, isDark),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildReadStatus(message, isDark),
          ],
        ],
      ),
    );
  }

  /// 消息元信息（时间戳）
  Widget _buildMessageMeta(Message message, bool isUser, bool isDark) {
    if (message.createTime == null) return const SizedBox.shrink();

    final time = message.createTime!;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        timeStr,
        style: GoogleFonts.notoSansSc(
          fontSize: 10,
          color: isDark ? Colors.white24 : Colors.black26,
        ),
      ),
    );
  }

  /// 已读状态
  Widget _buildReadStatus(Message message, bool isDark) {
    return Icon(
      Icons.done_all_rounded,
      size: 14,
      color: message.readStatus == 1
          ? AppColors.brandPink
          : isDark
              ? Colors.white24
              : Colors.black26,
    );
  }

  /// 打字指示器
  Widget _buildTypingIndicator(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildCompanionAvatar(context, isDark, size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.darkSurfaceContainerHighest : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPulsingDot(0),
                const SizedBox(width: 5),
                _buildPulsingDot(1),
                const SizedBox(width: 5),
                _buildPulsingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final progress = ((value - delay) % 1.0).clamp(0.0, 1.0);
        final opacity =
            (progress < 0.5) ? (progress * 2) : (2 - progress * 2);
        final scale = 0.6 + 0.4 * opacity;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.brandPink.withOpacity(0.3 + 0.7 * opacity),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  /// 底部输入栏
  Widget _buildInputBar(BuildContext context, bool isDark) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 8,
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkSurface : Colors.white)
                .withOpacity(0.9),
            border: Border(
              top: BorderSide(
                color:
                    (isDark ? Colors.white : Colors.black).withOpacity(0.06),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainerLow
                        : const Color(0xFFF2F3F8),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    style: GoogleFonts.notoSansSc(
                      fontSize: 15,
                      color: isDark ? Colors.white : AppColors.lightOnSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      hintStyle: GoogleFonts.notoSansSc(
                        fontSize: 15,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSendButton(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: _hasText ? _sendMessage : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _hasText
              ? const LinearGradient(
                  colors: [AppColors.brandPink, Color(0xFFFF8FA8)],
                )
              : null,
          color: _hasText
              ? null
              : isDark
                  ? AppColors.darkSurfaceContainerLow
                  : const Color(0xFFF2F3F8),
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          size: 22,
          color: _hasText
              ? Colors.white
              : isDark
                  ? Colors.white24
                  : Colors.black26,
        ),
      ),
    );
  }

  /// 聊天选项
  void _showChatOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('伴侣详情'),
              onTap: () {
                Navigator.pop(context);
                if (_companionId != null) {
                  context.push('/partners/detail/$_companionId');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 消息选项
  void _showMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            if (message.senderType == 'user')
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 消息气泡动画包装器 — 新消息淡入+滑动，历史消息直接显示
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

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _offset = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

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
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}
