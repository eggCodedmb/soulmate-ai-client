import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/storage/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地存储
  await LocalStorage.init();

  // 初始化Firebase（取消注释以启用）
  // await Firebase.initializeApp();

  runApp(
    const ProviderScope(
      child: SoulMateApp(),
    ),
  );
}
