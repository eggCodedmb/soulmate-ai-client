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

    final playingKey = svc.playingMessageKey;
    if (playingKey != null && svc.isPlaying) {
      _updateMessageState(playingKey, const MessageTtsEntry().copyWith(
        status: MessageTtsStatus.playing,
      ));
    } else if (playingKey != null && !svc.isPlaying) {
      // 播放结束
      final entry = state.getMessageState(playingKey);
      _updateMessageState(playingKey, entry.copyWith(
        status: MessageTtsStatus.ready,
      ));
      if (mounted) state = state.copyWith(playingMessageKey: null);
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
