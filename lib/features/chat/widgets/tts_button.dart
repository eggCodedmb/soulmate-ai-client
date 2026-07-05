import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/models/message.dart';
import '../../../shared/models/tts_config.dart';
import '../tts_provider.dart';

/// TTS 播放状态喇叭按钮组件 (使用 select 实现单条消息状态精准刷新)
class TtsButton extends ConsumerWidget {
  final Message message;
  final String messageKey;
  final TtsConfig? effectiveTtsConfig;

  const TtsButton({
    required this.message,
    required this.messageKey,
    super.key,
    this.effectiveTtsConfig,
  });

  void _onSpeakerTap(WidgetRef ref) {
    final entry = ref.read(ttsProvider).getMessageState(messageKey);
    final notifier = ref.read(ttsProvider.notifier);

    switch (entry.status) {
      case MessageTtsStatus.ready:
        notifier.playMessage(messageKey);
      case MessageTtsStatus.playing:
        notifier.togglePause(messageKey);
      case MessageTtsStatus.paused:
        notifier.togglePause(messageKey);
      case MessageTtsStatus.error:
      case MessageTtsStatus.none:
        if (effectiveTtsConfig != null) {
          notifier.generateForMessage(
            messageKey: messageKey,
            text: message.content,
            config: effectiveTtsConfig!,
            autoPlay: true,
          );
        }
      case MessageTtsStatus.generating:
        // 正在生成，不做操作
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 精准的 Riverpod Selector 优化，只监听当前消息对应的状态变化
    final entry = ref.watch(
      ttsProvider.select((state) => state.getMessageState(messageKey)),
    );

    final (icon, iconColor, isAnimated) = switch (entry.status) {
      MessageTtsStatus.generating => (
          Icons.hourglass_top_rounded,
          AppColors.brandPink.withValues(alpha: 0.5),
          true
        ),
      MessageTtsStatus.ready => (
          Icons.volume_up_rounded,
          isDark
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.25),
          false
        ),
      MessageTtsStatus.playing => (
          Icons.volume_up_rounded,
          AppColors.brandPink,
          true
        ),
      MessageTtsStatus.paused => (
          Icons.volume_off_rounded,
          AppColors.brandPink.withValues(alpha: 0.6),
          false
        ),
      MessageTtsStatus.error => (
          Icons.refresh_rounded,
          Colors.orange.withValues(alpha: 0.6),
          false
        ),
      MessageTtsStatus.none => (
          Icons.volume_up_rounded,
          isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.15),
          false
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: GestureDetector(
        onTap: () => _onSpeakerTap(ref),
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
                    ? _PulsingIcon(icon: icon, color: iconColor)
                    : Icon(icon, color: iconColor, size: 18),
              ),
      ),
    );
  }
}

/// TTS 播放脉冲声波动画图标
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
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

        IconData currentIcon;
        if (val < 0.33) {
          currentIcon = Icons.volume_mute_rounded;
        } else if (val < 0.66) {
          currentIcon = Icons.volume_down_rounded;
        } else {
          currentIcon = Icons.volume_up_rounded;
        }

        final scale = 0.92 + 0.16 * (val < 0.5 ? val * 2 : (1.0 - val) * 2);

        return Transform.scale(
          scale: scale,
          child: Icon(currentIcon, color: widget.color, size: 18),
        );
      },
    );
  }
}
