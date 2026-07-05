import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/soul_toast.dart';

/// 聊天底部多功能菜单抽屉组件
class MenuPanel extends StatelessWidget {
  final bool showExtraMenu;
  final VoidCallback onCloseMenu;
  final VoidCallback onStartAiCall;

  const MenuPanel({
    required this.showExtraMenu,
    required this.onCloseMenu,
    required this.onStartAiCall,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelHeight = showExtraMenu ? 260.0 : 0.0;
    final backgroundColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: panelHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          if (showExtraMenu)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 8) {
            onCloseMenu();
          }
        },
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: [
                // 顶部拖动手柄
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(
                  height: 220, // 固定高度给内部 GridView 留出空间
                  child: GridView.count(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.82,
                    children: [
                      _buildPanelMenuItem(
                        context,
                        icon: Icons.image_rounded,
                        label: '相册',
                        color: const Color(0xFF34C759),
                        onTap: () {
                          SoulToast.success(context, '打开相册');
                        },
                      ),
                      _buildPanelMenuItem(
                        context,
                        icon: Icons.photo_camera_rounded,
                        label: '拍摄',
                        color: const Color(0xFF007AFF),
                        onTap: () {
                          SoulToast.success(context, '开启相机拍摄');
                        },
                      ),
                      _buildPanelMenuItem(
                        context,
                        icon: Icons.phone_in_talk_rounded,
                        label: 'AI通话',
                        color: AppColors.brandPink,
                        onTap: () {
                          onCloseMenu();
                          onStartAiCall();
                        },
                      ),
                      _buildPanelMenuItem(
                        context,
                        icon: Icons.location_on_rounded,
                        label: '位置',
                        color: const Color(0xFFFF9500),
                        onTap: () {
                          SoulToast.success(context, '获取位置信息');
                        },
                      ),
                      _buildPanelMenuItem(
                        context,
                        icon: Icons.monetization_on_rounded,
                        label: '红包',
                        color: const Color(0xFFFF3B30),
                        onTap: () {
                          SoulToast.success(context, '发送红包');
                        },
                      ),
                      _buildPanelMenuItem(
                        context,
                        icon: Icons.folder_rounded,
                        label: '文件',
                        color: const Color(0xFF5AC8FA),
                        onTap: () {
                          SoulToast.success(context, '发送文件');
                        },
                      ),
                      _buildPanelMenuItem(
                        context,
                        icon: Icons.contact_phone_rounded,
                        label: '名片',
                        color: const Color(0xFF5856D6),
                        onTap: () {
                          SoulToast.success(context, '分享名片');
                        },
                      ),
                      _buildPanelMenuItem(
                        context,
                        icon: Icons.settings_rounded,
                        label: '设置',
                        color: const Color(0xFF8E8E93),
                        onTap: () {
                          SoulToast.success(context, '应用设置');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
