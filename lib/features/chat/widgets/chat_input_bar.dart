import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../voice_recorder_widget.dart';

/// 聊天底部输入栏组件 (局部监听文本框状态，隔离输入时的重建，提升打字性能)
class ChatInputBar extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode inputFocusNode;
  final bool isVoiceMode;
  final bool isTranscribing;
  final bool isStreaming;
  final VoidCallback toggleExtraMenu;
  final VoidCallback onSendMessage;
  final Future<void> Function(String audioPath, int durationMs) onVoiceSend;
  final VoidCallback onCancelStream;
  final ValueChanged<bool> onVoiceModeChanged;

  const ChatInputBar({
    required this.messageController,
    required this.inputFocusNode,
    required this.isVoiceMode,
    required this.isTranscribing,
    required this.isStreaming,
    required this.toggleExtraMenu,
    required this.onSendMessage,
    required this.onVoiceSend,
    required this.onCancelStream,
    required this.onVoiceModeChanged,
    super.key,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.messageController.text.trim().isNotEmpty;
    widget.messageController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 确保 controller 发生改变或内容同步时正确更新 _hasText
    if (oldWidget.messageController != widget.messageController) {
      oldWidget.messageController.removeListener(_onTextChanged);
      widget.messageController.addListener(_onTextChanged);
      _hasText = widget.messageController.text.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    widget.messageController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.06,
                ),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 菜单功能按钮（+ 按钮）
              _buildMenuButton(isDark),
              const SizedBox(width: 8),
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
                  child: widget.isVoiceMode
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

  Widget _buildMenuButton(bool isDark) {
    return GestureDetector(
      onTap: widget.toggleExtraMenu,
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F3F8),
        ),
        child: Icon(
          Icons.add_rounded,
          size: 24,
          color: isDark
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.black.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildTextField(bool isDark) {
    return Container(
      key: const ValueKey('textfield'),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F3F8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: widget.messageController,
        focusNode: widget.inputFocusNode,
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
        onSubmitted: (_) => widget.onSendMessage(),
      ),
    );
  }

  Widget _buildVoiceRecorder(bool isDark) {
    if (widget.isTranscribing) {
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
      onSend: widget.onVoiceSend,
      onCancel: () {
        // 取消录音，不做任何操作
      },
    );
  }

  Widget _buildSendButton(bool isDark) {
    // 流式传输中：显示停止按钮
    if (widget.isStreaming) {
      return GestureDetector(
        onTap: widget.onCancelStream,
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
        onTap: widget.onSendMessage,
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
        final newMode = !widget.isVoiceMode;
        widget.onVoiceModeChanged(newMode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isVoiceMode
              ? AppColors.brandPink.withValues(alpha: 0.12)
              : isDark
              ? const Color(0xFF1C1C1E)
              : const Color(0xFFF2F3F8),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            widget.isVoiceMode ? Icons.keyboard_rounded : Icons.mic_rounded,
            key: ValueKey(widget.isVoiceMode),
            size: 22,
            color: widget.isVoiceMode
                ? AppColors.brandPink
                : isDark
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}
