import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/tts_api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../shared/models/tts_config.dart';
import 'tts_audio_service.dart';

/// 单条消息的 TTS 状态
enum MessageTtsStatus {
  /// 无音频（未生成）
  none,

  /// 正在生成
  generating,

  /// 已生成，待播放
  ready,

  /// 正在播放
  playing,

  /// 已暂停
  paused,

  /// 生成失败
  error,
}

/// 消息 TTS 状态条目
class MessageTtsEntry {
  final MessageTtsStatus status;
  final String? audioPath;
  final String? error;
  final String? text;

  const MessageTtsEntry({
    this.status = MessageTtsStatus.none,
    this.audioPath,
    this.error,
    this.text,
  });

  MessageTtsEntry copyWith({
    MessageTtsStatus? status,
    String? audioPath,
    String? error,
    String? text,
  }) {
    return MessageTtsEntry(
      status: status ?? this.status,
      audioPath: audioPath ?? this.audioPath,
      error: error ?? this.error,
      text: text ?? this.text,
    );
  }
}

/// TTS 全局状态
class TtsState {
  /// 各消息的 TTS 状态（key = messageKey: "conversationId_messageId"）
  final Map<String, MessageTtsEntry> messageStates;

  /// 当前播放的消息 key
  final String? playingMessageKey;

  /// 错误信息
  final String? error;

  /// 声音档案列表缓存
  final List<VoiceProfile>? profiles;

  const TtsState({
    this.messageStates = const {},
    this.playingMessageKey,
    this.error,
    this.profiles,
  });

  TtsState copyWith({
    Map<String, MessageTtsEntry>? messageStates,
    String? playingMessageKey,
    String? error,
    List<VoiceProfile>? profiles,
  }) {
    return TtsState(
      messageStates: messageStates ?? this.messageStates,
      playingMessageKey: playingMessageKey,
      error: error,
      profiles: profiles ?? this.profiles,
    );
  }

  /// 获取指定消息的 TTS 状态
  MessageTtsEntry getMessageState(String messageKey) {
    return messageStates[messageKey] ?? const MessageTtsEntry();
  }
}

/// TTS 状态管理
class TtsNotifier extends StateNotifier<TtsState> {
  final TtsApiClient _api;
  TtsAudioService? _audioService;

  /// 临时 Key 到真实 Key 的映射表，用于拦截并重定向飞在半空中的异步 TTS 合成任务
  final Map<String, String> _tempToRealKeyMap = {};

  TtsNotifier(this._api) : super(const TtsState()) {
    if (_api.isConfigured) {
      _audioService = TtsAudioService(_api);
      _audioService!.setOnStateChanged(_onAudioStateChanged);
    }
  }

  void _onAudioStateChanged() {
    // 使用 Future.microtask 延迟状态修改，避免在 widget build 期间同步修改 provider
    // （Riverpod 不允许在 widget 生命周期中同步修改 provider 状态）
    Future.microtask(() {
      if (!mounted) return;
      _syncAudioState();
    });
  }

  void _syncAudioState() {
    final svc = _audioService;
    if (svc == null) return;

    final svcKeyRaw = svc.playingMessageKey;
    final svcKey = svcKeyRaw != null
        ? (_tempToRealKeyMap[svcKeyRaw] ?? svcKeyRaw)
        : null;
    final svcIsPlaying = svc.isPlaying;
    final isCompleted = svc.processingState == ProcessingState.completed;
    final isIdle = svc.processingState == ProcessingState.idle;

    debugPrint('[TTS Provider] 状态回调: svcKeyRaw=$svcKeyRaw, svcKey=$svcKey, isPlaying=$svcIsPlaying, '
        'isCompleted=$isCompleted, isIdle=$isIdle, '
        'providerPlayingKey=${state.playingMessageKey}');

    if (svcKey != null) {
      final entry = state.getMessageState(svcKey);
      
      // 准备一个新的 messageStates Map 用于批量更新，彻底避免状态不一致和遗漏重置
      final newMap = Map<String, MessageTtsEntry>.from(state.messageStates);
      bool changed = false;

      // 1. 将其他所有处于播放/暂停状态的消息重置为 ready
      newMap.forEach((key, val) {
        if (key != svcKey && 
            (val.status == MessageTtsStatus.playing || val.status == MessageTtsStatus.paused)) {
          newMap[key] = val.copyWith(status: MessageTtsStatus.ready);
          changed = true;
        }
      });
      
      String? nextPlayingKey = state.playingMessageKey;

      if (svcIsPlaying) {
        // ✅ 正在播放
        if (entry.status != MessageTtsStatus.playing) {
          newMap[svcKey] = entry.copyWith(status: MessageTtsStatus.playing);
          changed = true;
        }
        if (nextPlayingKey != svcKey) {
          nextPlayingKey = svcKey;
        }
      } else if (isCompleted) {
        // ✅ 播放结束 — 这是最关键的分支
        debugPrint('[TTS Provider] 播放完成: $svcKey, 当前状态=${entry.status}');
        if (entry.status != MessageTtsStatus.ready) {
          newMap[svcKey] = entry.copyWith(status: MessageTtsStatus.ready);
          changed = true;
        }
        if (nextPlayingKey != null) {
          nextPlayingKey = null;
        }
      } else if (isIdle) {
        // ✅ 已停止（手动 stop）
        if (entry.status == MessageTtsStatus.playing || entry.status == MessageTtsStatus.paused) {
          newMap[svcKey] = entry.copyWith(status: MessageTtsStatus.ready);
          changed = true;
        }
        if (nextPlayingKey != null) {
          nextPlayingKey = null;
        }
      } else {
        // ✅ 暂停（手动暂停）
        if (svc.processingState == ProcessingState.ready && !svcIsPlaying) {
          if (entry.status == MessageTtsStatus.playing) {
            newMap[svcKey] = entry.copyWith(status: MessageTtsStatus.paused);
            changed = true;
          }
        }
      }

      if (changed || state.playingMessageKey != nextPlayingKey) {
        state = state.copyWith(
          messageStates: newMap,
          playingMessageKey: nextPlayingKey,
        );
      }
    } else {
      // svcKey == null → 播放器已完全清空
      final providerPlayingKey = state.playingMessageKey;
      final newMap = Map<String, MessageTtsEntry>.from(state.messageStates);
      bool changed = false;

      // 重置所有处于播放/暂停状态的消息为 ready
      newMap.forEach((key, val) {
        if (val.status == MessageTtsStatus.playing || val.status == MessageTtsStatus.paused) {
          newMap[key] = val.copyWith(status: MessageTtsStatus.ready);
          changed = true;
        }
      });

      if (changed || providerPlayingKey != null) {
        state = state.copyWith(
          messageStates: newMap,
          playingMessageKey: null,
        );
      }
    }
  }

  void _updateMessageState(String key, MessageTtsEntry entry) {
    if (!mounted) return;
    final resolvedKey = _tempToRealKeyMap[key] ?? key;
    final newMap = Map<String, MessageTtsEntry>.from(state.messageStates);
    newMap[resolvedKey] = entry;
    state = state.copyWith(messageStates: newMap);
  }

  /// 加载声音档案列表
  Future<void> loadProfiles() async {
    if (!_api.isConfigured) return;
    try {
      final profiles = await _api.getProfiles();
      if (mounted) state = state.copyWith(profiles: profiles, error: null);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
    }
  }

  /// 为指定消息生成 TTS 音频（使用流式接口）
  ///
  /// [messageKey] 消息唯一标识（conversationId_messageId）
  /// [text] 消息文本内容
  /// [config] TTS 配置（伴侣级或全局默认）
  Future<void> generateForMessage({
    required String messageKey,
    required String text,
    required TtsConfig config,
    bool autoPlay = false,
  }) async {
    final effectiveKey = _tempToRealKeyMap[messageKey] ?? messageKey;

    final svc = _audioService;
    if (svc == null || !svc.isConfigured) return;

    if (LocalStorage.ttsProviderType == 'system') {
      _updateMessageState(effectiveKey, MessageTtsEntry(
        status: MessageTtsStatus.ready,
        audioPath: 'system',
        text: text,
      ));
      if (autoPlay) {
        await svc.speakSystemTts(text, effectiveKey);
      }
      return;
    }

    final currentEntry = state.getMessageState(effectiveKey);
    if (currentEntry.status == MessageTtsStatus.ready || 
        currentEntry.status == MessageTtsStatus.playing) {
      if (autoPlay && currentEntry.status == MessageTtsStatus.ready) {
        await playMessage(effectiveKey);
      }
      return;
    }

    // 检查缓存
    final cached = await svc.getCachedAudioPath(text, config);
    if (cached != null) {
      if (autoPlay) {
        await stop();
      }
      _updateMessageState(effectiveKey, MessageTtsEntry(
        status: MessageTtsStatus.ready,
        audioPath: cached,
      ));
      if (autoPlay) {
        await playMessage(effectiveKey);
      }
      return;
    }

    if (autoPlay) {
      await stop();
    }

    _updateMessageState(effectiveKey, const MessageTtsEntry().copyWith(
      status: MessageTtsStatus.generating,
    ));

    try {
      final path = await svc.generateAndCache(text, config);
      if (path != null) {
        _updateMessageState(effectiveKey, MessageTtsEntry(
          status: MessageTtsStatus.ready,
          audioPath: path,
        ));
        if (autoPlay) {
          await playMessage(effectiveKey);
        }
      } else {
        _updateMessageState(effectiveKey, const MessageTtsEntry().copyWith(
          status: MessageTtsStatus.error,
          error: '生成失败',
        ));
      }
    } catch (e) {
      _updateMessageState(effectiveKey, const MessageTtsEntry().copyWith(
        status: MessageTtsStatus.error,
        error: e.toString(),
      ));
    }
  }

  /// 将临时消息的 TTS 状态关联并转移到真实消息 (防抖/防闪烁)
  void associateTempKeyWithRealKey(String tempKey, String realKey) {
    if (tempKey == realKey || !mounted) return;
    
    // 注册临时 Key 到真实 Key 的重定向映射
    _tempToRealKeyMap[tempKey] = realKey;
    
    final newMap = Map<String, MessageTtsEntry>.from(state.messageStates);
    final tempEntry = newMap[tempKey];
    
    if (tempEntry != null) {
      // 迁移状态实体
      newMap[realKey] = tempEntry;
      newMap.remove(tempKey);
      
      String? nextPlayingKey = state.playingMessageKey;
      if (nextPlayingKey == tempKey) {
        nextPlayingKey = realKey;
      }
      
      state = state.copyWith(
        messageStates: newMap,
        playingMessageKey: nextPlayingKey,
      );
      
      // 同步更新音频播放器关联的 key，确保其回调函数能正确将状态通知给新的真实 key
      if (_audioService != null && _audioService!.playingMessageKey == tempKey) {
        _audioService!.updatePlayingMessageKey(realKey);
      }
    }
  }

  Future<void> enqueueSegment({
    required String messageKey,
    required String text,
    required TtsConfig config,
  }) async {
    final effectiveKey = _tempToRealKeyMap[messageKey] ?? messageKey;

    final svc = _audioService;
    if (svc == null || !svc.isConfigured || text.trim().isEmpty) return;

    final currentEntry = state.getMessageState(effectiveKey);
    
    // 如果是第一段且尚未开始生成/播放，标记为正在生成
    if (currentEntry.status == MessageTtsStatus.none) {
      _updateMessageState(effectiveKey, const MessageTtsEntry().copyWith(
        status: MessageTtsStatus.generating,
      ));
    }

    try {
      final path = await svc.generateAndCache(text, config);
      if (path != null) {
        // 重新解析 Key，防止在生成音频期间临时 Key 已经被关联/替换为了真实 Key
        final finalKey = _tempToRealKeyMap[messageKey] ?? messageKey;
        await svc.enqueue(path, finalKey);
      }
    } catch (e) {
      debugPrint('[TTS] 段落生成失败: $e');
    }
  }

  /// 播放指定消息的音频
  Future<void> playMessage(String messageKey) async {
    final svc = _audioService;
    if (svc == null) return;

    final entry = state.getMessageState(messageKey);
    if (entry.audioPath == null) return;

    if (mounted) {
      final newMap = Map<String, MessageTtsEntry>.from(state.messageStates);
      
      // 1. 将其他所有处于播放/暂停状态的消息重置为 ready
      newMap.forEach((key, val) {
        if (key != messageKey && 
            (val.status == MessageTtsStatus.playing || val.status == MessageTtsStatus.paused)) {
          newMap[key] = val.copyWith(status: MessageTtsStatus.ready);
        }
      });

      // 2. 将当前要播放的消息设置为 playing
      newMap[messageKey] = entry.copyWith(status: MessageTtsStatus.playing);

      // 3. 一次性更新 state
      state = state.copyWith(
        messageStates: newMap,
        playingMessageKey: messageKey,
      );
    }

    if (LocalStorage.ttsProviderType == 'system' || entry.audioPath == 'system') {
      final msgText = entry.text;
      if (msgText != null && msgText.isNotEmpty) {
        await svc.speakSystemTts(msgText, messageKey);
      }
      return;
    }

    // svc.play() 内部 _stopSilently → 不触发回调 → 状态不会被重置
    await svc.play(entry.audioPath!, messageKey);
  }

  /// 暂停/继续播放
  Future<void> togglePause(String messageKey) async {
    final svc = _audioService;
    if (svc == null) return;

    await svc.togglePause();
  }

  /// 停止播放
  Future<void> stop() async {
    _tempToRealKeyMap.clear(); // 新回合开始或手动停止时，清除旧映射

    final svc = _audioService;
    if (svc == null) return;

    final playingKey = state.playingMessageKey;
    if (playingKey != null && mounted) {
      final entry = state.getMessageState(playingKey);
      _updateMessageState(playingKey, entry.copyWith(
        status: MessageTtsStatus.ready,
      ));
    }
    if (mounted) state = state.copyWith(playingMessageKey: null);
    await svc.stop();
  }

  /// 重新生成指定消息的音频
  Future<void> regenerateMessage({
    required String messageKey,
    required String text,
    required TtsConfig config,
  }) async {
    // 先停止当前播放
    if (_audioService?.isPlaying == true &&
        state.playingMessageKey == messageKey) {
      await _audioService?.stop();
    }

    // 清除旧状态
    _updateMessageState(messageKey, const MessageTtsEntry());

    // 重新生成
    await generateForMessage(
      messageKey: messageKey,
      text: text,
      config: config,
    );
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _audioService?.dispose();
    super.dispose();
  }
}

/// TTS 状态 Provider
final ttsProvider = StateNotifierProvider<TtsNotifier, TtsState>((ref) {
  final api = ref.watch(ttsApiProvider);
  return TtsNotifier(api);
});

/// 声音档案列表 Provider
final voiceProfilesProvider = FutureProvider<List<VoiceProfile>>((ref) async {
  final api = ref.watch(ttsApiProvider);
  if (!api.isConfigured) return [];
  return api.getProfiles();
});
