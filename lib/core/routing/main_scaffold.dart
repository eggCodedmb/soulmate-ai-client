import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'dart:io' show Platform;

/// 主界面脚手架 - 底部Tab导航
class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    // 聊天页面隐藏底部Tab栏
    final location = GoRouterState.of(context).uri.toString();
    final showBottomNav = !location.contains('/chat/');

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: showBottomNav ? _buildBottomNavBar(context) : null,
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoTabBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chat_bubble_2_fill),
            label: '消息',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.heart_circle_fill),
            label: '伴侣',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_crop_circle_fill),
            label: '我的',
          ),
        ],
      );
    }

    return NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_filled),
          label: '首页',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          selectedIcon: Icon(Icons.chat_bubble_rounded),
          label: '消息',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_outline_rounded),
          selectedIcon: Icon(Icons.favorite_rounded),
          label: '伴侣',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: '我的',
        ),
      ],
    );
  }
}
