import 'dart:async';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/network/asr_api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/message_local_storage.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/models/companion.dart';
import '../../shared/models/message.dart';
import '../../shared/models/tts_config.dart';
import '../../shared/widgets/soul_toast.dart';
import 'tts_audio_service.dart';
import 'tts_provider.dart';
import 'voice_recorder_widget.dart';

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
  final FocusNode _inputFocusNode = FocusNode();
  final List<Message> _messages = [];
  bool _isTyping = false;
  bool _isStreaming = false;
  bool _isLoading = true;
  bool _hasText = false;
  bool _isVoiceMode = false;
  bool _isTranscribing = false;
  CancelToken? _streamCancelToken;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int? _companionId;
  String? _companionName;
  String? _companionAvatarUrl;
  List<String> _companionPersonalities = [];
  TtsConfig? _companionTtsConfig;
  late final int _conversationId;

  // 情绪映射
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

  @override
  void dispose() {
    _streamCancelToken?.cancel('页面退出');
    // 停止 TTS 播放
    ref.read(ttsProvider.notifier).stop();
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final localStorage = MessageLocalStorage.instance;

      // 先从本地加载缓存消息
      final cachedMessages = await localStorage.getMessages(
        _conversationId,
        limit: 50,
      );

      if (cachedMessages.isNotEmpty && mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(cachedMessages);
          _isLoading = false;
        });
      }

      // 从服务器获取对话信息
      final conversations = await apiService.getConversationList();
      final conv = conversations.firstWhere(
        (c) => c.id == _conversationId,
        orElse: () => throw Exception('对话不存在'),
      );
      _companionId = conv.companionId;

      final companion = await apiService.getCompanion(conv.companionId);
      _companionName = companion.name;
      _companionAvatarUrl = companion.avatarUrl;
      _companionPersonalities = companion.personalityKeys;
      _companionTtsConfig = companion.ttsConfig;

      // 从服务器获取最新消息
      final pageResult = await apiService.getMessages(
        _conversationId,
        page: 1,
        size: 20,
      );

      // 缓存到本地
      await localStorage.cacheMessages(_conversationId, pageResult.records);

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(pageResult.records);
          _currentPage = 1;
          _hasMore = pageResult.hasMore;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载消息失败: $e');
      if (mounted) {
        // 如果本地已有消息，不显示错误
        if (_messages.isEmpty) {
          setState(() => _isLoading = false);
          SoulToast.error(context, '加载消息失败，请检查网络');
        } else {
          SoulToast.info(context, '显示缓存消息');
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _companionId == null || _isStreaming) return;

    HapticFeedback.lightImpact();

    // 乐观插入用户消息
    final tempMessage = Message(
      id: 0,
      conversationId: _conversationId,
      senderType: 'user',
      content: content,
      createTime: DateTime.now(),
    );

    setState(() => _messages.insert(0, tempMessage));
    _messageController.clear();
    _scrollToBottom();

    // 准备空的 AI 回复占位
    final aiPlaceholder = Message(
      id: 0,
      conversationId: _conversationId,
      senderType: 'companion',
      content: '',
      createTime: DateTime.now(),
    );
    setState(() {
      _isStreaming = true;
      _isTyping = true; // 显示等待指示器
    });

    final apiService = ref.read(apiServiceProvider);
    _streamCancelToken = CancelToken();
    final buffer = StringBuffer();
    bool hasError = false;
    int chunkCount = 0;

    try {
      await for (final chatResponse in apiService.streamChat(
        SendMessageRequest(
          conversationId: _conversationId,
          companionId: _companionId!,
          content: content,
          llmProviderType: LocalStorage.llmProviderType != 'system' ? LocalStorage.llmProviderType : null,
          llmBaseUrl: LocalStorage.llmProviderType != 'system' ? LocalStorage.llmBaseUrl : null,
          llmApiKey: (LocalStorage.llmProviderType != 'system' && (LocalStorage.llmApiKey?.isNotEmpty ?? false)) ? LocalStorage.llmApiKey : null,
          llmModel: LocalStorage.llmProviderType != 'system' ? LocalStorage.llmModel : null,
        ),
        cancelToken: _streamCancelToken,
      )) {
        if (chatResponse.error != null && chatResponse.error!.isNotEmpty) {
          hasError = true;
          debugPrint('SSE收到错误: ${chatResponse.error}');
          if (mounted) {
            SoulToast.error(context, chatResponse.error!);
          }
          break;
        }

        if (chatResponse.content != null && chatResponse.content!.isNotEmpty) {
          chunkCount++;
          buffer.write(chatResponse.content);
          debugPrint('ChatPage chunk #$chunkCount: "${chatResponse.content}", bufferLen=${buffer.length}');
          
          if (mounted) {
            setState(() {
              if (_isTyping) {
                // 收到第一个 chunk，隐藏打字指示器，插入占位消息
                _isTyping = false;
                _messages.insert(0, aiPlaceholder);
              }
              // 更新占位消息的内容（index 0 = 屏幕底部）
              _messages[0] = Message(
                id: 0,
                conversationId: _conversationId,
                senderType: 'companion',
                content: buffer.toString(),
                createTime: aiPlaceholder.createTime,
              );
            });
            _scrollToBottom();
          }
        }

        if (chatResponse.done) {
          debugPrint('SSE完成: done=true, 共 $chunkCount 个有效chunk, 总长 ${buffer.length}');
          break;
        }
      }
    } catch (e) {
      debugPrint('流式消息异常: $e');
      hasError = true;
      if (mounted) {
        SoulToast.error(context, '发送失败');
      }
    }

    debugPrint('流式结束: chunkCount=$chunkCount, bufferLen=${buffer.length}, hasError=$hasError');
    
    _streamCancelToken = null;

    if (mounted) {
      setState(() {
        _isStreaming = false;
        _isTyping = false; // 确保隐藏打字指示器
      });

      // 如果没有错误且有内容，刷新消息列表获取服务端真实数据
      if (!hasError && buffer.isNotEmpty) {
        await _refreshMessages();
        // 自动触发 TTS 生成
        _autoGenerateTts(buffer.toString());
      } else if (!hasError && buffer.isEmpty) {
        // AI 没返回任何内容，确保移除可能的空占位
        debugPrint('AI未返回任何内容，移除空占位');
        setState(() {
          if (_messages.isNotEmpty && _messages[0].id == 0) {
            _messages.removeAt(0);
          }
        });
      }
    }
  }

  Future<void> _refreshMessages() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final localStorage = MessageLocalStorage.instance;

      final pageResult = await apiService.getMessages(
        _conversationId,
        page: 1,
        size: 20,
      );

      // 缓存到本地
      await localStorage.cacheMessages(_conversationId, pageResult.records);

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(pageResult.records);
          _currentPage = 1;
          _hasMore = pageResult.hasMore;
        });
      }
    } catch (e) {
      debugPrint('刷新消息失败: $e');
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final localStorage = MessageLocalStorage.instance;

      final pageResult = await apiService.getMessages(
        _conversationId,
        page: _currentPage + 1,
        size: 20,
      );

      // 缓存到本地
      await localStorage.cacheMessages(_conversationId, pageResult.records);

      if (mounted) {
        setState(() {
          _messages.addAll(pageResult.records);
          _currentPage++;
          _hasMore = pageResult.hasMore;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('加载更多消息失败: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
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

  // ==================== TTS 相关 ====================

  /// 获取有效的 TTS 配置（伴侣级优先，否则全局默认）
  TtsConfig? get _effectiveTtsConfig {
    return getEffectiveTtsConfig(_companionTtsConfig);
  }

  /// 生成消息的 TTS key
  String _messageTtsKey(Message message) {
    return '${_conversationId}_${message.id}';
  }

  /// 自动为 AI 回复生成 TTS 音频
  void _autoGenerateTts(String text) {
    if (!mounted) return;
    final config = _effectiveTtsConfig;
    if (config == null) return;

    // 找到最新的 AI 消息（refreshMessages 后 id > 0）
    final aiMessage = _messages.firstWhere(
      (m) => m.senderType == 'companion' && m.id > 0,
      orElse: () => _messages.first,
    );

    final key = _messageTtsKey(aiMessage);
    ref.read(ttsProvider.notifier).generateForMessage(
      messageKey: key,
      text: text,
      config: config,
      autoPlay: true,
    );
  }

  /// 点击喇叭：播放/暂停/重新生成
  void _onSpeakerTap(Message message) {
    if (!mounted) return;
    final key = _messageTtsKey(message);
    final entry = ref.read(ttsProvider).getMessageState(key);
    final notifier = ref.read(ttsProvider.notifier);

    switch (entry.status) {
      case MessageTtsStatus.ready:
        notifier.playMessage(key);
        break;
      case MessageTtsStatus.playing:
        notifier.togglePause(key);
        break;
      case MessageTtsStatus.paused:
        notifier.togglePause(key);
        break;
      case MessageTtsStatus.error:
      case MessageTtsStatus.none:
        // 重新生成并播放
        final config = _effectiveTtsConfig;
        if (config != null) {
          notifier.generateForMessage(
            messageKey: key,
            text: message.content,
            config: config,
            autoPlay: true,
          );
        }
        break;
      case MessageTtsStatus.generating:
        // 正在生成，不做操作
        break;
    }
  }

  /// 获取当前伴侣的 TTS 配置，用于显示
  TtsConfig? _getCompanionTtsConfig() {
    return _companionTtsConfig;
  }

  /// 获取伴侣性格主题色
  Color _getPersonalityColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final key = _companionPersonalities.isNotEmpty
        ? _companionPersonalities.first
        : 'gentle';
    final colors =
        AppColors.personalityColors[key] ?? AppColors.personalityColors['gentle']!;
    return isDark ? colors.dark : colors.light;
  }

  // ==================== UI 构建 ====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF5F5F9),
      appBar: _buildAppBar(context, isDark),
      body: _isLoading
          ? _buildLoadingState(context, isDark)
          : GestureDetector(
              onTap: () => _inputFocusNode.unfocus(),
              child: Column(
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
            ),
    );
  }

  // ==================== AppBar ====================

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
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
          _buildAppBarAvatar(context, isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _companionName ?? 'AI伴侣',
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
          onPressed: () => _showChatOptions(context, isDark),
        ),
      ],
    );
  }

  Widget _buildAppBarAvatar(BuildContext context, bool isDark) {
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
            color: AppColors.brandPink.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: _companionAvatarUrl != null && _companionAvatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: getFullUrl(ref, _companionAvatarUrl!),
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

  // ==================== 加载状态 ====================

  Widget _buildLoadingState(BuildContext context, bool isDark) {
    return Center(
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
            '加载对话中...',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 空状态 ====================

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
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
              color: AppColors.brandPink.withValues(alpha: 0.5),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.06, duration: 2500.ms, curve: Curves.easeInOut),
          const SizedBox(height: 24),
          Text(
            '开始和${_companionName ?? 'TA'}聊天吧',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '发送一条消息开启对话 💬',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 消息列表 ====================

  Widget _buildMessageList(BuildContext context, bool isDark) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
          _loadMoreMessages();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _messages.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // 加载更多指示器（在列表顶部，即 reversed 列表的末尾）
          if (index == _messages.length) {
            return _buildLoadMoreIndicator(isDark);
          }

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
      ),
    );
  }

  Widget _buildLoadMoreIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMore
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandPink.withValues(alpha: 0.6),
                ),
              )
            : Text(
                '上拉加载更多',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.3),
                ),
              ),
      ),
    );
  }

  bool _shouldShowDateSeparator(int index) {
    if (index >= _messages.length - 1) return true;
    final current = _messages[index];
    final older = _messages[index + 1];
    if (current.createTime == null || older.createTime == null) return false;
    return current.createTime!.day != older.createTime!.day ||
        current.createTime!.month != older.createTime!.month ||
        current.createTime!.year != older.createTime!.year;
  }

  // ==================== 日期分隔符 ====================

  Widget _buildDateSeparator(DateTime? dateTime, bool isDark) {
    if (dateTime == null) return const SizedBox.shrink();

    final now = DateTime.now();
    String label;
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      label = '今天';
    } else if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day - 1) {
      label = '昨天';
    } else if (now.difference(dateTime).inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      label = weekdays[dateTime.weekday - 1];
    } else {
      label = '${dateTime.month}月${dateTime.day}日';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.9, 0.9), duration: 300.ms, curve: Curves.easeOutBack),
    );
  }

  // ==================== 消息气泡 ====================

  Widget _buildMessageBubble(
    BuildContext context,
    Message message,
    bool isDark,
  ) {
    final isUser = message.senderType == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _buildMessageAvatar(context, isDark),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () {
                    HapticFeedback.heavyImpact();
                    _showMessageOptions(context, message, isDark);
                  },
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
                                : Colors.black
                                    .withValues(alpha: isDark ? 0.12 : 0.04),
                            blurRadius: isUser ? 10 : 6,
                            offset: Offset(0, isUser ? 3 : 1),
                          ),
                        ],
                      ),
                      child: _buildMessageText(
                        message, isUser, isDark,
                      ),
                    ),
                  ),
                ),

                // 情绪标签（仅AI消息）
                if (!isUser && message.emotionTag != null && message.emotionTag!.isNotEmpty)
                  _buildEmotionTag(message.emotionTag!, isDark),

                // TTS 喇叭按钮（仅AI消息，流式完成且有TTS配置时显示）
                if (!isUser && message.id > 0 && _effectiveTtsConfig != null)
                  _buildTtsButton(message, isDark),

                const SizedBox(height: 4),
                _buildMessageMeta(message, isUser, isDark),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            _buildReadStatus(message, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageAvatar(BuildContext context, bool isDark) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            _getPersonalityColor(context).withValues(alpha: 0.6),
            AppColors.brandPink.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: ClipOval(
        child: _companionAvatarUrl != null && _companionAvatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: getFullUrl(ref, _companionAvatarUrl!),
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

  /// TTS 喇叭按钮
  Widget _buildTtsButton(Message message, bool isDark) {
    final key = _messageTtsKey(message);
    // 使用 watch 实现响应式更新
    final entry = ref.watch(ttsProvider).getMessageState(key);

    // 根据状态决定图标和行为
    IconData icon;
    Color iconColor;
    bool isAnimated = false;

    switch (entry.status) {
      case MessageTtsStatus.generating:
        icon = Icons.hourglass_top_rounded;
        iconColor = AppColors.brandPink.withValues(alpha: 0.5);
        isAnimated = true;
        break;
      case MessageTtsStatus.ready:
        icon = Icons.volume_up_rounded;
        iconColor = isDark
            ? Colors.white.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.25);
        break;
      case MessageTtsStatus.playing:
        icon = Icons.volume_up_rounded;
        iconColor = AppColors.brandPink;
        isAnimated = true;
        break;
      case MessageTtsStatus.paused:
        icon = Icons.volume_off_rounded;
        iconColor = AppColors.brandPink.withValues(alpha: 0.6);
        break;
      case MessageTtsStatus.error:
        icon = Icons.refresh_rounded;
        iconColor = Colors.orange.withValues(alpha: 0.6);
        break;
      case MessageTtsStatus.none:
        icon = Icons.volume_up_rounded;
        iconColor = isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.15);
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: GestureDetector(
        onTap: () => _onSpeakerTap(message),
        child: isAnimated && entry.status == MessageTtsStatus.generating
            ? SizedBox(
                width: 28,
                height: 28,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandPink.withValues(alpha: 0.5),
                  ),
                ),
              )
            : AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: entry.status == MessageTtsStatus.playing
                      ? AppColors.brandPink.withValues(alpha: 0.1)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: isAnimated && entry.status == MessageTtsStatus.playing
                    ? _PulsingIcon(icon: icon, color: iconColor, size: 18)
                    : Icon(icon, color: iconColor, size: 18),
              ),
      ),
    );
  }

  Widget _buildMessageMeta(Message message, bool isUser, bool isDark) {
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

  Widget _buildReadStatus(Message message, bool isDark) {
    return Icon(
      message.readStatus == 1
          ? Icons.done_all_rounded
          : Icons.done_rounded,
      size: 14,
      color: message.readStatus == 1
          ? AppColors.brandPink
          : isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.2),
    );
  }

  String _cleanMessageContent(String content) {
    return content
        .replaceAll(RegExp(r'<command.*?>.*?</command>', dotAll: true), '')
        .replaceAll(RegExp(r'<command.*$', dotAll: true), '')
        .trim();
  }

  /// 构建消息文本，流式传输时带闪烁光标
  Widget _buildMessageText(Message message, bool isUser, bool isDark) {
    final isStreamingThis = _isStreaming &&
        !isUser &&
        message.id == 0;

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

    // 流式传输中：直接展示文本 + 闪烁光标
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

  // ==================== 打字指示器 ====================

  Widget _buildTypingIndicator(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          _buildMessageAvatar(context, isDark),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: _TypingDots(isDark: isDark),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 200.ms)
          .slideY(begin: 0.2, end: 0, duration: 200.ms, curve: Curves.easeOutCubic),
    );
  }

  // ==================== 输入栏 ====================

  Widget _buildInputBar(BuildContext context, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF0D0D0F) : Colors.white;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 8,
            top: 10,
            bottom: MediaQuery.of(context).padding.bottom + 10,
          ),
          decoration: BoxDecoration(
            color: surfaceColor.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 左侧：文本输入 或 语音按钮（带动画切换）
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axis: Axis.horizontal,
                        child: child,
                      ),
                    );
                  },
                  child: _isVoiceMode
                      ? _buildVoiceRecorder(isDark)
                      : _buildTextField(isDark),
                ),
              ),
              const SizedBox(width: 10),
              _buildSendButton(isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// 文本输入框
  Widget _buildTextField(bool isDark) {
    return Container(
      key: const ValueKey('textfield'),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F3F8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: _messageController,
        focusNode: _inputFocusNode,
        maxLines: 5,
        minLines: 1,
        textInputAction: TextInputAction.newline,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
        ),
        decoration: InputDecoration(
          hintText: '输入消息...',
          hintStyle: TextStyle(
            fontSize: 15,
            color: isDark
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.2),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _sendMessage(),
      ),
    );
  }

  /// 语音录制组件
  Widget _buildVoiceRecorder(bool isDark) {
    // ASR 识别中：显示加载状态
    if (_isTranscribing) {
      return Container(
        key: const ValueKey('transcribing'),
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F3F8),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandPink.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '语音识别中...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return VoiceRecorderWidget(
      key: const ValueKey('voicerecorder'),
      onSend: _onVoiceSend,
      onCancel: () {
        // 取消录音，不做任何操作
      },
    );
  }

  /// 语音发送回调：录音完成 → ASR 识别 → 发送消息
  Future<void> _onVoiceSend(String audioPath, int durationMs) async {
    if (_companionId == null || _isStreaming) return;

    setState(() => _isTranscribing = true);

    try {
      // 根据 ASR 配置选择识别服务
      final String transcribedText;

      if (LocalStorage.asrProviderType == 'custom') {
        // 自定义接入商（OpenAI Whisper API 格式）
        final asrClient = AsrApiClient();
        transcribedText = await asrClient.transcribe(audioPath);
      } else {
        // 系统默认（后端内置 ASR）
        final apiService = ref.read(apiServiceProvider);
        transcribedText = await apiService.transcribeAudio(audioPath);
      }

      if (!mounted) return;

      if (transcribedText.isEmpty) {
        SoulToast.error(context, '语音识别失败，未识别出文字');
        setState(() => _isTranscribing = false);
        return;
      }

      // 2. 将识别出的文字填入输入框，用户可编辑后发送
      _messageController.text = transcribedText;
      setState(() {
        _hasText = true;
        _isTranscribing = false;
        _isVoiceMode = false; // 切回文本模式，方便用户确认
      });
      _inputFocusNode.requestFocus();

      SoulToast.success(context, '语音识别完成');
    } on ApiException catch (e) {
      debugPrint('ASR 接口异常: $e');
      if (mounted) {
        SoulToast.error(context, e.message);
        setState(() => _isTranscribing = false);
      }
    } on Exception catch (e) {
      debugPrint('语音识别失败: $e');
      if (mounted) {
        SoulToast.error(context, '语音识别失败，请重试');
        setState(() => _isTranscribing = false);
      }
    }
  }

  Widget _buildSendButton(bool isDark) {
    // 流式传输中：显示停止按钮
    if (_isStreaming) {
      return GestureDetector(
        onTap: () {
          _streamCancelToken?.cancel('用户取消');
          _streamCancelToken = null;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F3F8),
          ),
          child: Icon(
            Icons.stop_rounded,
            size: 22,
            color: isDark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    // 有文本时：显示发送按钮
    if (_hasText) {
      return GestureDetector(
        onTap: _sendMessage,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brandPink, Color(0xFFFF8FA8)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPink.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_upward_rounded,
            size: 22,
            color: Colors.white,
          ),
        ),
      );
    }

    // 无文本时：显示麦克风/键盘切换按钮
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _isVoiceMode = !_isVoiceMode;
          if (!_isVoiceMode) {
            // 切回文本模式时，自动聚焦输入框
            _inputFocusNode.requestFocus();
          } else {
            // 切到语音模式时，取消焦点
            _inputFocusNode.unfocus();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isVoiceMode
              ? AppColors.brandPink.withValues(alpha: 0.12)
              : isDark
                  ? const Color(0xFF1C1C1E)
                  : const Color(0xFFF2F3F8),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            _isVoiceMode ? Icons.keyboard_rounded : Icons.mic_rounded,
            key: ValueKey(_isVoiceMode),
            size: 22,
            color: _isVoiceMode
                ? AppColors.brandPink
                : isDark
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }

  // ==================== 菜单 ====================

  void _showChatOptions(BuildContext context, bool isDark) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽手柄
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('伴侣详情'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (_companionId != null) {
                    context.push('/partners/detail/$_companionId');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('刷新消息'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _refreshMessages();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(
    BuildContext context,
    Message message,
    bool isDark,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('复制'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.content));
                  SoulToast.success(context, '已复制到剪贴板');
                },
              ),
              if (message.senderType == 'user')
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    '删除',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: 实现删除消息
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 打字动画组件 ====================

class _TypingDots extends StatefulWidget {
  final bool isDark;
  const _TypingDots({required this.isDark});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.15;
            final progress = ((_controller.value - delay) % 1.0)
                .clamp(0.0, 1.0);
            final bounce = (progress < 0.5)
                ? (progress * 2)
                : (2 - progress * 2);
            final scale = 0.6 + 0.4 * bounce;
            final opacity = 0.3 + 0.7 * bounce;

            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.brandPink.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ==================== 闪烁光标组件 ====================

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

// ==================== 消息气泡动画包装器 ====================

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
      begin: const Offset(0, 0.25),
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

// ==================== TTS 播放脉冲图标 ====================

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _PulsingIcon({
    required this.icon,
    required this.color,
    this.size = 18,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 持续前向循环动画来模拟声波向外扩散的效果
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        
        // 随时间推移循环切换图标，营造出“声波一级级往外扩”的动画感觉
        IconData currentIcon;
        if (val < 0.33) {
          currentIcon = Icons.volume_mute_rounded; // 仅喇叭主体
        } else if (val < 0.66) {
          currentIcon = Icons.volume_down_rounded; // 喇叭 + 一级声波
        } else {
          currentIcon = Icons.volume_up_rounded;   // 喇叭 + 二级声波
        }

        // 呼吸放大缩小的扩音动效：在动画正中间（0.5）达到最大，随后收回
        final scale = 0.92 + 0.16 * (val < 0.5 ? val * 2 : (1.0 - val) * 2);

        return Transform.scale(
          scale: scale,
          child: Icon(
            currentIcon,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}
