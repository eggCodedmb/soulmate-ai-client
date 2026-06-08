import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../shared/models/user.dart';
import '../../shared/models/subscription.dart';
import '../../shared/widgets/membership_badge.dart';
import '../../shared/widgets/membership_card.dart';

/// 个人中心页
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with TickerProviderStateMixin {
  User? _user;
  List<SubscriptionPlan> _plans = [];
  UserSubscription? _currentSubscription;
  bool _isLoading = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final results = await Future.wait([
        apiService.getUserInfo(),
        apiService.getSubscriptionPlans(),
        apiService.getCurrentSubscription(),
      ]);
      if (mounted) {
        setState(() {
          _user = results[0] as User;
          _plans = results[1] as List<SubscriptionPlan>;
          _currentSubscription = results[2] as UserSubscription?;
        });
      }
    } catch (e) {
      debugPrint('加载数据失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF5F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            _buildAppBar(context, isDark),
            // 主内容
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: RefreshIndicator(
                          onRefresh: _loadData,
                          color: colorScheme.primary,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            children: [
                              // 用户信息卡片
                              _buildUserCard(context, isDark),
                              const SizedBox(height: 24),
                              // 会员升级
                              _buildUpgradeCard(context),
                              const SizedBox(height: 24),
                              // 功能菜单
                              _buildMenuSection(context, isDark),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部导航栏
  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Spacer(),
          Text(
            '我的',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? Colors.white : Colors.black,
              size: 24,
            ),
            onPressed: () => context.push('/profile/settings'),
          ),
        ],
      ),
    );
  }

  /// 用户信息卡片
  Widget _buildUserCard(BuildContext context, bool isDark) {
    final nickname = _user?.nickname ?? '未设置昵称';
    final userId = _user?.id ?? 0;
    final isGuest = _user?.guestFlag == 1;
    final avatarUrl = _user?.avatarUrl;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: Colors.white.withOpacity(0.15), width: 1)
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 头像
              _buildAvatar(context, avatarUrl, isDark),
              const SizedBox(width: 20),
              // 用户信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ID: $userId',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isGuest)
                      _buildStatusBadge(
                        '游客账号',
                        Icons.person_outline_rounded,
                        Colors.orange,
                        isDark,
                      )
                    else if (_currentSubscription != null)
                      _buildMemberBadgeFromSubscription()
                    else
                      _buildStatusBadge(
                        '免费版',
                        Icons.workspace_premium_outlined,
                        AppColors.brandPink,
                        isDark,
                      ),
                  ],
                ),
              ),
              // 编辑按钮
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: isDark
                      ? Border.all(color: Colors.white.withOpacity(0.15))
                      : null,
                ),
                child: GestureDetector(
                  onTap: () async {
                    final updated =
                        await context.push<bool>('/profile/edit');
                    if (updated == true) {
                      _loadData();
                    }
                  },
                  child: Icon(
                    Icons.edit_outlined,
                    color: isDark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey[600],
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 状态标签
  Widget _buildStatusBadge(
      String text, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.3 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 会员标签
  Widget _buildMemberBadgeFromSubscription() {
    SubscriptionPlan? plan;
    if (_currentSubscription != null) {
      plan = _plans
          .where((p) => p.id == _currentSubscription!.planId)
          .firstOrNull;
    }
    if (plan == null) return const SizedBox.shrink();
    return MembershipBadge.fromPlanCode(planCode: plan.planCode, compact: true);
  }

  /// 头像
  Widget _buildAvatar(BuildContext context, String? avatarUrl, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withOpacity(0.1) : colorScheme.primaryContainer,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? Image.network(
                getFullUrl(ref, avatarUrl),
                fit: BoxFit.cover,
                width: 80,
                height: 80,
                errorBuilder: (_, __, ___) => _buildDefaultAvatar(isDark, colorScheme),
              )
            : _buildDefaultAvatar(isDark, colorScheme),
      ),
    );
  }

  Widget _buildDefaultAvatar(bool isDark, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : colorScheme.primaryContainer,
      ),
      child: Icon(
        Icons.person_rounded,
        size: 40,
        color: isDark ? Colors.white.withOpacity(0.8) : colorScheme.primary,
      ),
    );
  }

  /// 会员升级卡片
  Widget _buildUpgradeCard(BuildContext context) {
    // 找到当前套餐
    SubscriptionPlan? currentPlan;
    if (_currentSubscription != null) {
      currentPlan = _plans
          .where((p) => p.id == _currentSubscription!.planId)
          .firstOrNull;
    }

    if (currentPlan == null) {
      return MembershipCard.free(
        onTap: () => context.push('/profile/subscription'),
      );
    }

    return MembershipCard.member(
      plan: currentPlan,
      subscription: _currentSubscription!,
      onTap: () => context.push('/profile/subscription'),
    );
  }

  /// 功能菜单
  Widget _buildMenuSection(BuildContext context, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: Colors.white.withOpacity(0.15), width: 1)
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            icon: Icons.psychology_outlined,
            iconColor: const Color(0xFF9C27B0),
            title: '记忆管理',
            subtitle: '查看和管理AI记忆',
            isDark: isDark,
            onTap: () => context.push('/profile/memories'),
          ),
          _buildDivider(context, isDark),
          _buildMenuItem(
            context,
            icon: Icons.mood_outlined,
            iconColor: const Color(0xFFFF9800),
            title: '情绪日记',
            subtitle: '记录你的心情故事',
            isDark: isDark,
            onTap: () {
              // TODO: 跳转到情绪日记页
            },
          ),
          _buildDivider(context, isDark),
          _buildMenuItem(
            context,
            icon: Icons.alarm_rounded,
            iconColor: const Color(0xFF4CAF50),
            title: '定时叫醒/通知',
            subtitle: '伴侣来电唤醒与日程提醒',
            isDark: isDark,
            onTap: () => context.push('/profile/reminders'),
          ),
          _buildDivider(context, isDark),
          _buildMenuItem(
            context,
            icon: Icons.workspace_premium_outlined,
            iconColor: const Color(0xFFFFD700),
            title: '订阅会员',
            subtitle: '解锁全部高级功能',
            isDark: isDark,
            onTap: () => context.push('/profile/subscription'),
          ),
          _buildDivider(context, isDark),
          _buildMenuItem(
            context,
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF2196F3),
            title: '关于我们',
            subtitle: '了解SoulMate AI',
            isDark: isDark,
            onTap: () {
              // TODO: 跳转到关于页
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              // 文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // 箭头
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDark
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context, bool isDark) {
    return Divider(
      height: 1,
      indent: 68,
      endIndent: 20,
      color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.2),
    );
  }
}
