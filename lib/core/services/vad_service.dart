import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../core/utils/audio_utils.dart';

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
      lastAudioPath: lastAudioPath,
      error: error,
    );
  }
}

class VadNotifier extends AutoDisposeNotifier<VadState> {
  static Future<void>? _cleanupFuture;
  sherpa_onnx.VoiceActivityDetector? _vad;
  StreamSubscription<Uint8List>? _audioSub;
  bool _isListening = false;
  final List<double> _allSamples = [];

  @override
  VadState build() {
    ref.onDispose(() async {
      await _stopAndDispose();
    });
    return const VadState();
  }

  Future<String> _getModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    final modelPath = '${modelDir.path}/silero_vad.onnx';
    final file = File(modelPath);
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/silero_vad.onnx');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    return modelPath;
  }

  Future<void> startListening(Stream<Uint8List> audioStream) async {
    if (state.isRecording) return;
    _allSamples.clear();

    if (_cleanupFuture != null) {
      try {
        await _cleanupFuture!.timeout(const Duration(milliseconds: 500));
      } catch (_) {}
      _cleanupFuture = null;
    }

    try {
      final modelPath = await _getModelPath();

      final sileroConfig = sherpa_onnx.SileroVadModelConfig(
        model: modelPath,
        minSilenceDuration: 1.0,
        minSpeechDuration: 0.3,
        threshold: 0.75,
        windowSize: 512,
      );

      final config = sherpa_onnx.VadModelConfig(
        sileroVad: sileroConfig,
        numThreads: 1,
        debug: false,
      );

      _vad = sherpa_onnx.VoiceActivityDetector(
        config: config,
        bufferSizeInSeconds: 30,
      );

      _isListening = true;
      state = state.copyWith(
        isRecording: true,
        error: null,
        lastAudioPath: null,
      );

      _audioSub = audioStream.listen(
        (data) {
          if (!_isListening || _vad == null) return;

          final samples = _pcm16ToFloat32(data);
          if (samples.isEmpty) return;

          _allSamples.addAll(samples);

          final db = AudioUtils.calculateDb(samples);
          if (state.isRecording) {
            state = state.copyWith(currentDb: db);
          }

          // Noise gate: if volume is below -42.0 dBFS (approx. 45 dB SPL noise),
          // treat the chunk as absolute silence to allow the VAD to trigger speech end.
          final processedSamples = db < -42.0
              ? Float32List(samples.length)
              : samples;

          _vad!.acceptWaveform(processedSamples);

          if (_vad!.isDetected()) {
            _drainSpeechSegments();
          }
        },
        onError: (Object e) {
          debugPrint('[VadNotifier] Audio stream error: $e');
          if (state.isRecording) {
            state = state.copyWith(error: e.toString());
          }
        },
      );
    } catch (e) {
      debugPrint('[VadNotifier] startListening failed: $e');
      state = state.copyWith(isRecording: false, error: e.toString());
    }
  }

  Future<void> _drainSpeechSegments() async {
    if (_vad == null) return;

    while (!_vad!.isEmpty()) {
      final segment = _vad!.front();
      _vad!.pop();

      try {
        final tempDir = await getTemporaryDirectory();
        final filePath =
            '${tempDir.path}/call_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
        final wavData = AudioUtils.samplesToWav(segment.samples, 16000);
        await File(filePath).writeAsBytes(wavData);

        if (state.isRecording) {
          _isListening = false;
          state = state.copyWith(isRecording: false);
          await _audioSub?.cancel();
          _audioSub = null;
        }

        state = state.copyWith(lastAudioPath: filePath);
        break; // Only process the first segment
      } catch (e) {
        debugPrint('[VadNotifier] Error processing speech segment: $e');
      }
    }
  }

  Future<void> stopListening() async {
    if (!state.isRecording) return;
    _isListening = false;
    state = state.copyWith(isRecording: false);

    await _audioSub?.cancel();
    _audioSub = null;

    try {
      _vad?.flush();
      await _drainSpeechSegments();

      if (state.lastAudioPath == null) {
        debugPrint('[VadNotifier] VAD did not detect segments on stop, using fallback');
        final tempDir = await getTemporaryDirectory();
        final filePath =
            '${tempDir.path}/call_voice_fallback_${DateTime.now().millisecondsSinceEpoch}.wav';
        final samples = _allSamples.isNotEmpty ? _allSamples : List<double>.filled(1600, 0.0);
        final wavData = AudioUtils.samplesToWav(samples, 16000);
        await File(filePath).writeAsBytes(wavData);
        state = state.copyWith(lastAudioPath: filePath);
      }
    } catch (e) {
      debugPrint('[VadNotifier] stopListening error: $e');
    }
  }

  Future<void> _stopAndDispose() async {
    _isListening = false;
    _allSamples.clear();
    await _audioSub?.cancel();
    _audioSub = null;

    final vad = _vad;
    _vad = null;

    if (vad != null) {
      _cleanupFuture = () async {
        try {
          vad.flush();
          vad.free();
        } catch (e) {
          debugPrint('[VadNotifier] Cleanup error: $e');
        }
      }();
    }
  }

  void clearAudioPath() {
    state = state.copyWith(lastAudioPath: null);
  }

  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    // 先拷贝到对齐的缓冲区 — record 包返回的 Uint8List 底层 buffer 偏移可能
    // 为奇数（非 2 的倍数），Int16List.view 要求偏移量必须是 2 字节对齐的。
    final aligned = Uint8List.fromList(bytes);
    final int16List = Int16List.view(
      aligned.buffer,
      0,
      aligned.lengthInBytes ~/ 2,
    );
    final float32List = Float32List(int16List.length);
    for (int i = 0; i < int16List.length; i++) {
      float32List[i] = int16List[i] / 32768.0;
    }
    return float32List;
  }
}

final vadNotifierProvider =
    AutoDisposeNotifierProvider<VadNotifier, VadState>(() {
  return VadNotifier();
});
