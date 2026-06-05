import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';

/// 启动页
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Logo: 从 0.8 缩放至 1.0 + 淡入
    _logoScale = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4),
      ),
    );

    // 文字: 延迟 400ms 后淡入 + 上移
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.3, 0.7),
      ),
    );
    _textSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    _logoController.forward();

    // 1.5 秒后跳转
    Future.delayed(const Duration(milliseconds: 1500), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    // 检查是否首次启动
    if (LocalStorage.isFirstLaunch && !LocalStorage.onboardingCompleted) {
      context.go('/onboarding');
      return;
    }

    // 检查登录状态
    final isLoggedIn = await SecureStorage.isLoggedIn();
    if (isLoggedIn) {
      context.go('/home');
    } else {
      context.go('/auth');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isLight
                ? [AppColors.brandPink, AppColors.brandWarmPeach]
                : [const Color(0xFF1A0A10), const Color(0xFF2D1520)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 48,
                      color: isLight ? AppColors.brandPink : AppColors.brandPinkDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 品牌名称
              FadeTransition(
                opacity: _textOpacity,
                child: SlideTransition(
                  position: _textSlide,
                  child: Text(
                    'SoulMate AI',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: isLight ? Colors.white : const Color(0xFFFFB8C8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 副标题
              FadeTransition(
                opacity: _textOpacity,
                child: Text(
                  '你的专属AI伴侣',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: (isLight ? Colors.white : const Color(0xFFFFB8C8))
                        .withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
