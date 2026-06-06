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
  bottom,
}

/// 通用气泡提示组件
class SoulToast {
  SoulToast._();

  /// 显示 Toast
  static void show(
    BuildContext context, {
    required String message,
    SoulToastType type = SoulToastType.info,
    SoulToastPosition position = SoulToastPosition.top,
    Duration duration = const Duration(seconds: 2),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final config = _getConfig(type);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    HapticFeedback.lightImpact();

    final snackBar = SnackBar(
      content: _ToastContent(
        message: message,
        icon: config.icon,
        color: config.color,
        isDark: isDark,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: position == SoulToastPosition.top ? 50 : 0,
        bottom: position == SoulToastPosition.bottom ? 50 : 0,
      ),
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: config.color,
              onPressed: onAction ?? () {},
            )
          : null,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// 快捷方法
  static void success(
    BuildContext context,
    String message, {
    SoulToastPosition position = SoulToastPosition.top,
  }) {
    show(context, message: message, type: SoulToastType.success, position: position);
  }

  static void error(
    BuildContext context,
    String message, {
    SoulToastPosition position = SoulToastPosition.top,
  }) {
    show(context, message: message, type: SoulToastType.error, position: position);
  }

  static void warning(
    BuildContext context,
    String message, {
    SoulToastPosition position = SoulToastPosition.top,
  }) {
    show(context, message: message, type: SoulToastType.warning, position: position);
  }

  static void info(
    BuildContext context,
    String message, {
    SoulToastPosition position = SoulToastPosition.top,
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

class _ToastContent extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _ToastContent({
    required this.message,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
