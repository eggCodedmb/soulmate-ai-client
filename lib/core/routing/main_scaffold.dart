import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';

/// Tab 配置
class _TabConfig {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _TabConfig({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// 主界面脚手架 - 底部Tab导航
class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({
    super.key,
    required this.navigationShell,
  });

  static const List<_TabConfig> _tabs = [
    _TabConfig(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: '首页',
    ),
    _TabConfig(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: '消息',
    ),
    _TabConfig(
      icon: Icons.favorite_outline_rounded,
      activeIcon: Icons.favorite_rounded,
      label: '伴侣',
    ),
    _TabConfig(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // 子路由页面隐藏底部Tab栏（只有Tab根页面才显示）
    final segments = GoRouterState.of(context).uri.pathSegments;
    final showBottomNav = segments.length <= 1;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: showBottomNav
          ? _AnimatedBottomNavBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              tabs: _tabs,
            )
          : null,
    );
  }
}

/// 现代化动画底部导航栏
class _AnimatedBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_TabConfig> tabs;

  const _AnimatedBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? AppColors.lightSurfaceContainerHighest
            : AppColors.darkSurfaceContainerHighest,
        boxShadow: [
          // 顶部细线
          BoxShadow(
            color: (isLight ? AppColors.lightOutline : AppColors.darkOutline)
                .withOpacity(0.5),
            blurRadius: 0,
            offset: const Offset(0, -0.5),
          ),
          // 上方阴影
          BoxShadow(
            color: Colors.black.withOpacity(isLight ? 0.06 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6, left: 8, right: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (index) {
              return Expanded(
                child: _TabItem(
                  config: tabs[index],
                  isSelected: currentIndex == index,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap(index);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// 单个 Tab 项（带动画）
class _TabItem extends StatelessWidget {
  final _TabConfig config;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.config,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    const activeColor = AppColors.brandPink;
    final inactiveColor =
        isLight ? AppColors.lightOnSurfaceVariant : AppColors.darkOnSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(isLight ? 0.1 : 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标 + 动画缩放
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: child,
                  );
                },
                child: Icon(
                  isSelected ? config.activeIcon : config.icon,
                  key: ValueKey<bool>(isSelected),
                  size: 24,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // 标签 + 颜色动画
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: 0.2,
              ),
              child: Text(config.label),
            ),
            // 选中指示器小圆点
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(top: 3),
              width: isSelected ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
