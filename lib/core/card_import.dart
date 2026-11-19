import 'dart:convert';
import 'dart:typed_data';

import '../data/demo.dart';
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

Lorebook? parseCharacterBook(Map<String, dynamic>? raw, {String? linked}) {
  if (raw == null) return null;
  final data = raw['data'] is Map ? raw['data'] as Map : raw;
  final book = data['character_book'];
  if (book is! Map) return null;
  final entries = book['entries'];
  if (entries is! List || entries.isEmpty) return null;
  final result = <LoreEntry>[];
  for (final entry in entries.whereType<Map>()) {
    final keys = (entry['keys'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        [];
    final content = (entry['content'] ?? '').toString().trim();
    if (keys.isEmpty || content.isEmpty) continue;
    final ext = entry['extensions'] is Map
        ? Map<String, dynamic>.from(entry['extensions'] as Map)
        : const <String, dynamic>{};
    result.add(
      LoreEntry(
        id: 'lore-${DateTime.now().microsecondsSinceEpoch}-${result.length}',
        name: (entry['name'] ?? entry['comment'] ?? keys.first).toString(),
        keys: keys,
        secondaryKeys: (entry['secondary_keys'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        content: content,
        enabled: entry['enabled'] != false,
        constant: entry['constant'] == true,
        selective: entry['selective'] == true,
        order: (entry['insertion_order'] as num?)?.toInt() ??
            (entry['order'] as num?)?.toInt() ??
            100,
        position: (entry['position'] == 'after_char' ||
                entry['position'] == 1 ||
                ext['position'] == 1)
            ? 'after'
            : 'before',
        depth: (ext['depth'] as num?)?.toInt() ?? 4,
        role: (ext['role'] ?? 'system').toString(),
        comment: (entry['comment'] ?? '').toString(),
      ),
    );
  }
  if (result.isEmpty) return null;
  return Lorebook(
    id: 'book-${DateTime.now().microsecondsSinceEpoch}',
    name: (book['name'] ?? linked ?? '角色世界书').toString(),
    linked: linked,
    entries: result,
  );
}
