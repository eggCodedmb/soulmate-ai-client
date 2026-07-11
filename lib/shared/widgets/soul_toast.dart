import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// Toast 类型
enum SoulToastType {
  success,
  error,
  warning,
  info,
}

/// Toast 显示位置
enum SoulToastPosition {
  top,
  center,
  bottom,
}

/// 通用气泡提示组件
class SoulToast {
  SoulToast._();

  static OverlayEntry? _currentEntry;

  /// 显示 Toast
  static void show(
    BuildContext context, {
    required String message,
    SoulToastType type = SoulToastType.info,
    SoulToastPosition position = SoulToastPosition.center,
    Duration duration = const Duration(seconds: 2),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final config = _getConfig(type);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    HapticFeedback.lightImpact();

    // 移除上一条还在显示的 toast
    _currentEntry?.remove();
    _currentEntry = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        message: message,
        icon: config.icon,
        color: config.color,
        isDark: isDark,
        position: position,
        duration: duration,
        onDismissed: () {
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    Overlay.of(context).insert(entry);
  }

  /// 快捷方法
  static void success(
    BuildContext context,
    String message, {
    SoulToastPosition position = SoulToastPosition.center,
  }) {
    show(context, message: message, type: SoulToastType.success, position: position);
  }

  static void error(
    BuildContext context,
    String message, {
    SoulToastPosition position = SoulToastPosition.center,
  }) {
    show(context, message: message, type: SoulToastType.error, position: position);
  }

  static void warning(
    BuildContext context,
    String message, {
    SoulToastPosition position = SoulToastPosition.center,
  }) {
    show(context, message: message, type: SoulToastType.warning, position: position);
  }

  static void info(
    BuildContext context,
    String message, {
    SoulToastPosition position = SoulToastPosition.center,
  }) {
    show(context, message: message, type: SoulToastType.info, position: position);
  }

  static _ToastConfig _getConfig(SoulToastType type) {
    switch (type) {
      case SoulToastType.success:
        return const _ToastConfig(
          icon: Icons.check_circle_rounded,
          color: Color(0xFF34C759),
        );
      case SoulToastType.error:
        return const _ToastConfig(
          icon: Icons.error_rounded,
          color: Color(0xFFFF3B30),
        );
      case SoulToastType.warning:
        return const _ToastConfig(
          icon: Icons.warning_rounded,
          color: Color(0xFFFF9500),
        );
      case SoulToastType.info:
        return const _ToastConfig(
          icon: Icons.info_rounded,
          color: AppColors.brandLavender,
        );
    }
  }
}

class _ToastConfig {
  final IconData icon;
  final Color color;

  const _ToastConfig({required this.icon, required this.color});
}

/// 基于 Overlay 的 Toast，支持屏幕居中显示
class _ToastOverlay extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final bool isDark;
  final SoulToastPosition position;
  final Duration duration;
  final VoidCallback onDismissed;

  const _ToastOverlay({
    required this.message,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.position,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      // 停留时长 + 淡出 200ms
      duration: widget.duration + const Duration(milliseconds: 200),
      vsync: this,
    );

    // 前 duration 时间保持 1.0，最后 200ms 从 1.0 → 0.0
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismissed();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fadeOutStart =
        widget.duration.inMilliseconds / _controller.duration!.inMilliseconds;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // 前 fadeOutStart 段保持 opacity=1，之后淡出
            final opacity = _controller.value > fadeOutStart
                ? 1.0 - ((_controller.value - fadeOutStart) / (1.0 - fadeOutStart))
                : 1.0;
            // 弹入时的缩放：前 10% 从 0.85 → 1.0
            final scale = _controller.value < 0.1
                ? 0.85 + 0.15 * (_controller.value / 0.1)
                : 1.0;

            return Align(
              alignment: _getAlignment(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                ),
              ),
            );
          },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF2C2C2E).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: widget.isDark ? 0.35 : 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: widget.color.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.color, size: 18),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark
                        ? Colors.white
                        : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Alignment _getAlignment() {
    switch (widget.position) {
      case SoulToastPosition.top:
        return Alignment.topCenter;
      case SoulToastPosition.center:
        return Alignment.center;
      case SoulToastPosition.bottom:
        return Alignment.bottomCenter;
    }
  }
}
