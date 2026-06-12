import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/tts_api_client.dart';
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

  const MessageTtsEntry({
    this.status = MessageTtsStatus.none,
    this.audioPath,
    this.error,
  });

  MessageTtsEntry copyWith({
    MessageTtsStatus? status,
    String? audioPath,
    String? error,
  }) {
    return MessageTtsEntry(
      status: status ?? this.status,
      audioPath: audioPath ?? this.audioPath,
      error: error,
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

  TtsNotifier(this._api) : super(const TtsState()) {
    if (_api.isConfigured) {
      _audioService = TtsAudioService(_api);
      _audioService!.setOnStateChanged(_onAudioStateChanged);
    }
  }

  void _onAudioStateChanged() {
    if (!mounted) return;
    final svc = _audioService;
    if (svc == null) return;

    final svcKey = svc.playingMessageKey;
    final svcIsPlaying = svc.isPlaying;
    final providerPlayingKey = state.playingMessageKey;

    if (svcKey != null) {
      final entry = state.getMessageState(svcKey);
      if (svcIsPlaying) {
        // 1. 正在播放
        if (entry.status != MessageTtsStatus.playing) {
          _updateMessageState(svcKey, entry.copyWith(status: MessageTtsStatus.playing));
        }
        if (providerPlayingKey != svcKey) {
          state = state.copyWith(playingMessageKey: svcKey);
        }
      } else {
        // 2. 暂停或缓冲中 (Key 还在，但未在播放)
        if (entry.status != MessageTtsStatus.paused && entry.status != MessageTtsStatus.generating) {
          _updateMessageState(svcKey, entry.copyWith(status: MessageTtsStatus.paused));
        }
      }
    } else if (providerPlayingKey != null) {
      // 3. 彻底停止或播放结束 (svcKey 已清空)
      final entry = state.getMessageState(providerPlayingKey);
      if (entry.status == MessageTtsStatus.playing || entry.status == MessageTtsStatus.paused) {
        _updateMessageState(providerPlayingKey, entry.copyWith(status: MessageTtsStatus.ready));
      }
      state = state.copyWith(playingMessageKey: null);
    }
  }

  void _updateMessageState(String key, MessageTtsEntry entry) {
    if (!mounted) return;
    final newMap = Map<String, MessageTtsEntry>.from(state.messageStates);
    newMap[key] = entry;
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
    final svc = _audioService;
    if (svc == null || !svc.isConfigured) return;

    // 检查缓存
    final cached = await svc.getCachedAudioPath(text, config);
    if (cached != null) {
      _updateMessageState(messageKey, MessageTtsEntry(
        status: MessageTtsStatus.ready,
        audioPath: cached,
      ));
      if (autoPlay) {
        await playMessage(messageKey);
      }
      return;
    }

    // 标记正在生成
    _updateMessageState(messageKey, const MessageTtsEntry().copyWith(
      status: MessageTtsStatus.generating,
    ));

    try {
      final path = await svc.generateAndCache(text, config);
      if (path != null) {
        _updateMessageState(messageKey, MessageTtsEntry(
          status: MessageTtsStatus.ready,
          audioPath: path,
        ));
        if (autoPlay) {
          await playMessage(messageKey);
        }
      } else {
        _updateMessageState(messageKey, const MessageTtsEntry().copyWith(
          status: MessageTtsStatus.error,
          error: '生成失败',
        ));
      }
    } catch (e) {
      _updateMessageState(messageKey, const MessageTtsEntry().copyWith(
        status: MessageTtsStatus.error,
        error: e.toString(),
      ));
    }
  }

  /// 为指定消息生成并播放一段音频（流式段落支持）
  Future<void> enqueueSegment({
    required String messageKey,
    required String text,
    required TtsConfig config,
  }) async {
    final svc = _audioService;
    if (svc == null || !svc.isConfigured || text.trim().isEmpty) return;

    final currentEntry = state.getMessageState(messageKey);
    
    // 如果是第一段且尚未开始生成/播放，标记为正在生成
    if (currentEntry.status == MessageTtsStatus.none) {
      _updateMessageState(messageKey, const MessageTtsEntry().copyWith(
        status: MessageTtsStatus.generating,
      ));
    }

    try {
      final path = await svc.generateAndCache(text, config);
      if (path != null) {
        // 加入播放队列
        await svc.enqueue(path, messageKey);
        
        // 更新状态为正在播放（如果 service 还没更新状态）
        if (state.playingMessageKey != messageKey) {
          if (mounted) state = state.copyWith(playingMessageKey: messageKey);
        }
        
        // 只要有一段 ready/playing，就把整体状态设为 playing/ready
        _updateMessageState(messageKey, MessageTtsEntry(
          status: svc.isPlaying ? MessageTtsStatus.playing : MessageTtsStatus.ready,
          audioPath: path, // 记录最后一段路径（仅参考）
        ));
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

    // 如果正在播放其他消息，先停止
    if (svc.isPlaying && state.playingMessageKey != messageKey) {
      await svc.stop();
    }

    if (mounted) state = state.copyWith(playingMessageKey: messageKey);
    _updateMessageState(messageKey, entry.copyWith(
      status: MessageTtsStatus.playing,
    ));

    // 这里由于 play 是针对单文件设计的，如果消息由多段组成，
    // 点击“重新播放”目前只会播放最后一段（或缓存的全量文件）。
    // 在流式场景下，点击播放按钮通常发生在流结束后，此时可以播放全量缓存。
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
