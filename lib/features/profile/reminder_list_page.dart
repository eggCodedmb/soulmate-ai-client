import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/services/reminder_scheduler_service.dart';
import '../../shared/models/reminder.dart';
import '../../shared/widgets/soul_toast.dart';

class ReminderListPage extends ConsumerStatefulWidget {
  const ReminderListPage({super.key});

  @override
  ConsumerState<ReminderListPage> createState() => _ReminderListPageState();
}

class _ReminderListPageState extends ConsumerState<ReminderListPage> {
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  final Map<int, bool> _audioCachedMap = {};

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final list = await apiService.getReminderList();
      setState(() {
        _reminders = list;
      });
      // 异步检测每个提醒的语音文件缓存状态
      _checkAudioCache(list);
    } catch (e) {
      debugPrint('获取提醒列表失败: $e');
      if (mounted) {
        SoulToast.error(context, '加载失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkAudioCache(List<Reminder> list) async {
    final scheduler = ref.read(reminderSchedulerProvider);
    for (final reminder in list) {
      final cached = await scheduler.isAudioCached(reminder);
      if (mounted) {
        setState(() {
          _audioCachedMap[reminder.id] = cached;
        });
      }
    }
  }

  Future<void> _toggleEnabled(Reminder reminder, bool value) async {
    final apiService = ref.read(apiServiceProvider);
    final scheduler = ref.read(reminderSchedulerProvider);
    final prevEnabled = reminder.enabled;
    final newEnabled = value ? 1 : 0;

    // 乐观更新
    setState(() {
      final idx = _reminders.indexWhere((r) => r.id == reminder.id);
      if (idx != -1) {
        _reminders[idx] = _reminders[idx].copyWith(enabled: newEnabled);
      }
    });

    try {
      await apiService.updateReminder(reminder.id, enabled: newEnabled);
      
      // 如果启用了闹钟，触发语音包同步
      if (value) {
        await scheduler.syncAudioCache();
        _checkAudioCache(_reminders);
      }
    } catch (e) {
      // 失败回滚
      setState(() {
        final idx = _reminders.indexWhere((r) => r.id == reminder.id);
        if (idx != -1) {
          _reminders[idx] = _reminders[idx].copyWith(enabled: prevEnabled);
        }
      });
      if (mounted) {
        SoulToast.error(context, '操作失败: $e');
      }
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    final apiService = ref.read(apiServiceProvider);
    try {
      await apiService.deleteReminder(reminder.id);
      setState(() {
        _reminders.removeWhere((r) => r.id == reminder.id);
        _audioCachedMap.remove(reminder.id);
      });
      if (mounted) {
        SoulToast.success(context, '提醒已成功删除');
      }
    } catch (e) {
      if (mounted) {
        SoulToast.error(context, '删除失败: $e');
      }
    }
  }

  String _formatRepeatDays(String repeatDays) {
    if (repeatDays.isEmpty) return '仅限一次';
    final days = repeatDays.split(',');
    final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final result = days.map((d) {
      final val = int.tryParse(d);
      if (val != null && val >= 1 && val <= 7) {
        return weekdayNames[val - 1];
      }
      return '';
    }).where((element) => element.isNotEmpty).join('、');
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF5F5F9),
      appBar: AppBar(
        title: const Text('定时叫醒/通知'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 2.5,
                ),
              )
            : _reminders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.alarm_off_rounded,
                          size: 72,
                          color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无定时提醒',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '您可以让伴侣帮您设置，或手动点击下方按钮创建',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey[400],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReminders,
                    color: colorScheme.primary,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _reminders.length,
                      itemBuilder: (context, index) {
                        final reminder = _reminders[index];
                        final isCached = _audioCachedMap[reminder.id] ?? false;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Slidable(
                            key: ValueKey(reminder.id),
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              extentRatio: 0.25,
                              children: [
                                SlidableAction(
                                  onPressed: (_) {
                                    HapticFeedback.mediumImpact();
                                    _deleteReminder(reminder);
                                  },
                                  backgroundColor: const Color(0xFFFF3B30),
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_outline_rounded,
                                  label: '删除',
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(20),
                                  ),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () async {
                                    final updated = await context.push<bool>(
                                      '/profile/reminders/edit',
                                      extra: reminder,
                                    );
                                    if (updated == true) {
                                      _loadReminders();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // 伴侣头像
                                        Container(
                                          width: 54,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.brandPink.withOpacity(0.3),
                                              width: 2,
                                            ),
                                          ),
                                          child: ClipOval(
                                            child: reminder.companionAvatarUrl != null &&
                                                    reminder.companionAvatarUrl!.isNotEmpty
                                                ? Image.network(
                                                    getFullUrl(ref, reminder.companionAvatarUrl!),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                                                  )
                                                : _buildDefaultAvatar(),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // 提醒信息
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    reminder.reminderTime,
                                                    style: TextStyle(
                                                      fontSize: 28,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark ? Colors.white : Colors.black,
                                                      fontFeatures: const [FontFeature.tabularFigures()],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // 缓存状态图标
                                                  Tooltip(
                                                    message: isCached ? '语音包已下载就绪 (0延迟离线接听)' : '语音包同步中...',
                                                    child: Icon(
                                                      isCached
                                                          ? Icons.cloud_done_rounded
                                                          : Icons.cloud_download_outlined,
                                                      size: 16,
                                                      color: isCached
                                                          ? const Color(0xFF4CAF50)
                                                          : Colors.grey[400],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  // 伴侣昵称
                                                  Text(
                                                    reminder.companionName ?? '伴侣',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.brandPink,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  // 提醒类型标签
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: reminder.type == 'WAKE_UP'
                                                          ? const Color(0xFFE8F5E9)
                                                          : const Color(0xFFE3F2FD),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      reminder.type == 'WAKE_UP' ? '来电叫醒' : '日程通知',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: reminder.type == 'WAKE_UP'
                                                            ? const Color(0xFF2E7D32)
                                                            : const Color(0xFF1565C0),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _formatRepeatDays(reminder.repeatDays),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // 启用开关
                                        Switch(
                                          value: reminder.enabled == 1,
                                          activeColor: AppColors.brandPink,
                                          activeTrackColor: AppColors.brandPink.withOpacity(0.4),
                                          inactiveThumbColor: Colors.white,
                                          inactiveTrackColor: isDark
                                              ? Colors.white.withOpacity(0.12)
                                              : Colors.grey[300],
                                          onChanged: (val) {
                                            HapticFeedback.lightImpact();
                                            _toggleEnabled(reminder, val);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          HapticFeedback.lightImpact();
          final updated = await context.push<bool>('/profile/reminders/edit');
          if (updated == true) {
            _loadReminders();
          }
        },
        backgroundColor: AppColors.brandPink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.person_rounded, color: Colors.grey[400], size: 24),
    );
  }
}
