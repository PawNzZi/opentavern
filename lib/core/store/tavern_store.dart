/// 本地数据仓库。
///
/// 数据结构与旧版酒馆插件的 `data.json` 完全一致（`version: 1` +
/// `characters` / `worlds` / `chats`），因此旧 App 导出的备份可以直接导入。
///
/// 存储位置：应用文档目录下 `OpenTavern/data.json`，写入走「临时文件 + 改名」，
/// 避免写到一半被杀进程导致数据损坏。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TavernStore {
  TavernStore._();

  static final TavernStore instance = TavernStore._();

  static const int schemaVersion = 1;

  late Directory _dir;
  Map<String, dynamic> _data = <String, dynamic>{
    'version': schemaVersion,
    'characters': <dynamic>[],
    'worlds': <dynamic>[],
    'chats': <dynamic>[],
  };

  String get directoryPath => _dir.path;

  String get dataFilePath => p.join(_dir.path, 'data.json');

  List<Map<String, dynamic>> get characters => _listOf('characters');

  List<Map<String, dynamic>> get worlds => _listOf('worlds');

  List<Map<String, dynamic>> get chats => _listOf('chats');

  List<Map<String, dynamic>> _listOf(String key) {
    final Object? raw = _data[key];
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }
    return raw.whereType<Map>().map((Map item) {
      return item.map((Object? k, Object? v) => MapEntry<String, dynamic>('$k', v));
    }).toList(growable: false);
  }

  Future<void> load() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    _dir = Directory(p.join(docs.path, 'OpenTavern'));
    if (!await _dir.exists()) {
      await _dir.create(recursive: true);
    }
    final File file = File(dataFilePath);
    if (!await file.exists()) {
      return;
    }
    try {
      final Object? parsed = jsonDecode(await file.readAsString());
      if (parsed is Map) {
        _data = <String, dynamic>{
          'version': schemaVersion,
          'characters': parsed['characters'] is List ? parsed['characters'] : <dynamic>[],
          'worlds': parsed['worlds'] is List ? parsed['worlds'] : <dynamic>[],
          'chats': parsed['chats'] is List ? parsed['chats'] : <dynamic>[],
        };
      }
    } catch (_) {
      // 文件损坏时保留空库，不阻塞启动；后续写入会覆盖。
    }
  }

  Future<void> save() async {
    final File target = File(dataFilePath);
    final File temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(_data), flush: true);
    await temp.rename(target.path);
  }

  /// 整体替换（用于导入备份）。
  Future<void> replaceAll(Map<String, dynamic> incoming) async {
    _data = <String, dynamic>{
      'version': schemaVersion,
      'characters': incoming['characters'] is List ? incoming['characters'] : <dynamic>[],
      'worlds': incoming['worlds'] is List ? incoming['worlds'] : <dynamic>[],
      'chats': incoming['chats'] is List ? incoming['chats'] : <dynamic>[],
    };
    await save();
  }

  Map<String, dynamic> snapshot() => Map<String, dynamic>.of(_data);
}
