import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../network/api_service.dart';
import '../network/tts_api_client.dart';
import '../storage/local_storage.dart';
import '../storage/secure_storage.dart';
import '../../shared/models/reminder.dart';
import '../../shared/models/tts_config.dart';
import '../routing/app_router.dart';

class ReminderSchedulerService {
  final ApiService _apiService;
  final TtsApiClient _ttsApiClient;

  Timer? _timer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  bool _isOnline = true; // 当前网络状态
  String? _lastCheckedTime;
  // 离线时缓存的闹钟列表，联网后自动刷新
  List<Reminder>? _cachedReminders;

  ReminderSchedulerService(this._apiService, this._ttsApiClient);

  /// 启动调度与音频同步
  void start() {
    if (_timer != null) return; // 已经启动

    debugPrint('[ReminderScheduler] 闹钟调度服务启动...');
    // 每30秒检查一次当前时间是否匹配闹钟
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkReminders());

    // 监听网络状态变化
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
      final wasOffline = !_isOnline;
      _isOnline = online;

      if (online && wasOffline) {
        debugPrint('[ReminderScheduler] 网络已恢复，刷新闹钟缓存并同步音频...');
        _refreshReminderCache();
        syncAudioCache();
      } else if (!online) {
        debugPrint('[ReminderScheduler] 网络已断开，将使用本地缓存继续调度');
      }
    });

    // 首次启动：检测网络并加载闹钟
    _initConnectivityAndCache();
  }

  /// 首次启动检测网络状态并预加载闹钟缓存
  Future<void> _initConnectivityAndCache() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _isOnline = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      _isOnline = false;
    }
    debugPrint('[ReminderScheduler] 初始网络状态: ${_isOnline ? "在线" : "离线"}');

    await _refreshReminderCache();

    if (_isOnline) {
      syncAudioCache();
    }
  }

  /// 刷新闹钟列表缓存（联网时调用）
  Future<void> _refreshReminderCache() async {
    try {
      _cachedReminders = await _apiService.getReminderList();
      debugPrint('[ReminderScheduler] 闹钟缓存已刷新，共 ${_cachedReminders?.length ?? 0} 条');
    } catch (e) {
      debugPrint('[ReminderScheduler] 刷新闹钟缓存失败: $e');
    }
  }

  /// 停止调度
  void stop() {
    _timer?.cancel();
    _timer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    debugPrint('[ReminderScheduler] 闹钟调度服务停止。');
  }

  /// 获取持久化音频缓存目录
  Future<Directory> getCacheDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${supportDir.path}/reminder_audio_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 检查特定闹钟音频文件是否已缓存
  Future<bool> isAudioCached(Reminder reminder) async {
    final cacheDir = await getCacheDir();
    final isMimo = LocalStorage.ttsProviderType == 'mimo';
    final file = File('${cacheDir.path}/reminder_${reminder.id}.${isMimo ? 'wav' : 'mp3'}');
    return await file.exists();
  }

  /// 针对单个闹钟，下载并缓存 TTS 语音包
  Future<String?> downloadAndCacheAudio(Reminder reminder) async {
    if (!_ttsApiClient.isConfigured) {
      debugPrint('[ReminderScheduler] TTS服务尚未配置');
      return null;
    }
    try {
      final companion = await _apiService.getCompanion(reminder.companionId);
      final config = companion.ttsConfig;
      if (config == null || config.profileId == null) {
        debugPrint('[ReminderScheduler] 伴侣 ${reminder.companionId} 尚未配置声音音色');
        return null;
      }

      final request = buildTtsRequest(config, reminder.textTemplate);
      final data = await _ttsApiClient.generate(request);

      final cacheDir = await getCacheDir();
      final isMimo = LocalStorage.ttsProviderType == 'mimo';
      final file = File('${cacheDir.path}/reminder_${reminder.id}.${isMimo ? 'wav' : 'mp3'}');
      await file.writeAsBytes(data);
      debugPrint('[ReminderScheduler] 定时提醒音频下载成功: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('[ReminderScheduler] 定时提醒音频下载失败, ID: ${reminder.id}, 错误: $e');
      return null;
    }
  }

  /// 全局语音包缓存对齐
  Future<void> syncAudioCache() async {
    if (_isSyncing) return;
    final isLoggedIn = await SecureStorage.isLoggedIn();
    if (!isLoggedIn) return;

    _isSyncing = true;
    try {
      final reminders = await _apiService.getReminderList();
      final enabledReminders = reminders.where((r) => r.enabled == 1).toList();
      for (final reminder in enabledReminders) {
        final cached = await isAudioCached(reminder);
        if (!cached) {
          debugPrint('[ReminderScheduler] 闹钟语音包未就绪，开始后台预下载, ID: ${reminder.id}');
          await downloadAndCacheAudio(reminder);
        }
      }
    } catch (e) {
      debugPrint('[ReminderScheduler] 全局语音包扫描同步失败: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// 定时扫描判断
  Future<void> _checkReminders() async {
    final isLoggedIn = await SecureStorage.isLoggedIn();
    if (!isLoggedIn) return;

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (timeStr == _lastCheckedTime) return;
    _lastCheckedTime = timeStr;

    // 获取闹钟列表：在线时刷新缓存，离线时使用本地缓存
    List<Reminder> reminders;
    if (_isOnline) {
      try {
        reminders = await _apiService.getReminderList();
        _cachedReminders = reminders; // 更新缓存
      } catch (e) {
        // 在线但请求失败（超时等），降级使用缓存
        debugPrint('[ReminderScheduler] 请求闹钟列表失败，使用本地缓存: $e');
        reminders = _cachedReminders ?? [];
      }
    } else {
      // 离线，使用缓存（静默，不打日志）
      reminders = _cachedReminders ?? [];
    }

    if (reminders.isEmpty) return;

    final enabledReminders = reminders.where((r) => r.enabled == 1).toList();

    for (final reminder in enabledReminders) {
      if (reminder.reminderTime == timeStr) {
        bool shouldTrigger = false;
        if (reminder.repeatDays.isEmpty) {
          // 一次性提醒，触发后将其关闭（在线时才同步服务器）
          shouldTrigger = true;
          if (_isOnline) {
            try {
              await _apiService.updateReminder(reminder.id, enabled: 0);
            } catch (e) {
              debugPrint('[ReminderScheduler] 关闭一次性提醒失败: $e');
            }
          }
        } else {
          // 重复星期，例如 "1,2,3,4,5" (1=周一, 7=周日)
          final weekday = now.weekday; // 1-7
          final days = reminder.repeatDays.split(',');
          if (days.contains(weekday.toString())) {
            shouldTrigger = true;
          }
        }

        if (shouldTrigger) {
          _triggerReminderCall(reminder);
        }
      }
    }
  }

  /// 呼叫伴侣来电
  void _triggerReminderCall(Reminder reminder) {
    debugPrint('[ReminderScheduler] 匹配成功，拉起全屏呼叫页面, 闹钟ID: ${reminder.id}');
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      GoRouter.of(context).push('/call/${reminder.id}', extra: reminder);
    } else {
      debugPrint('[ReminderScheduler] 无法拉起呼叫页面：全局 navigatorKey 对应的 context 为空');
    }
  }

  /// 引导开启悬浮窗权限 (Draw over other apps)
  Future<bool> checkAndRequestOverlayPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.systemAlertWindow.status;
    if (status.isGranted) return true;

    if (context.mounted) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('需要悬浮窗权限'),
          content: const Text('为保证伴侣能在设定的时间以电话形式唤醒您，请允许“在其他应用上层显示”（悬浮窗）权限。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );

      if (result == true) {
        final newStatus = await Permission.systemAlertWindow.request();
        return newStatus.isGranted;
      }
    }
    return false;
  }
}

/// Provider
final reminderSchedulerProvider = Provider<ReminderSchedulerService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final ttsApiClient = ref.watch(ttsApiProvider);
  return ReminderSchedulerService(apiService, ttsApiClient);
});
