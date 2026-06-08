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

  /// 音频缓存目录
  Directory? _cacheDir;

  /// 当前播放状态
  bool _isPlaying = false;
  String? _playingMessageKey;

  /// 播放状态回调
  VoidCallback? _onStateChanged;

  TtsAudioService(this._api) {
    _player.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      final completed = state.processingState == ProcessingState.completed;
      // 在 just_audio 中，当自然播放完成时，state.playing 依然可能为 true。
      // 因此我们需要结合 completed 状态来判断真实的播放状态。
      _isPlaying = state.playing && !completed;
      
      if (wasPlaying && !_isPlaying) {
        // 播放结束或暂停 —— 先回调通知（此时 playingMessageKey 仍可用）
        _onStateChanged?.call();
        // 回调完成后再清除 key
        if (completed) {
          _playingMessageKey = null;
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
  ///
  /// 如果已缓存则直接返回缓存路径。
  Future<String?> generateAndCache(String text, TtsConfig config) async {
    if (!_api.isConfigured || config.profileId == null) return null;

    // 检查缓存
    final cached = await getCachedAudioPath(text, config);
    if (cached != null) return cached;

    // 使用流式接口生成
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
      // 清理不完整文件
      if (await file.exists()) {
        await file.delete();
      }
      debugPrint('[TTS] 生成音频失败: $e');
      return null;
    }
  }

  /// 播放指定文件
  Future<void> play(String filePath, String messageKey) async {
    try {
      await _player.setFilePath(filePath);
      // 强制将播放位置重置到起点，以解决在 just_audio 中重复播放相同文件失效的问题
      await _player.seek(Duration.zero);
      _playingMessageKey = messageKey;
      _isPlaying = true;
      _onStateChanged?.call();
      await _player.play();
    } catch (e) {
      debugPrint('[TTS] 播放失败: $e');
      _playingMessageKey = null;
      _isPlaying = false;
      _onStateChanged?.call();
    }
  }

  /// 暂停/继续播放
  Future<void> togglePause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  /// 停止播放
  Future<void> stop() async {
    await _player.stop();
    _playingMessageKey = null;
    _isPlaying = false;
    _onStateChanged?.call();
  }

  /// 释放资源
  void dispose() {
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
