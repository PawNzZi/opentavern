/// 角色卡导入/导出：PNG（tEXt）、JSON、CHARX/BYAF（ZIP）三种容器。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/tavern_card.dart';
import 'png_card_codec.dart';

class CardException implements Exception {
  CardException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CardImportResult {
  CardImportResult({
    required this.card,
    required this.source,
    this.image,
  });

  final TavernCard card;

  /// `png` / `json` / `charx`
  final String source;

  /// PNG 卡的原图（导入后当头像用）；其它格式为 null。
  final Uint8List? image;
}

class CardIo {
  CardIo._();

  /// 根据文件名与内容自动判断容器。
  static CardImportResult parse(Uint8List bytes, {String fileName = ''}) {
    final String lower = fileName.toLowerCase();
    final bool isZip = bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
    if (lower.endsWith('.charx') || lower.endsWith('.byaf') || lower.endsWith('.zip') || isZip) {
      final Map<String, dynamic> json = _readZipJson(bytes);
      return CardImportResult(card: normalize(json), source: 'charx');
    }
    if (lower.endsWith('.png') || PngCardCodec.looksLikePng(bytes)) {
      final Map<String, dynamic>? json = PngCardCodec.readCardJson(bytes);
      if (json == null) {
        throw CardException('这张 PNG 里没有角色卡数据（缺少 chara / ccv3 元数据）');
      }
      return CardImportResult(card: normalize(json), source: 'png', image: bytes);
    }
    return CardImportResult(card: normalize(_readJson(bytes)), source: 'json');
  }

  static Map<String, dynamic> _readJson(Uint8List bytes) {
    try {
      final Object? parsed = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
      throw CardException('角色卡不是 JSON 对象');
    } on CardException {
      rethrow;
    } catch (_) {
      throw CardException('JSON 文件格式错误');
    }
  }

  static Map<String, dynamic> _readZipJson(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (_) {
      throw CardException('ZIP 文件损坏');
    }
    final List<ArchiveFile> candidates = <ArchiveFile>[];
    for (final ArchiveFile file in archive.files) {
      final String name = file.name.toLowerCase();
      if (!file.isFile || !name.endsWith('.json') || name.endsWith('settings.json')) {
        continue;
      }
      candidates.add(file);
    }
    if (candidates.isEmpty) {
      throw CardException('ZIP 里没有可解析的 JSON 角色卡');
    }
    ArchiveFile preferred = candidates.first;
    for (final ArchiveFile file in candidates) {
      if (RegExp(r'(^|/)(card|character|chara)\.json$').hasMatch(file.name.toLowerCase())) {
        preferred = file;
        break;
      }
    }
    try {
      final Object? parsed = jsonDecode(utf8.decode(preferred.content as List<int>, allowMalformed: true));
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
    } catch (_) {
      // 落到下面的统一报错
    }
    throw CardException('ZIP 里的角色卡不是合法 JSON');
  }

  /// V1 / V2 / V3 统一成内部模型。
  static TavernCard normalize(Map<String, dynamic> raw) {
    final Map<String, dynamic> data = raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : raw;
    final String name = _text(data['name'], 120).trim();
    if (name.isEmpty) {
      throw CardException('角色卡缺少 name');
    }
    TavernWorld? book;
    final Object? rawBook = data['character_book'];
    if (rawBook is Map) {
      book = _normalizeBook(Map<String, dynamic>.from(rawBook), '$name 的世界书');
    }
    final List<String> greetings = _strings(data['alternate_greetings'] ?? data['alternateGreetings']);
    if (rawBook is Map) {
      final Object? entries = rawBook['entries'];
      if (entries is List) {
        for (final Object? entry in entries) {
          if (entry is! Map) continue;
          final String label = '${entry['comment'] ?? ''} ${entry['name'] ?? ''} '
              '${(entry['keys'] is List) ? (entry['keys'] as List).join(' ') : entry['keys'] ?? ''}';
          if (!RegExp(r'开场白|开场|greeting|first[_ ]?mes|alternate', caseSensitive: false).hasMatch(label)) {
            continue;
          }
          final String content = _text(entry['content'] ?? entry['entry'], 200000).trim();
          if (content.isNotEmpty) greetings.add(content);
        }
      }
    }
    return TavernCard(
      name: name,
      description: _text(data['description']),
      personality: _text(data['personality']),
      scenario: _text(data['scenario']),
      firstMes: _text(data['first_mes'] ?? data['firstMessage']),
      example: _text(data['mes_example'] ?? data['exampleDialogue']),
      creatorNotes: _text(data['creator_notes'] ?? data['creatorcomment']),
      systemPrompt: _text(data['system_prompt'] ?? data['systemPrompt']),
      postHistory: _text(data['post_history_instructions'] ?? data['postHistoryInstructions']),
      alternateGreetings: greetings,
      tags: _strings(data['tags']).take(20).toList(growable: false),
      creator: _text(data['creator'], 120),
      characterVersion: _text(data['character_version'] ?? data['characterVersion'], 80),
      extensions: data['extensions'] is Map
          ? Map<String, dynamic>.from(data['extensions'] as Map)
          : <String, dynamic>{},
      voice: _text((data['extensions'] is Map) ? (data['extensions'] as Map)['hdsh_voice'] : '', 80),
      spec: _text(raw['spec'], 40),
      specVersion: _text(raw['spec_version'], 20),
      book: book,
    );
  }

  static TavernWorld _normalizeBook(Map<String, dynamic> book, String fallbackName) {
    final List<dynamic> rawEntries = book['entries'] is List ? book['entries'] as List<dynamic> : <dynamic>[];
    final List<TavernWorldEntry> entries = <TavernWorldEntry>[];
    for (int i = 0; i < rawEntries.length; i++) {
      final Object? item = rawEntries[i];
      if (item is! Map) continue;
      final Map<String, dynamic> entry = Map<String, dynamic>.from(item);
      entries.add(TavernWorldEntry(
        id: 'e${i + 1}',
        comment: _text(entry['comment'] ?? entry['name'], 200),
        keys: _strings(entry['keys'] ?? entry['key']),
        content: _text(entry['content'] ?? entry['entry']),
        order: _int(entry['insertion_order'] ?? entry['order'], 100),
        position: _int(entry['position'], 0),
        depth: _int(entry['depth'], 4),
        role: _int(entry['role'], 0),
        enabled: entry['enabled'] != false,
        constant: entry['constant'] == true,
        selective: entry['selective'] != false,
      ));
    }
    return TavernWorld(
      id: '',
      name: _text(book['name'], 120).trim().isEmpty ? fallbackName : _text(book['name'], 120).trim(),
      entries: entries,
    );
  }

  /// 导出成 V2 JSON（给「导出 JSON」用）。
  static String exportJson(TavernCard card) {
    return const JsonEncoder.withIndent('  ').convert(cardToV2Json(card));
  }

  /// 导出成 PNG（把 V2 JSON 塞进 chara 块）。
  static Uint8List exportPng(TavernCard card, {Uint8List? image}) {
    final Uint8List base = image ?? PngCardCodec.fallbackPng;
    return PngCardCodec.embedCard(base, cardToV2Json(card));
  }

  static String _text(Object? value, [int max = 200000]) {
    final String text = value is String ? value : (value == null ? '' : '$value');
    return text.length <= max ? text : text.substring(0, max);
  }

  static int _int(Object? value, int fallback) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  static List<String> _strings(Object? value) {
    if (value is! List) return const <String>[];
    return <String>[
      for (final Object? item in value)
        if ('$item'.trim().isNotEmpty) '$item'.trim(),
    ];
  }
}
