import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vad/vad.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/utils/audio_utils.dart';

// 状态类，包含 VAD 的当前状态
class VadState {
  final bool isRecording;
  final double currentDb;
  final String? lastAudioPath;
  final String? error;

  const VadState({
    this.isRecording = false,
    this.currentDb = -60.0,
    this.lastAudioPath,
    this.error,
  });

  VadState copyWith({
    bool? isRecording,
    double? currentDb,
    String? lastAudioPath,
    String? error,
  }) {
    return VadState(
      isRecording: isRecording ?? this.isRecording,
      currentDb: currentDb ?? this.currentDb,
      lastAudioPath: lastAudioPath, // 这里不使用 ??，因为可能需要重置为 null
      error: error,
    );
  }
}

// 使用 Riverpod 管理 VAD 生命周期
class VadNotifier extends AutoDisposeNotifier<VadState> {
  static Future<void>? _cleanupFuture;
  VadHandler? _vadHandler;
  StreamSubscription? _onSpeechEndSub;
  StreamSubscription? _onFrameProcessedSub;
  StreamSubscription? _onErrorSub;

  @override
  VadState build() {
    _vadHandler = VadHandler.create();
    
    // 初始化时建立监听，避免重复订阅
    _onSpeechEndSub = _vadHandler!.onSpeechEnd.listen((samples) {
      // 使用 Future.microtask 避开 stream callback 的同步调用栈，彻底防止与底层 FFI 录音停止发生死锁
      Future.microtask(() async {
        if (!state.isRecording) return;
        debugPrint('[VadNotifier] Speech ended, captured ${samples.length} samples');
        try {
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/call_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

          final wavData = AudioUtils.samplesToWav(samples, 16000);
          await File(filePath).writeAsBytes(wavData);

          // 先彻底关闭底层录音，避免 UI 监听器并发重复触发 stopListening()
          await stopListening();
          state = state.copyWith(lastAudioPath: filePath);
        } catch (e) {
          debugPrint('[VadNotifier] Error processing speech end: $e');
        }
      });
    });

    _onFrameProcessedSub = _vadHandler!.onFrameProcessed.listen((frame) {
      if (!state.isRecording) return;
      final db = AudioUtils.calculateDb(frame.frame);
      state = state.copyWith(currentDb: db, lastAudioPath: null);
    });

    _onErrorSub = _vadHandler!.onError.listen((error) {
      debugPrint('[VadNotifier] Error: $error');
      state = state.copyWith(error: error, lastAudioPath: null);
    });

    // 绑定 Riverpod 的 dispose 生命周期，避免在组件树中手动 manage
    ref.onDispose(() {
      _onSpeechEndSub?.cancel();
      _onFrameProcessedSub?.cancel();
      _onErrorSub?.cancel();
      
      final handler = _vadHandler;
      _vadHandler = null;
      if (handler != null) {
        _cleanupFuture = () async {
          try {
            await handler.stopListening().timeout(const Duration(milliseconds: 300));
            await Future.delayed(const Duration(milliseconds: 100));
            await handler.dispose();
          } catch (e) {
            debugPrint('[VadNotifier] Cleanup error: $e');
          }
        }();
      }
    });

    return const VadState();
  }

  Future<void> startListening() async {
    if (state.isRecording) return;
    
    if (_cleanupFuture != null) {
      debugPrint('[VadNotifier] Waiting for previous VAD instance cleanup...');
      try {
        await _cleanupFuture!.timeout(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('[VadNotifier] Previous VAD instance cleanup timed out or failed: $e');
      }
      _cleanupFuture = null;
      debugPrint('[VadNotifier] Previous VAD instance cleanup done/bypassed');
    }
    
    state = state.copyWith(isRecording: true, error: null, lastAudioPath: null);
    
    // 使用 runZonedGuarded 捕获第三方 VAD 内部异步循环抛出的未捕获异常
    unawaited(runZonedGuarded(() async {
      try {
        await _vadHandler?.startListening(
          positiveSpeechThreshold: 0.5,
          redemptionFrames: 25,
          model: 'v5',
          frameSamples: 512,
        );
      } catch (e) {
        debugPrint('[VadNotifier] startListening failed: $e');
        state = state.copyWith(isRecording: false, error: e.toString());
      }
    }, (error, stack) {
      debugPrint('[VadNotifier] Caught VAD internal async error: $error');
      // 如果是已知无害的 StreamController close 之后的添加事件报错，进行静默忽略，防止 Crash
      if (error.toString().contains('Cannot add new events after calling close')) {
        return;
      }
      if (state.isRecording) {
        state = state.copyWith(error: error.toString());
      }
    }));
  }

  Future<void> stopListening() async {
    if (!state.isRecording) return;
    state = state.copyWith(isRecording: false);
    try {
      await _vadHandler?.stopListening();
    } catch (e) {
      debugPrint('[VadNotifier] stopListening failed: $e');
    }
  }
  
  void clearAudioPath() {
    state = state.copyWith(lastAudioPath: null);
  }
}

final vadNotifierProvider = AutoDisposeNotifierProvider<VadNotifier, VadState>(() {
  return VadNotifier();
});