import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/tts_api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../shared/models/tts_config.dart';

/// TTS 音频服务 - 负责生成、缓存、播放 TTS 音频
///
/// 使用流式接口生成音频，缓存到临时目录，使用 just_audio 播放。
class TtsAudioService {
  final TtsApiClient _api;
  final AudioPlayer _player = AudioPlayer();
  late final ConcatenatingAudioSource _playlist;

  /// 音频缓存目录
  Directory? _cacheDir;

  /// 当前播放状态
  bool _isPlaying = false;
  String? _playingMessageKey;
  
  // 记录当前播放列表中已有的文件路径，避免重复添加
  final List<String> _queuedFilePaths = [];

  /// 播放状态回调
  VoidCallback? _onStateChanged;

  StreamSubscription<PlayerState>? _playerStateSubscription;

  TtsAudioService(this._api) {
    _playlist = ConcatenatingAudioSource(children: []);
    _player.setAudioSource(_playlist);

    _playerStateSubscription = _player.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      final completed = state.processingState == ProcessingState.completed;
      
      _isPlaying = state.playing && !completed;
      
      if (wasPlaying && !_isPlaying) {
        _onStateChanged?.call();
        if (completed) {
          _playingMessageKey = null;
          _queuedFilePaths.clear();
          // 注意：不要在完成时直接 stop()，因为可能还会有新的段落加入
          // 但如果确实播完了所有段落，清空播放列表
          _playlist.clear();
        }
      } else {
        _onStateChanged?.call();
      }
    });
  }

  bool get isPlaying => _isPlaying;
  String? get playingMessageKey => _playingMessageKey;
  bool get isConfigured => _api.isConfigured;

  /// 设置状态变化回调
  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  /// 初始化缓存目录
  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getTemporaryDirectory();
    _cacheDir = Directory('${appDir.path}/tts_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }

  /// 生成缓存 key（基于内容 + 声音配置的 hash）
  String _cacheKey(String text, TtsConfig config) {
    final input = '$text|${config.profileId}|${config.language}|${config.engine}';
    return md5.convert(utf8.encode(input)).toString();
  }

  /// 检查音频是否已缓存
  Future<String?> getCachedAudioPath(String text, TtsConfig config) async {
    final dir = await _getCacheDir();
    final key = _cacheKey(text, config);
    final isMimo = LocalStorage.ttsProviderType == 'mimo';
    final file = File('${dir.path}/$key.${isMimo ? 'wav' : 'mp3'}');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  /// 生成音频（使用流式接口），写入缓存文件，返回文件路径
  Future<String?> generateAndCache(String text, TtsConfig config) async {
    if (!_api.isConfigured || config.profileId == null) return null;

    final cached = await getCachedAudioPath(text, config);
    if (cached != null) return cached;

    final request = buildTtsRequest(config, text);
    final dir = await _getCacheDir();
    final key = _cacheKey(text, config);
    final isMimo = LocalStorage.ttsProviderType == 'mimo';
    final file = File('${dir.path}/$key.${isMimo ? 'wav' : 'mp3'}');
    final sink = file.openWrite();

    try {
      await for (final chunk in _api.generateStream(request)) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      return file.path;
    } catch (e) {
      await sink.close();
      if (await file.exists()) {
        await file.delete();
      }
      debugPrint('[TTS] 生成音频失败: $e');
      return null;
    }
  }

  /// 将音频加入播放队列
  Future<void> enqueue(String filePath, String messageKey) async {
    try {
      // 如果是新的消息，清空旧队列
      if (_playingMessageKey != messageKey) {
        await stop();
        _playingMessageKey = messageKey;
      }

      // 避免重复添加同一文件（针对流式分段可能的重试逻辑）
      if (_queuedFilePaths.contains(filePath)) return;

      _queuedFilePaths.add(filePath);
      await _playlist.add(AudioSource.file(filePath));

      // 如果当前没在播放，且这是第一段，开始播放
      if (!_isPlaying && _playlist.length > 0) {
        // 如果处于 completed 状态（之前播完了），需要 seek 到 0
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
        _isPlaying = true;
        _onStateChanged?.call();
      }
    } catch (e) {
      debugPrint('[TTS] 加入队列播放失败: $e');
    }
  }

  /// 播放指定文件（单文件模式，清空队列）
  Future<void> play(String filePath, String messageKey) async {
    await stop();
    _playingMessageKey = messageKey;
    await enqueue(filePath, messageKey);
  }

  /// 暂停/继续播放
  Future<void> togglePause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  /// 停止播放并清空队列
  Future<void> stop() async {
    await _player.stop();
    await _playlist.clear();
    _queuedFilePaths.clear();
    _playingMessageKey = null;
    _isPlaying = false;
    _onStateChanged?.call();
  }

  /// 释放资源
  void dispose() {
    _onStateChanged = null;
    _playerStateSubscription?.cancel();
    _player.dispose();
  }
}

/// 获取全局默认 TtsConfig（从 LocalStorage 读取）
TtsConfig? getGlobalTtsConfig() {
  final profileId = LocalStorage.ttsGlobalProfileId;
  if (profileId == null || profileId.isEmpty) return null;
  return TtsConfig(
    profileId: profileId,
    profileName: LocalStorage.ttsGlobalProfileName,
    language: LocalStorage.ttsGlobalLanguage,
    engine: LocalStorage.ttsGlobalEngine,
    enabled: true,
  );
}

/// 获取有效的 TTS 配置（伴侣优先，否则回退全局默认）
TtsConfig? getEffectiveTtsConfig(TtsConfig? companionTtsConfig) {
  if (companionTtsConfig != null &&
      companionTtsConfig.enabled &&
      companionTtsConfig.profileId != null) {
    return companionTtsConfig;
  }
  return getGlobalTtsConfig();
}
