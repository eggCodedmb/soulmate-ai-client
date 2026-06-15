import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_service.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/models/memory.dart';
import '../../shared/models/companion.dart';
import '../../shared/models/memory_stats.dart';
import 'memory_edit_sheet.dart';

/// 记忆管理页
class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key});

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage>
    with SingleTickerProviderStateMixin {
  List<Memory> _allMemories = [];
  List<Companion> _companions = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  int? _selectedCompanionId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;
  MemoryStats _stats = const MemoryStats(totalMemories: 0, averageImportance: 0.0, categoryCount: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final results = await Future.wait([
        apiService.getMemoryList(),
        apiService.getCompanionList(),
        apiService.getMemoryStats(companionId: _selectedCompanionId),
      ]);
      if (mounted) {
        setState(() {
          _allMemories = results[0] as List<Memory>;
          _companions = results[1] as List<Companion>;
          _stats = results[2] as MemoryStats;
        });
      }
    } on Exception catch (e) {
      debugPrint('加载记忆数据失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshData() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final results = await Future.wait([
        apiService.getMemoryList(),
        apiService.getMemoryStats(companionId: _selectedCompanionId),
      ]);
      if (mounted) {
        setState(() {
          _allMemories = results[0] as List<Memory>;
          _stats = results[1] as MemoryStats;
        });
      }
    } on Exception catch (e) {
      debugPrint('刷新记忆数据失败: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final stats = await apiService.getMemoryStats(companionId: _selectedCompanionId);
      if (mounted) {
        setState(() => _stats = stats);
      }
    } on Exception catch (e) {
      debugPrint('加载统计数据失败: $e');
    }
  }

  List<Memory> get _filteredMemories {
    var memories = _allMemories;

    // 按伴侣筛选
    if (_selectedCompanionId != null) {
      memories =
          memories.where((m) => m.companionId == _selectedCompanionId).toList();
    }

    // 按分类筛选
    if (_selectedCategory != 'all') {
      memories =
          memories.where((m) => m.category == _selectedCategory).toList();
    }

    // 按搜索关键词筛选
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      memories = memories.where((m) {
        return m.title.toLowerCase().contains(query) ||
            m.content.toLowerCase().contains(query);
      }).toList();
    }

    // 按重要度降序排列
    memories.sort((a, b) => b.importance.compareTo(a.importance));
    return memories;
  }

  String _getCompanionName(int companionId) {
    final companion = _companions.where((c) => c.id == companionId).firstOrNull;
    return companion?.name ?? '未知伴侣';
  }

  Future<void> _deleteMemory(Memory memory) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.deleteMemory(memory.id);
      setState(() {
        _allMemories.removeWhere((m) => m.id == memory.id);
      });
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记忆已删除')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  void _showDeleteConfirm(Memory memory) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('确认删除'),
        content: Text('确定要删除记忆"${memory.title}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteMemory(memory);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _onMemoryUpdated(Memory updatedMemory) {
    setState(() {
      final index = _allMemories.indexWhere((m) => m.id == updatedMemory.id);
      if (index != -1) {
        _allMemories[index] = updatedMemory;
      }
    });
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filteredMemories = _filteredMemories;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _isLoading
          ? _buildLoadingState(context)
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: AppColors.brandPink,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // 渐变头部
                  _buildSliverAppBar(context),

                  // 搜索栏
                  if (_isSearchVisible) _buildSearchBar(context),

                  // 伴侣筛选
                  if (_companions.isNotEmpty)
                    _buildCompanionFilter(context),

                  // 分类筛选标签
                  _buildCategoryFilter(context),

                  // 统计卡片
                  if (_allMemories.isNotEmpty)
                    _buildStatsCard(context),

                  // 记忆列表或空状态
                  if (filteredMemories.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(context),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final memory = filteredMemories[index];
                            return _buildMemoryCard(context, memory, index);
                          },
                          childCount: filteredMemories.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.brandPink),
          SizedBox(height: 16),
          Text('加载记忆中...'),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearchVisible ? Icons.search_off_rounded : Icons.search_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() {
              _isSearchVisible = !_isSearchVisible;
              if (!_isSearchVisible) {
                _searchQuery = '';
                _searchController.clear();
              }
            });
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1A1025),
                      const Color(0xFF0D0D0F),
                    ]
                  : [
                      AppColors.brandPink,
                      AppColors.brandLavender,
                    ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.psychology_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '记忆管理',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '管理 AI 伴侣的长期记忆',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.level1(context),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: '搜索记忆标题或内容...',
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.brandPink,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 200.ms)
              .slideY(begin: -0.1, end: 0, duration: 200.ms),
        ),
      ),
    );
  }

  Widget _buildCompanionFilter(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 54,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          children: [
            _buildCompanionChip(
              context,
              label: '全部伴侣',
              isSelected: _selectedCompanionId == null,
              onTap: () {
                if (_selectedCompanionId != null) {
                  setState(() => _selectedCompanionId = null);
                  _loadStats();
                }
              },
            ),
            ..._companions.map((companion) {
              return _buildCompanionChip(
                context,
                label: companion.name,
                isSelected: _selectedCompanionId == companion.id,
                avatarUrl: companion.avatarUrl != null && companion.avatarUrl!.isNotEmpty
                    ? getFullUrl(ref, companion.avatarUrl!)
                    : null,
                onTap: () {
                  if (_selectedCompanionId != companion.id) {
                    setState(() => _selectedCompanionId = companion.id);
                    _loadStats();
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanionChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    String? avatarUrl,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brandPink.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.brandPink
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avatarUrl != null) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.brandPink.withValues(alpha: 0.2),
                  backgroundImage: NetworkImage(avatarUrl),
                  onBackgroundImageError: (_, __) {},
                ),
                const SizedBox(width: 8),
              ] else ...[
                Icon(
                  Icons.people_rounded,
                  size: 16,
                  color:
                      isSelected ? AppColors.brandPink : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? AppColors.brandPink
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final allCategories = [
      (key: 'all', label: '全部', icon: Icons.grid_view_rounded, color: colorScheme.onSurfaceVariant),
      ...memoryCategories.map((c) => (
            key: c.key,
            label: c.label,
            icon: c.icon,
            color: c.color,
          )),
    ];

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          itemCount: allCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final cat = allCategories[index];
            final isSelected = _selectedCategory == cat.key;
            final color = cat.color;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedCategory = cat.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? color
                        : colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 16,
                      color: isSelected ? color : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isSelected ? color : colorScheme.onSurfaceVariant,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.level1(context),
          ),
          child: Row(
            children: [
              _buildStatItem(
                context,
                icon: Icons.auto_awesome_rounded,
                label: '总记忆',
                value: '${_stats.totalMemories}',
                color: AppColors.brandPink,
              ),
              _buildStatDivider(context),
              _buildStatItem(
                context,
                icon: Icons.star_rounded,
                label: '平均重要度',
                value: _stats.averageImportance.toStringAsFixed(1),
                color: AppColors.brandLavender,
              ),
              _buildStatDivider(context),
              _buildStatItem(
                context,
                icon: Icons.category_rounded,
                label: '分类数',
                value: '${_stats.categoryCount}',
                color: AppColors.brandWarmPeach,
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 300.ms).slideY(
              begin: 0.05,
              end: 0,
              delay: 200.ms,
              duration: 300.ms,
            ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }

  Widget _buildMemoryCard(BuildContext context, Memory memory, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catConfig = getCategoryConfig(memory.category);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(memory.id),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.4,
          children: [
            SlidableAction(
              onPressed: (_) {
                MemoryEditSheet.show(
                  context,
                  memory,
                  onSaved: _onMemoryUpdated,
                );
              },
              backgroundColor: AppColors.brandLavender,
              foregroundColor: Colors.white,
              icon: Icons.edit_rounded,
              label: '编辑',
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            SlidableAction(
              onPressed: (_) => _showDeleteConfirm(memory),
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              icon: Icons.delete_rounded,
              label: '删除',
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () => MemoryEditSheet.show(
            context,
            memory,
            onSaved: _onMemoryUpdated,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.level1(context),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧分类图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: catConfig.color.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    catConfig.icon,
                    color: catConfig.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // 内容区域
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题行
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              memory.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 重要度星星
                          _buildImportanceStars(memory.importance),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 内容预览
                      Text(
                        memory.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),

                      // 底部信息行
                      Row(
                        children: [
                          // 分类标签
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: catConfig.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              catConfig.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: catConfig.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 伴侣名称
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _getCompanionName(memory.companionId),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),

                          // 可见性图标
                          Icon(
                            memory.userVisible == 1
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            size: 14,
                            color: memory.userVisible == 1
                                ? AppColors.brandPink
                                : colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: 80 * index),
                duration: 300.ms,
              )
              .slideY(
                begin: 0.08,
                end: 0,
                delay: Duration(milliseconds: 80 * index),
                duration: 300.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
      ),
    );
  }

  Widget _buildImportanceStars(int importance) {
    final color = _getImportanceColor(importance);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < (importance / 2).ceil();
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: 14,
          color: filled ? color : color.withValues(alpha: 0.2),
        );
      }),
    );
  }

  Color _getImportanceColor(int importance) {
    if (importance >= 8) return const Color(0xFFFF3B30);
    if (importance >= 6) return AppColors.brandPink;
    if (importance >= 4) return const Color(0xFFFF9500);
    return const Color(0xFF8E8E93);
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.brandPink.withValues(alpha: 0.1),
                    AppColors.brandLavender.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology_outlined,
                size: 64,
                color: AppColors.brandPink.withValues(alpha: 0.5),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scaleXY(
                  begin: 1,
                  end: 1.05,
                  duration: 2000.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 24),
            Text(
              '暂无记忆',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? '没有找到匹配的记忆'
                  : 'AI 伴侣会在对话中自动积累记忆',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'all';
                    _selectedCompanionId = null;
                  });
                  _loadStats();
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('清除筛选'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
