import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/auth/auth_page.dart';
import '../../features/home/home_page.dart';
import '../../features/chat/chat_page.dart';
import '../../features/partner/partner_manage_page.dart';
import '../../features/partner/partner_detail_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/edit_profile_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/subscription/subscription_page.dart';
import '../../features/splash/splash_page.dart';
import '../storage/secure_storage.dart';
import '../storage/local_storage.dart';
import 'main_scaffold.dart';

/// 路由配置
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      // 启动页
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      // 引导页
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      // 登录页
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthPage(),
      ),
      // 主界面（底部Tab）
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0: 首页
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          // Tab 1: 消息
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/conversations',
                builder: (context, state) => const ConversationListPage(),
                routes: [
                  GoRoute(
                    path: 'chat/:id',
                    builder: (context, state) {
                      final conversationId = state.pathParameters['id']!;
                      return ChatPage(conversationId: conversationId);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Tab 2: 伴侣
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partners',
                builder: (context, state) => const PartnerManagePage(),
                routes: [
                  GoRoute(
                    path: 'detail/:id',
                    builder: (context, state) {
                      final companionId = state.pathParameters['id']!;
                      return PartnerDetailPage(companionId: companionId);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Tab 3: 我的
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfilePage(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsPage(),
                  ),
                  GoRoute(
                    path: 'subscription',
                    builder: (context, state) => const SubscriptionPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) async {
      // 启动页不检查
      if (state.matchedLocation == '/splash') {
        return null;
      }

      // 检查是否首次启动
      if (LocalStorage.isFirstLaunch && !LocalStorage.onboardingCompleted) {
        if (state.matchedLocation != '/onboarding') {
          return '/onboarding';
        }
        return null;
      }

      // 检查登录状态
      final isLoggedIn = await SecureStorage.isLoggedIn();
      if (!isLoggedIn) {
        if (state.matchedLocation != '/auth') {
          return '/auth';
        }
        return null;
      }

      // 已登录用户访问登录/引导页时重定向到首页
      if (state.matchedLocation == '/auth' || state.matchedLocation == '/onboarding') {
        return '/home';
      }

      return null;
    },
  );
});
