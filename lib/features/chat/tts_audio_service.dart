import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/tts_api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../shared/models/tts_config.dart';

/// 播放器状态枚举，保持与 just_audio 相同的名称以兼容调用方
enum ProcessingState {
  idle,
  loading,
  buffering,
  ready,
  completed,
}

/// TTS 音频服务 - 负责生成、缓存、播放 TTS 音频
///
/// 使用流式接口生成音频，缓存到临时目录，使用 flutter_sound 播放。
class TtsAudioService {
  final TtsApiClient _api;
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  /// 音频缓存目录
  Directory? _cacheDir;

  /// 当前播放状态
  bool _isPlaying = false;
  String? _playingMessageKey;
  ProcessingState _processingState = ProcessingState.idle;
  
  // 自定义顺序播放队列
  final List<String> _playlist = [];

  /// 播放状态回调
  VoidCallback? _onStateChanged;

  TtsAudioService(this._api) {
    _player.openPlayer().then((_) {
      debugPrint('[TTS] FlutterSoundPlayer opened successfully');
    }).catchError((e) {
      debugPrint('[TTS] Failed to open FlutterSoundPlayer: $e');
    });
  }

  bool get isPlaying => _isPlaying;
  String? get playingMessageKey => _playingMessageKey;
  bool get isConfigured => _api.isConfigured;
  ProcessingState get processingState => _processingState;

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

      // 避免重复添加同一文件
      if (_playlist.contains(filePath)) return;

      _playlist.add(filePath);

      // 如果当前没在播放，开始播放
      if (!_isPlaying) {
        _isPlaying = true;
        _processingState = ProcessingState.ready;
        _onStateChanged?.call();
        await _playNext();
      }
    } catch (e) {
      debugPrint('[TTS] 加入队列播放失败: $e');
    }
  }

  /// 顺序播放队列中的下一个音频
  Future<void> _playNext() async {
    if (_playlist.isEmpty) {
      _isPlaying = false;
      _processingState = ProcessingState.completed;
      _onStateChanged?.call();
      return;
    }

    final currentFile = _playlist.first;
    try {
      await _player.startPlayer(
        fromURI: currentFile,
        whenFinished: () async {
          if (_playlist.isNotEmpty) {
            _playlist.removeAt(0);
          }
          await _playNext();
        },
      );
    } catch (e) {
      debugPrint('[TTS] 顺序播放单个文件失败: $e');
      // 播放失败则跳过该文件继续播放下一个
      if (_playlist.isNotEmpty) {
        _playlist.removeAt(0);
      }
      await _playNext();
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
    if (_player.isPlaying) {
      await _player.pausePlayer();
      _isPlaying = false;
      _processingState = ProcessingState.ready;
      _onStateChanged?.call();
    } else if (_player.isPaused) {
      await _player.resumePlayer();
      _isPlaying = true;
      _processingState = ProcessingState.ready;
      _onStateChanged?.call();
    }
  }

  /// 停止播放并清空队列
  Future<void> stop() async {
    try {
      await _player.stopPlayer();
    } catch (_) {}
    _playlist.clear();
    _playingMessageKey = null;
    _isPlaying = false;
    _processingState = ProcessingState.idle;
    _onStateChanged?.call();
  }

  /// 释放资源
  void dispose() {
    _onStateChanged = null;
    try {
      _player.closePlayer();
    } catch (_) {}
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
