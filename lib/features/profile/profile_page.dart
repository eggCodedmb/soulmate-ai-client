import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/models/user.dart';

/// 个人中心页
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final user = await apiService.getUserInfo();
      setState(() {
        _user = user;
      });
    } catch (e) {
      debugPrint('加载用户信息失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/profile/settings'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserInfo,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 用户信息卡片
                  _buildUserCard(context),
                  const SizedBox(height: 16),
                  // 数据概览
                  _buildDataOverview(context),
                  const SizedBox(height: 16),
                  // 会员升级
                  _buildUpgradeCard(context),
                  const SizedBox(height: 16),
                  // 功能菜单
                  _buildMenuSection(context),
                ],
              ),
            ),
    );
  }

  Widget _buildUserCard(BuildContext context) {
    final nickname = _user?.nickname ?? '未设置昵称';
    final userId = _user?.id ?? 0;
    final isGuest = _user?.guestFlag == 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.level1(context),
      ),
      child: Row(
        children: [
          // 头像
          _buildAvatar(context),
          const SizedBox(width: 16),
          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: $userId',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGuest
                        ? AppColors.brandWarmPeach.withOpacity(0.1)
                        : AppColors.brandPink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isGuest ? '游客账号' : '免费版',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isGuest ? AppColors.brandWarmPeach : AppColors.brandPink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 编辑按钮
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () async {
              final updated = await context.push<bool>('/profile/edit');
              if (updated == true) {
                _loadUserInfo();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final avatarUrl = _user?.avatarUrl;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                getFullUrl(ref, avatarUrl),
                fit: BoxFit.cover,
                width: 64,
                height: 64,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          : Icon(
              Icons.person_rounded,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
    );
  }

  Widget _buildDataOverview(BuildContext context) {
    // 计算陪伴天数
    final createTime = _user?.createTime;
    final days = createTime != null
        ? DateTime.now().difference(createTime).inDays
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.level1(context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDataItem(context, '已陪伴', '$days', '天'),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          _buildDataItem(context, '共对话', '--', '条'),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          _buildDataItem(context, '记忆', '--', '条'),
        ],
      ),
    );
  }

  Widget _buildDataItem(BuildContext context, String label, String value, String unit) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                unit,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandPink, AppColors.brandLavender],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.level2(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✨ 升级会员',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '解锁无限对话',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push('/profile/subscription'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.brandPink,
            ),
            child: const Text('立即升级'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.level1(context),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            icon: Icons.psychology_outlined,
            title: '记忆管理',
            onTap: () {
              context.push('/profile/memories');
            },
          ),
          _buildDivider(context),
          _buildMenuItem(
            context,
            icon: Icons.mood_outlined,
            title: '情绪日记',
            onTap: () {
              // TODO: 跳转到情绪日记页
            },
          ),
          _buildDivider(context),
          _buildMenuItem(
            context,
            icon: Icons.workspace_premium_outlined,
            title: '订阅会员',
            onTap: () => context.push('/profile/subscription'),
          ),
          _buildDivider(context),
          _buildMenuItem(
            context,
            icon: Icons.info_outline,
            title: '关于我们',
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
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
    );
  }
}
