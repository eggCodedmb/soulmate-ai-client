import 'dart:async';
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
import '../../shared/models/companion.dart';
import '../../shared/models/message.dart';
import '../../shared/models/tts_config.dart';
import '../../shared/models/reminder.dart';
import '../../shared/widgets/soul_toast.dart';
import 'tts_audio_service.dart';
import 'tts_provider.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/menu_panel.dart';
import 'widgets/message_bubble.dart';

/// 聊天详情页
class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatPage({required this.conversationId, super.key});

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
  bool _isVoiceMode = false;
  bool _isTranscribing = false;
  bool _showExtraMenu = false;
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
  late final TtsNotifier _ttsNotifier;

  @override
  void initState() {
    super.initState();
    _ttsNotifier = ref.read(ttsProvider.notifier);
    _conversationId = int.parse(widget.conversationId);
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        setState(() {
          _showExtraMenu = false;
        });
      }
    });
    _loadMessages();
  }

  @override
  void dispose() {
    _streamCancelToken?.cancel('页面退出');
    _ttsNotifier.stop();
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
    final ttsSentenceBuffer = StringBuffer();
    int lastTtsSentLength = 0;
    bool hasError = false;
    int chunkCount = 0;

    final ttsConfig = _effectiveTtsConfig;

    try {
      await for (final chatResponse in apiService.streamChat(
        SendMessageRequest(
          conversationId: _conversationId,
          companionId: _companionId!,
          content: content,
          llmProviderType: LocalStorage.llmProviderType != 'system'
              ? LocalStorage.llmProviderType
              : null,
          llmBaseUrl: LocalStorage.llmProviderType != 'system'
              ? LocalStorage.llmBaseUrl
              : null,
          llmApiKey:
              (LocalStorage.llmProviderType != 'system' &&
                  (LocalStorage.llmApiKey?.isNotEmpty ?? false))
              ? LocalStorage.llmApiKey
              : null,
          llmModel: LocalStorage.llmProviderType != 'system'
              ? LocalStorage.llmModel
              : null,
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
          final chunk = chatResponse.content!;
          buffer.write(chunk);
          debugPrint(
            'ChatPage chunk #$chunkCount: "$chunk", bufferLen=${buffer.length}',
          );

          if (mounted) {
            setState(() {
              if (_isTyping) {
                _isTyping = false;
                _messages.insert(0, aiPlaceholder);
              }
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

          // TTS 流式处理逻辑
          if (ttsConfig != null) {
            ttsSentenceBuffer.write(chunk);
            final currentTtsText = ttsSentenceBuffer.toString();
            final reg = RegExp(r'[。！？!？\n\r]');
            final matches = reg.allMatches(currentTtsText).toList();

            if (matches.isNotEmpty) {
              final lastMatch = matches.last;
              final completeText = currentTtsText.substring(0, lastMatch.end);

              if (completeText.length > lastTtsSentLength) {
                final newSentence = completeText
                    .substring(lastTtsSentLength)
                    .trim();
                if (newSentence.length > 1) {
                  debugPrint('[TTS] 提取到完整句子并加入队列: "$newSentence"');
                  final messageKey = '${_conversationId}_0';
                  ref
                      .read(ttsProvider.notifier)
                      .enqueueSegment(
                        messageKey: messageKey,
                        text: newSentence,
                        config: ttsConfig,
                      );
                  lastTtsSentLength = lastMatch.end;
                }
              }
            }
          }
        }

        if (chatResponse.done) {
          debugPrint(
            'SSE完成: done=true, 共 $chunkCount 个有效chunk, 总长 ${buffer.length}',
          );
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

    debugPrint(
      '流式结束: chunkCount=$chunkCount, bufferLen=${buffer.length}, hasError=$hasError',
    );
    _streamCancelToken = null;

    if (mounted) {
      setState(() {
        _isStreaming = false;
        _isTyping = false;
      });

      if (!hasError && buffer.isNotEmpty) {
        if (ttsConfig != null && ttsSentenceBuffer.length > lastTtsSentLength) {
          final remainingText = ttsSentenceBuffer
              .toString()
              .substring(lastTtsSentLength)
              .trim();
          if (remainingText.isNotEmpty) {
            debugPrint('[TTS] 处理最后剩余段落: "$remainingText"');
            ref
                .read(ttsProvider.notifier)
                .enqueueSegment(
                  messageKey: '${_conversationId}_0',
                  text: remainingText,
                  config: ttsConfig,
                );
          }
        }

        await _refreshMessages();

        final aiMessage = _messages.firstWhere(
          (m) => m.senderType == 'companion' && m.id > 0,
          orElse: () => _messages.first,
        );
        final realKey = _messageTtsKey(aiMessage);
        final tempKey = '${_conversationId}_0';

        ref
            .read(ttsProvider.notifier)
            .associateTempKeyWithRealKey(tempKey, realKey);
        _autoGenerateTts(buffer.toString(), autoPlay: false);
      } else if (!hasError && buffer.isEmpty) {
        debugPrint('AI未返回任何内容，移除空占位');
        setState(() {
          if (_messages.isNotEmpty && _messages[0].id == 0) {
            _messages.removeAt(0);
          }
        });
      }
    }
  }

  Future<void> _deleteMessage(Message message) async {
    try {
      setState(() {
        _messages.removeWhere((m) {
          if (message.id > 0) {
            return m.id == message.id;
          } else {
            return m.id == 0 &&
                m.content == message.content &&
                m.createTime == message.createTime;
          }
        });
      });

      if (message.id > 0) {
        await ref.read(apiServiceProvider).deleteMessage(message.id);
        await MessageLocalStorage.instance.deleteMessage(message.id);
        if (mounted) {
          SoulToast.success(context, '消息已删除');
        }
      } else {
        if (mounted) {
          SoulToast.success(context, '未发送消息已清除');
        }
      }
    } catch (e) {
      debugPrint('删除消息失败: $e');
      if (mounted) {
        SoulToast.error(context, '删除消息失败: ${e.toString()}');
        _refreshMessages();
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

  TtsConfig? get _effectiveTtsConfig {
    return getEffectiveTtsConfig(_companionTtsConfig);
  }

  String _messageTtsKey(Message message) {
    return '${_conversationId}_${message.id}';
  }

  void _autoGenerateTts(String text, {bool autoPlay = true}) {
    if (!mounted) return;
    final config = _effectiveTtsConfig;
    if (config == null) return;

    final aiMessage = _messages.firstWhere(
      (m) => m.senderType == 'companion' && m.id > 0,
      orElse: () => _messages.first,
    );

    final key = _messageTtsKey(aiMessage);
    ref
        .read(ttsProvider.notifier)
        .generateForMessage(
          messageKey: key,
          text: text,
          config: config,
          autoPlay: autoPlay,
        );
  }

  Color _getPersonalityColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final key = _companionPersonalities.isNotEmpty
        ? _companionPersonalities.first
        : 'gentle';
    final colors =
        AppColors.personalityColors[key] ??
        AppColors.personalityColors['gentle']!;
    return isDark ? colors.dark : colors.light;
  }

  void _toggleExtraMenu() {
    HapticFeedback.lightImpact();
    if (_showExtraMenu) {
      setState(() {
        _showExtraMenu = false;
      });
    } else {
      final hasKeyboard = _inputFocusNode.hasFocus;
      if (hasKeyboard) {
        _inputFocusNode.unfocus();
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            setState(() {
              _showExtraMenu = true;
            });
          }
        });
      } else {
        setState(() {
          _showExtraMenu = true;
        });
      }
    }
  }

  void _startAiCall() {
    if (_companionId == null) return;

    final mockReminder = Reminder(
      id: 0,
      userId: 0,
      companionId: _companionId!,
      companionName: _companionName ?? 'AI伴侣',
      companionAvatarUrl: _companionAvatarUrl,
      reminderTime: '',
      textTemplate: '你好呀！很高兴接到你的电话，今天有什么想和我聊聊的吗？',
      type: 'AI_CALL',
    );

    context.push(
      '/call/0?outgoing=true&conversationId=$_conversationId',
      extra: mockReminder,
    );
  }

  Future<void> _onVoiceSend(String audioPath, int durationMs) async {
    if (_companionId == null || _isStreaming) return;

    setState(() => _isTranscribing = true);

    try {
      final String transcribedText;

      if (LocalStorage.asrProviderType == 'custom') {
        final asrClient = AsrApiClient();
        transcribedText = await asrClient.transcribe(audioPath);
      } else {
        final apiService = ref.read(apiServiceProvider);
        transcribedText = await apiService.transcribeAudio(audioPath);
      }

      if (!mounted) return;

      if (transcribedText.isEmpty) {
        SoulToast.error(context, '语音识别失败，未识别出文字');
        setState(() => _isTranscribing = false);
        return;
      }

      _messageController.text = transcribedText;
      setState(() {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0F)
          : const Color(0xFFF5F5F9),
      appBar: ChatAppBar(
        companionName: _companionName,
        companionAvatarUrl: _companionAvatarUrl,
        companionId: _companionId,
      ),
      body: _isLoading
          ? _buildLoadingState(context, isDark)
          : GestureDetector(
              onTap: () {
                _inputFocusNode.unfocus();
                if (_showExtraMenu) {
                  setState(() => _showExtraMenu = false);
                }
              },
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        if (_messages.isEmpty)
                          _buildEmptyState(context, isDark)
                        else
                          _buildMessageList(context, isDark),
                        if (_showExtraMenu)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showExtraMenu = false;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.0),
                                      Colors.black.withValues(alpha: 0.4),
                                    ],
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(duration: 200.ms),
                          ),
                      ],
                    ),
                  ),
                  if (_isTyping) _buildTypingIndicator(context, isDark),
                  ChatInputBar(
                    messageController: _messageController,
                    inputFocusNode: _inputFocusNode,
                    isVoiceMode: _isVoiceMode,
                    isTranscribing: _isTranscribing,
                    isStreaming: _isStreaming,
                    toggleExtraMenu: _toggleExtraMenu,
                    onSendMessage: _sendMessage,
                    onVoiceSend: _onVoiceSend,
                    onCancelStream: () {
                      _streamCancelToken?.cancel('用户取消');
                      _streamCancelToken = null;
                    },
                    onVoiceModeChanged: (val) {
                      setState(() {
                        _isVoiceMode = val;
                        if (!_isVoiceMode) {
                          _inputFocusNode.requestFocus();
                        } else {
                          _inputFocusNode.unfocus();
                        }
                      });
                    },
                  ),
                  MenuPanel(
                    showExtraMenu: _showExtraMenu,
                    onCloseMenu: () {
                      setState(() {
                        _showExtraMenu = false;
                      });
                    },
                    onStartAiCall: _startAiCall,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMessageList(BuildContext context, bool isDark) {
    final personalityColor = _getPersonalityColor(context);
    final effectiveConfig = _effectiveTtsConfig;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
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
          if (index == _messages.length) {
            return _buildLoadMoreIndicator(isDark);
          }

          final message = _messages[index];
          final showDateSeparator = _shouldShowDateSeparator(index);
          final key = _messageTtsKey(message);

          return Column(
            children: [
              if (showDateSeparator)
                _buildDateSeparator(message.createTime, isDark),
              MessageBubble(
                message: message,
                companionAvatarUrl: _companionAvatarUrl,
                personalityColor: personalityColor,
                isStreaming: _isStreaming,
                messageKey: key,
                effectiveTtsConfig: effectiveConfig,
                onLongPress: () {
                  HapticFeedback.heavyImpact();
                  _showMessageOptions(context, message, isDark);
                },
              ),
            ],
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
      child:
          Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.05,
                    ),
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
              .scale(
                begin: const Offset(0.9, 0.9),
                duration: 300.ms,
                curve: Curves.easeOutBack,
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

  Widget _buildAvatarFallback(double size) {
    return Center(
      child: Icon(
        Icons.favorite_rounded,
        size: size * 0.45,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child:
          Row(
                children: [
                  _buildMessageAvatar(context, isDark),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.12 : 0.04,
                          ),
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
              .slideY(
                begin: 0.2,
                end: 0,
                duration: 200.ms,
                curve: Curves.easeOutCubic,
              ),
    );
  }

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
              .scaleXY(
                begin: 1,
                end: 1.06,
                duration: 2500.ms,
                curve: Curves.easeInOut,
              ),
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

  void _showMessageOptions(BuildContext context, Message message, bool isDark) {
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
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.15,
                  ),
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
                    _deleteMessage(message);
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
            final progress = ((_controller.value - delay) % 1.0).clamp(
              0.0,
              1.0,
            );
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
