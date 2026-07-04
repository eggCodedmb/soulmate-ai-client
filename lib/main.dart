import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'app.dart';
import 'core/storage/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 sherpa_onnx 原生绑定（必须在任何 VAD/ASR/TTS 使用前调用）
  sherpa_onnx.initBindings();

  // 初始化本地存储（必须在 runApp 之前，因为 Provider 需要读取配置）
  await LocalStorage.init();

  runApp(
    const ProviderScope(
      child: SoulMateApp(),
    ),
  );
}
