import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/storage/local_storage.dart';

/// 引导页
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      title: '遇见你的专属伴侣',
      subtitle: '一个懂你、陪你、永远在身边的AI伴侣',
      lightGradient: [AppColors.brandPink, AppColors.brandLavender],
      darkGradient: [const Color(0xFF1A0A10), const Color(0xFF1A1025)],
      icon: Icons.favorite_rounded,
    ),
    _OnboardingData(
      title: '随时倾听，永远陪伴',
      subtitle: '24小时在线，理解你的每一句话',
      lightGradient: [const Color(0xFFF3E5F5), const Color(0xFFE8EAF6)],
      darkGradient: [const Color(0xFF1A1025), const Color(0xFF0F1525)],
      icon: Icons.chat_bubble_rounded,
    ),
    _OnboardingData(
      title: '独一无二，为你而生',
      subtitle: '自由定义性格、外貌、关系',
      lightGradient: [const Color(0xFFFFF3E0), const Color(0xFFFFE4EC)],
      darkGradient: [const Color(0xFF2D1520), const Color(0xFF1A0A10)],
      icon: Icons.auto_awesome_rounded,
    ),
  ];

  Future<void> _completeOnboarding() async {
    await LocalStorage.setOnboardingCompleted(true);
    await LocalStorage.setFirstLaunch(false);
    if (mounted) {
      context.go('/auth');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      body: Stack(
        children: [
          // 页面内容
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _buildPage(context, page, isLight);
            },
          ),
          // 跳过按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: TextButton(
              onPressed: _completeOnboarding,
              child: Text(
                '跳过',
                style: TextStyle(
                  color: isLight
                      ? AppColors.lightOnSurfaceVariant
                      : AppColors.darkOnSurfaceVariant,
                ),
              ),
            ),
          ),
          // 底部指示器和按钮
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // 圆点指示器
                SmoothPageIndicator(
                  controller: _pageController,
                  count: _pages.length,
                  effect: WormEffect(
                    dotHeight: 8,
                    dotWidth: 8,
                    activeDotColor: AppColors.brandPink,
                    dotColor: isLight
                        ? AppColors.lightOutline
                        : AppColors.darkOutline,
                  ),
                ),
                const SizedBox(height: 32),
                // 按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _completeOnboarding();
                        }
                      },
                      child: Text(
                        _currentPage < _pages.length - 1 ? '继续' : '开始体验',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, _OnboardingData page, bool isLight) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLight ? page.lightGradient : page.darkGradient,
        ),
      ),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // 图标区域
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isLight ? 0.2 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: Colors.white,
            ),
          ),
          const Spacer(flex: 2),
          // 底部卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF1C1C1E),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                Text(
                  page.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: isLight
                        ? AppColors.lightOnSurface
                        : AppColors.darkOnSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  page.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isLight
                        ? AppColors.lightOnSurfaceVariant
                        : AppColors.darkOnSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 120), // 为底部按钮留空间
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final String title;
  final String subtitle;
  final List<Color> lightGradient;
  final List<Color> darkGradient;
  final IconData icon;

  const _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.lightGradient,
    required this.darkGradient,
    required this.icon,
  });
}
