/// OpenTavern：单机 AI 角色扮演。
///
/// 与旧版（跑在 DSH 里的酒馆插件）不同：没有桌面端、没有服务端，
/// 角色卡 / 世界书 / 对话 / 记忆全部存在本机，AI 直连用户配置的供应商。
///
/// 阶段 0：项目骨架 + 液态玻璃外壳 + 供应商客户端 + 本地存储。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'core/store/tavern_store.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TavernStore.instance.load();
  runApp(const OpenTavernApp());
}

class OpenTavernApp extends StatelessWidget {
  const OpenTavernApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenTavern',
      debugShowCheckedModeBanner: false,
      theme: buildTavernTheme(),
      home: const TavernShell(),
    );
  }
}
