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
  VadHandler? _vadHandler;
  StreamSubscription? _onSpeechEndSub;
  StreamSubscription? _onFrameProcessedSub;
  StreamSubscription? _onErrorSub;

  @override
  VadState build() {
    _vadHandler = VadHandler.create();
    
    // 初始化时建立监听，避免重复订阅
    _onSpeechEndSub = _vadHandler!.onSpeechEnd.listen((samples) async {
      debugPrint('[VadNotifier] Speech ended, captured ${samples.length} samples');
      if (state.isRecording) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/call_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

        final wavData = AudioUtils.samplesToWav(samples, 16000);
        await File(filePath).writeAsBytes(wavData);

        state = state.copyWith(lastAudioPath: filePath);
        // 自动停止录音
        stopListening();
      }
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
      
      // 延迟释放，彻底规避 vad 包内部在 stopListening 后因异步导致 closed controller add 的崩溃
      final handler = _vadHandler;
      _vadHandler = null;
      if (handler != null) {
        handler.stopListening().then((_) {
          Future.delayed(const Duration(milliseconds: 200), () {
            try {
              handler.dispose();
            } catch (_) {}
          });
        });
      }
    });

    return const VadState();
  }

  Future<void> startListening() async {
    if (state.isRecording) return;
    state = state.copyWith(isRecording: true, error: null, lastAudioPath: null);
    
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