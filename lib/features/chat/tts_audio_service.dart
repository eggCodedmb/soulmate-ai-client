import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/tts_api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../shared/models/tts_config.dart';

/// 播放器状态枚举，保持与 just_audio 相同的名称以兼容调用方
enum ProcessingState { idle, loading, buffering, ready, completed }

/// TTS 音频服务 - 负责生成、缓存、播放 TTS 音频
///
/// 使用流式接口生成音频，缓存到临时目录，使用 flutter_sound 播放。
class TtsAudioService {
  final TtsApiClient _api;
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final FlutterTts _flutterTts = FlutterTts();

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

  /// 进度订阅，用于检测播放结束
  StreamSubscription<PlaybackDisposition>? _progressSubscription;

  /// 安全回退定时器：当 whenFinished 不触发时，用 onProgress 检测播放结束
  Timer? _completionGuardTimer;

  /// 标记当前播放文件是否已通过 whenFinished 正常完成
  bool _whenFinishedFired = false;

  TtsAudioService(this._api) {
    _player
        .openPlayer()
        .then((_) {
          debugPrint('[TTS] FlutterSoundPlayer opened successfully');
          // 启用进度订阅，用于安全回退检测
          _player.setSubscriptionDuration(const Duration(milliseconds: 200));
          _progressSubscription = _player.onProgress?.listen(_onProgress);
        })
        .catchError((e) {
          debugPrint('[TTS] Failed to open FlutterSoundPlayer: $e');
        });

    _flutterTts.setCompletionHandler(() {
      debugPrint('[TTS] 手机系统 Native TTS 播放完成');
      _isPlaying = false;
      _processingState = ProcessingState.completed;
      _notifyStateChanged();
    });
    _flutterTts.setCancelHandler(() {
      _isPlaying = false;
      _processingState = ProcessingState.idle;
      _notifyStateChanged();
    });
    _flutterTts.setErrorHandler((msg) {
      debugPrint('[TTS] 手机系统 Native TTS 发生错误: $msg');
      _isPlaying = false;
      _processingState = ProcessingState.idle;
      _notifyStateChanged();
    });
  }

  bool get isPlaying => _isPlaying;
  String? get playingMessageKey => _playingMessageKey;
  bool get isConfigured => _api.isConfigured;
  ProcessingState get processingState => _processingState;

  /// 设置状态变化回调
  // ignore: use_setters_to_change_properties
  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  /// 动态更新当前播放消息的 key，用于流式临时 key (id=0) 与真实 key (id>0) 的无缝过渡
  // ignore: use_setters_to_change_properties
  void updatePlayingMessageKey(String newKey) {
    _playingMessageKey = newKey;
  }

  /// 进度回调 - 用作 whenFinished 的安全回退
  void _onProgress(PlaybackDisposition disposition) {
    // 当播放器实际已停止但 whenFinished 没触发时，通过 onProgress 检测
    if (!_isPlaying || _playlist.isEmpty) return;

    // 检查播放器是否真的已经停了（position 不再变化且接近 duration）
    if (disposition.duration.inMilliseconds > 0 &&
        disposition.position.inMilliseconds > 0 &&
        disposition.position >=
            disposition.duration - const Duration(milliseconds: 100)) {
      // 启动一个短延时守卫：如果 200ms 内 whenFinished 没触发，手动推进
      _completionGuardTimer?.cancel();
      _completionGuardTimer = Timer(const Duration(milliseconds: 300), () {
        if (!_whenFinishedFired && _isPlaying && _playlist.isNotEmpty) {
          debugPrint('[TTS] 安全回退：whenFinished 未触发，手动推进到下一段');
          _advancePlaylist();
        }
      });
    }
  }

  /// 推进播放列表（从 whenFinished 或安全回退调用）
  Future<void> _advancePlaylist() async {
    _completionGuardTimer?.cancel();
    if (_playlist.isNotEmpty) {
      _playlist.removeAt(0);
    }
    await _playNext();
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
    final input =
        '$text|${config.profileId}|${config.language}|${config.engine}';
    return md5.convert(utf8.encode(input)).toString();
  }

  /// 检查音频是否已缓存
  Future<String?> getCachedAudioPath(String text, TtsConfig config) async {
    final dir = await _getCacheDir();
    final key = _cacheKey(text, config);
    // 同时检查 .wav 和 .mp3 以支持动态检测出的不同音频格式
    final wavFile = File('${dir.path}/$key.wav');

    if (await wavFile.exists() && await wavFile.length() > 200) {
      return wavFile.path;
    }
    final mp3File = File('${dir.path}/$key.mp3');
    if (await mp3File.exists() && await mp3File.length() > 200) {
      return mp3File.path;
    }
    return null;
  }

  /// 检测音频文件是否为 WAV 格式（检查 RIFF 与 WAVE 文件头）
  Future<bool> _isWavFile(File file) async {
    try {
      if (!await file.exists()) return false;
      final length = await file.length();
      if (length < 12) return false;

      final raf = await file.open(mode: FileMode.read);
      final header = await raf.read(12);
      await raf.close();

      if (header.length >= 12 &&
          header[0] == 0x52 &&
          header[1] == 0x49 &&
          header[2] == 0x46 &&
          header[3] == 0x46 && // RIFF
          header[8] == 0x57 &&
          header[9] == 0x41 &&
          header[10] == 0x56 &&
          header[11] == 0x45) {
        // WAVE
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// 生成音频（使用流式接口），写入缓存文件，返回文件路径
  Future<String?> generateAndCache(String text, TtsConfig config) async {
    if (!_api.isConfigured || config.profileId == null) return null;

    final cached = await getCachedAudioPath(text, config);
    if (cached != null) return cached;

    final request = buildTtsRequest(config, text);
    final dir = await _getCacheDir();
    final key = _cacheKey(text, config);

    // 先写入临时文件，生成完毕后再通过文件头特征重命名为正确后缀名，解决编码与后缀不一致引发的播放失败问题
    final tempFile = File('${dir.path}/$key.tmp');
    if (await tempFile.exists()) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }

    final sink = tempFile.openWrite();

    try {
      await for (final chunk in _api.generateStream(request)) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();

      final length = await tempFile.length();
      if (length < 200) {
        debugPrint('[TTS] 生成的音频文件过小 ($length 字节)，可能为无效或错误响应，进行删除');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        return null;
      }

      // 动态分析实际音频格式
      final isWav = await _isWavFile(tempFile);
      final finalFile = File('${dir.path}/$key.${isWav ? 'wav' : 'mp3'}');

      if (await finalFile.exists()) {
        try {
          await finalFile.delete();
        } catch (_) {}
      }

      await tempFile.rename(finalFile.path);
      return finalFile.path;
    } catch (e) {
      await sink.close();
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      debugPrint('[TTS] 生成音频失败: $e');
      return null;
    }
  }

  /// 将音频加入播放队列
  Future<void> enqueue(String filePath, String messageKey) async {
    try {
      // 如果是新的消息，清空旧队列
      if (_playingMessageKey != null && _playingMessageKey != messageKey) {
        await stop();
      }

      _playingMessageKey = messageKey;

      // 避免重复添加同一文件
      if (_playlist.contains(filePath)) return;

      _playlist.add(filePath);

      // 如果当前没在播放，开始播放
      if (!_isPlaying) {
        _isPlaying = true;
        _processingState = ProcessingState.ready;
        _notifyStateChanged();
        await _playNext();
      }
    } catch (e) {
      debugPrint('[TTS] 加入队列播放失败: $e');
    }
  }

  /// 顺序播放队列中的下一个音频
  Future<void> _playNext() async {
    if (_playlist.isEmpty) {
      // 播放队列清空 → 完成
      _isPlaying = false;
      _processingState = ProcessingState.completed;
      // 保留 _playingMessageKey 不清空，让 provider 读取后决定如何处理
      _notifyStateChanged();

      // 延迟清空 _playingMessageKey，给 provider 足够时间读取
      Future.microtask(() {
        if (_processingState == ProcessingState.completed && !_isPlaying) {
          _playingMessageKey = null;
        }
      });
      return;
    }

    final currentFile = _playlist.first;
    _whenFinishedFired = false;

    try {
      final isWav = currentFile.endsWith('.wav');
      await _player.startPlayer(
        fromURI: currentFile,
        codec: isWav ? Codec.pcm16WAV : Codec.mp3,
        whenFinished: () async {
          _whenFinishedFired = true;
          _completionGuardTimer?.cancel();
          debugPrint('[TTS] whenFinished 正常触发');
          await _advancePlaylist();
        },
      );
      _isPlaying = true;
      _processingState = ProcessingState.ready;
      _notifyStateChanged();
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
  /// 注意：使用 _stopSilently 而非 stop，避免触发回调导致 provider 层状态竞态
  Future<void> play(String filePath, String messageKey) async {
    await _stopSilently();
    _playingMessageKey = messageKey;
    await enqueue(filePath, messageKey);
  }

  /// 暂停/继续播放
  Future<void> togglePause() async {
    if (_isPlaying) {
      await _player.pausePlayer();
      _isPlaying = false;
      _processingState = ProcessingState.ready;
      _notifyStateChanged();
    } else {
      await _player.resumePlayer();
      _isPlaying = true;
      _processingState = ProcessingState.ready;
      _notifyStateChanged();
    }
  }

  bool _ttsInitialized = false;

  /// 初始化 Native 系统 TTS 配置
  Future<void> _initFlutterTts() async {
    if (_ttsInitialized) return;
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _ttsInitialized = true;
    } catch (e) {
      debugPrint('[TTS] 初始化 Native TTS 警告: $e');
    }
  }

  /// 使用设备原生手机系统 TTS 朗读文本（离线）
  Future<void> speakSystemTts(String text, String messageKey) async {
    await _stopSilently();
    _playingMessageKey = messageKey;
    _isPlaying = true;
    _processingState = ProcessingState.ready;
    _notifyStateChanged();

    try {
      await _initFlutterTts();

      try {
        await _flutterTts.setLanguage('zh-CN');
      } catch (_) {
        try {
          await _flutterTts.setLanguage('zh');
        } catch (_) {}
      }

      final result = await _flutterTts.speak(text);
      if (result == 0) {
        debugPrint('[TTS] Native TTS 尚未完全 Bind，延迟 300ms 后进行二次唤醒');
        await Future.delayed(const Duration(milliseconds: 300));
        await _flutterTts.speak(text);
      }
    } catch (e) {
      debugPrint('[TTS] 调用原生系统 TTS 异常: $e');
      _isPlaying = false;
      _processingState = ProcessingState.idle;
      _notifyStateChanged();
    }
  }

  /// 停止手机系统 Native TTS
  Future<void> stopSystemTts() async {
    if (!_ttsInitialized) return;
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  /// 静默停止：重置内部状态但不触发回调
  /// 用于 play() 内部的清理，避免回调中错误地覆盖 provider 层刚设置的新消息状态
  Future<void> _stopSilently() async {
    _completionGuardTimer?.cancel();
    await stopSystemTts();
    try {
      await _player.stopPlayer();
    } catch (_) {}
    _playlist.clear();
    _playingMessageKey = null;
    _isPlaying = false;
    _processingState = ProcessingState.idle;
    // 不调用 _notifyStateChanged()!
  }

  /// 停止播放并清空队列（对外接口，会触发状态回调）
  Future<void> stop() async {
    await _stopSilently();
    _notifyStateChanged();
  }

  /// 统一的状态变更通知
  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  /// 释放资源
  void dispose() {
    _completionGuardTimer?.cancel();
    _progressSubscription?.cancel();
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
