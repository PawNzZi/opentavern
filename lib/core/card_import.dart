import 'dart:convert';
import 'dart:typed_data';

import '../data/demo.dart';
import 'lore_io.dart';
import 'models.dart';

/// Parses a SillyTavern V2/V3 character card from a PNG (tEXt/iTXt `chara` or
/// `ccv3` chunk) or a plain JSON file.
DemoCharacter? parseCharacterCard(Uint8List bytes, String fileName) {
  try {
    Map<String, dynamic>? json;
    String? avatar;

    if (_isPng(bytes)) {
      avatar = base64Encode(bytes);
      final text = _pngCardJson(bytes);
      if (text != null) {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          json = Map<String, dynamic>.from(decoded);
        }
      }
    } else {
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      final decoded = jsonDecode(text);
      if (decoded is Map) json = Map<String, dynamic>.from(decoded);
    }

    if (json == null) return null;
    // 世界书 JSON 顶层也有 name + entries：它不能当角色卡导入，
    // 否则会出现「名称是世界书名、内容全空」的假角色卡。
    if (json['data'] is! Map &&
        json.containsKey('entries') &&
        !json.containsKey('description') &&
        !json.containsKey('first_mes') &&
        !json.containsKey('personality') &&
        !json.containsKey('scenario')) {
      return null;
    }
    return DemoCharacter.fromCardJson(json, avatarBase64: avatar);
  } catch (_) {
    return null;
  }
}

bool _isPng(Uint8List b) {
  const sig = [137, 80, 78, 71, 13, 10, 26, 10];
  if (b.length < 8) return false;
  for (var i = 0; i < 8; i++) {
    if (b[i] != sig[i]) return false;
  }
  return true;
}

String? _pngCardJson(Uint8List b) {
  var offset = 8;
  String? chara;
  String? ccv3;
  while (offset + 8 <= b.length) {
    final length = _u32(b, offset);
    final type = String.fromCharCodes(b.sublist(offset + 4, offset + 8));
    final dataStart = offset + 8;
    final dataEnd = dataStart + length;
    if (dataEnd + 4 > b.length) break;
    final data = b.sublist(dataStart, dataEnd);
    if (type == 'tEXt') {
      final parsed = _textChunk(data);
      if (parsed != null) {
        if (parsed.$1 == 'chara') chara = parsed.$2;
        if (parsed.$1 == 'ccv3') ccv3 = parsed.$2;
      }
    } else if (type == 'iTXt') {
      final parsed = _itxtChunk(data);
      if (parsed != null) {
        if (parsed.$1 == 'chara') chara = parsed.$2;
        if (parsed.$1 == 'ccv3') ccv3 = parsed.$2;
      }
    }
    offset = dataEnd + 4;
  }
  String? payload = ccv3 ?? chara;
  if (payload == null) return null;
  try {
    return utf8.decode(base64Decode(payload));
  } catch (_) {
    return null;
  }
}

(String, String)? _textChunk(Uint8List data) {
  final zero = data.indexOf(0);
  if (zero < 0) return null;
  final key = latin1.decode(data.sublist(0, zero));
  final value = utf8.decode(data.sublist(zero + 1), allowMalformed: true);
  return (key, value);
}

(String, String)? _itxtChunk(Uint8List data) {
  final keyEnd = data.indexOf(0);
  if (keyEnd < 0 || keyEnd + 3 > data.length) return null;
  final key = latin1.decode(data.sublist(0, keyEnd));
  final compressed = data[keyEnd + 1] == 1;
  if (compressed) return null;
  var p = keyEnd + 3;
  final langEnd = data.indexOf(0, p);
  if (langEnd < 0) return null;
  p = langEnd + 1;
  final transEnd = data.indexOf(0, p);
  if (transEnd < 0) return null;
  p = transEnd + 1;
  final value = utf8.decode(data.sublist(p), allowMalformed: true);
  return (key, value);
}

int _u32(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

/// Extracts the embedded `character_book` of a V2/V3 card into a [Lorebook].
///
/// The book normally lives at `data.character_book`, but third-party cards also
/// put it at the root or under `data.extensions.character_book`, so all three
/// locations are checked. Every entry with content is imported (see
/// [loreEntryFromMap]): empty-key constant entries, disabled entries, selective
/// entries, secondary keys, position and insertion order are all preserved.
Lorebook? parseCharacterBook(Map<String, dynamic>? raw, {String? linked}) {
  if (raw == null) return null;
  final data = raw['data'] is Map
      ? Map<String, dynamic>.from(raw['data'] as Map)
      : raw;

  Map<String, dynamic>? book;
  final candidates = <dynamic>[
    data['character_book'],
    raw['character_book'],
    if (data['extensions'] is Map)
      (data['extensions'] as Map)['character_book'],
  ];
  for (final candidate in candidates) {
    if (candidate is Map) {
      book = Map<String, dynamic>.from(candidate);
      break;
    }
  }
  if (book == null) return null;

  final entriesRaw = book['entries'];
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final result = <LoreEntry>[];
  if (entriesRaw is List) {
    for (var i = 0; i < entriesRaw.length; i++) {
      final value = entriesRaw[i];
      if (value is! Map) continue;
      final entry = loreEntryFromMap(
        Map<String, dynamic>.from(value),
        id: 'card-$stamp-$i',
      );
      if (entry != null) result.add(entry);
    }
  } else if (entriesRaw is Map) {
    for (final item in entriesRaw.entries) {
      final value = item.value;
      if (value is! Map) continue;
      final entry = loreEntryFromMap(
        Map<String, dynamic>.from(value),
        id: 'card-$stamp-${item.key}',
      );
      if (entry != null) result.add(entry);
    }
  }
  if (result.isEmpty) return null;

  final bookName = (book['name'] ?? '').toString().trim();
  return Lorebook(
    id: 'book-$stamp',
    name: bookName.isNotEmpty ? bookName : (linked ?? '角色世界书'),
    linked: linked,
    entries: result,
  );
}
