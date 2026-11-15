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
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/tavern_card.dart';

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

  /// 直接访问底层数据（设置等模块需要原地读写）。
  Map<String, dynamic> get rawData => _data;

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

  /// 导入一张角色卡：写头像、必要时拆出内嵌世界书、落库。
  Future<Map<String, dynamic>> importCard(TavernCard card, {Uint8List? avatar}) async {
    const Uuid uuid = Uuid();
    final String id = 'c_${uuid.v4()}';
    final int now = DateTime.now().millisecondsSinceEpoch;

    String avatarPath = '';
    if (avatar != null && avatar.isNotEmpty) {
      final Directory dir = Directory(p.join(_dir.path, 'avatars'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final File file = File(p.join(dir.path, '$id.png'));
      await file.writeAsBytes(avatar, flush: true);
      avatarPath = file.path;
    }

    final List<String> worldIds = <String>[];
    final TavernWorld? book = card.book;
    if (book != null && book.entries.isNotEmpty) {
      final String worldId = 'w_${uuid.v4()}';
      _data['worlds'].add(<String, dynamic>{
        'id': worldId,
        'name': book.name,
        'entries': book.entries.map((TavernWorldEntry e) => e.toJson()).toList(),
        'ownerCharacterId': id,
        'createdAt': now,
        'updatedAt': now,
      });
      worldIds.add(worldId);
    }

    final Map<String, dynamic> record = <String, dynamic>{
      'id': id,
      'name': card.name,
      'avatar': avatarPath,
      'description': card.description,
      'personality': card.personality,
      'scenario': card.scenario,
      'firstMes': card.firstMes,
      'example': card.example,
      'creatorNotes': card.creatorNotes,
      'systemPrompt': card.systemPrompt,
      'postHistory': card.postHistory,
      'alternateGreetings': card.alternateGreetings,
      'tags': card.tags,
      'creator': card.creator,
      'characterVersion': card.characterVersion,
      'extensions': card.extensions,
      'voice': card.voice,
      'spec': card.spec,
      'specVersion': card.specVersion,
      'worldIds': worldIds,
      'createdAt': now,
      'updatedAt': now,
    };
    (_data['characters'] as List).add(record);
    await save();
    return record;
  }

  /// 删除角色（连带它的头像文件与归属世界书）。
  Future<void> deleteCharacter(String id) async {
    final List<dynamic> characters = _data['characters'] as List;
    final int index = characters.indexWhere((Object? item) => item is Map && item['id'] == id);
    if (index < 0) return;
    final Map<dynamic, dynamic> record = characters[index] as Map;
    final String avatar = '${record['avatar'] ?? ''}';
    if (avatar.isNotEmpty) {
      try {
        final File file = File(avatar);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // 删不掉不影响数据
      }
    }
    characters.removeAt(index);
    final List<dynamic> worlds = _data['worlds'] as List;
    worlds.removeWhere((Object? item) => item is Map && item['ownerCharacterId'] == id);
    await save();
  }

  Map<String, dynamic>? character(String id) => _find('characters', id);

  Map<String, dynamic>? world(String id) => _find('worlds', id);

  Map<String, dynamic>? chat(String id) => _find('chats', id);

  Map<String, dynamic>? _find(String key, String id) {
    final Object? raw = _data[key];
    if (raw is! List) return null;
    for (final Object? item in raw) {
      if (item is Map && '${item['id']}' == id) {
        return item.map((Object? k, Object? v) => MapEntry<String, dynamic>('$k', v));
      }
    }
    return null;
  }

  /// 直接拿到可修改的条目引用（不复制）。
  Map? mutable(String key, String id) {
    final Object? raw = _data[key];
    if (raw is! List) return null;
    for (final Object? item in raw) {
      if (item is Map && '${item['id']}' == id) return item;
    }
    return null;
  }

  List<Map<String, dynamic>> get worldsOfCharacter {
    return worlds;
  }

  /// 新建世界书（导入备份/手动新建用）。
  Future<Map<String, dynamic>> addWorld(String name, {String ownerCharacterId = ''}) async {
    final String id = 'w_${const Uuid().v4()}';
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> world = <String, dynamic>{
      'id': id,
      'name': name,
      'entries': <dynamic>[],
      'ownerCharacterId': ownerCharacterId,
      'createdAt': now,
      'updatedAt': now,
    };
    (_data['worlds'] as List).add(world);
    await save();
    return world;
  }

  Future<void> deleteWorld(String id) async {
    (_data['worlds'] as List).removeWhere((Object? item) => item is Map && '${item['id']}' == id);
    await save();
  }

  /// 新建对话（第一条消息是开场白）。
  Future<Map<String, dynamic>> addChat(
    String characterId, {
    required String firstMes,
    String title = '',
  }) async {
    final String id = 't_${const Uuid().v4()}';
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> chat = <String, dynamic>{
      'id': id,
      'characterId': characterId,
      'title': title,
      'messages': <dynamic>[
        if (firstMes.trim().isNotEmpty)
          <String, dynamic>{
            'id': 'm_${const Uuid().v4()}',
            'role': 'assistant',
            'text': firstMes,
            'at': now,
          },
      ],
      'variables': <String, dynamic>{},
      'memory': null,
      'createdAt': now,
      'updatedAt': now,
    };
    (_data['chats'] as List).add(chat);
    await save();
    return chat;
  }

  Future<void> deleteChat(String id) async {
    (_data['chats'] as List).removeWhere((Object? item) => item is Map && '${item['id']}' == id);
    await save();
  }

  Future<void> touchChat(String id) async {
    final Map? chat = mutable('chats', id);
    if (chat == null) return;
    chat['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    await save();
  }

  Map<String, dynamic> snapshot() => Map<String, dynamic>.of(_data);
}
