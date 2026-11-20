import 'dart:convert';
import 'dart:typed_data';

import 'models.dart';

/// Reads SillyTavern `worlds/<name>.json` style files.
///
/// ST stores entries under `entries` as an object keyed by uid (`"0": {...}`)
/// or as an array; both shapes are accepted. Each entry keeps every field the
/// app can represent: `key`/`keys`, `keysecondary`/`secondary_keys`,
/// `comment`, `content`, `constant`, `selective`, `order`/`insertion_order`,
/// `position`, `disable`/`enabled`, `depth` and `role`.
Lorebook? parseWorldInfo(Uint8List bytes, String fileName) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    Map<String, dynamic>? map;
    dynamic entriesRaw;
    if (decoded is Map) {
      map = Map<String, dynamic>.from(decoded);
      entriesRaw = map['entries'];
    } else if (decoded is List) {
      entriesRaw = decoded;
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final entries = <LoreEntry>[];
    if (entriesRaw is Map) {
      for (final item in entriesRaw.entries) {
        final value = item.value;
        if (value is! Map) continue;
        final parsed = loreEntryFromMap(
          Map<String, dynamic>.from(value),
          id: 'world-$stamp-${item.key}',
        );
        if (parsed != null) entries.add(parsed);
      }
    } else if (entriesRaw is List) {
      for (var i = 0; i < entriesRaw.length; i++) {
        final value = entriesRaw[i];
        if (value is! Map) continue;
        final parsed = loreEntryFromMap(
          Map<String, dynamic>.from(value),
          id: 'world-$stamp-$i',
        );
        if (parsed != null) entries.add(parsed);
      }
    }
    if (entries.isEmpty) return null;

    final rawName = map == null ? '' : _text(map['name']);
    final name = rawName.isNotEmpty ? rawName : _fileStem(fileName);
    return Lorebook(
      id: 'book-$stamp',
      name: name.isEmpty ? '世界书' : name,
      entries: entries,
    );
  } catch (_) {
    return null;
  }
}

/// Converts one SillyTavern world-info / character-book entry map into a
/// [LoreEntry]. Both `worlds/*.json` and V2/V3 `character_book` use the same
/// field names (with aliases), so the import rules live in one place and are
/// shared by [parseWorldInfo] and `parseCharacterBook`.
///
/// Import rules (documented on purpose, so nothing is silently lost):
/// * An entry with empty `content` is skipped — there is nothing to inject or
///   edit.
/// * An entry with no `keys` and `constant == false` is **kept**: ST editors
///   allow such "orphan" entries (drafts, disabled notes, mvu/InitVar helpers).
///   It will never activate, but it stays visible and editable so the user can
///   add keywords later instead of losing it on import.
/// * `enabled` honours both the character-card `enabled` field and ST's
///   `disable` flag; `selective` defaults to `false` as in ST.
LoreEntry? loreEntryFromMap(
  Map<String, dynamic> map, {
  required String id,
}) {
  final content = _text(map['content']);
  if (content.isEmpty) return null;

  final extensions = map['extensions'] is Map
      ? Map<String, dynamic>.from(map['extensions'] as Map)
      : const <String, dynamic>{};
  final keys = _firstKeys(map, const ['keys', 'key']);
  final secondary = _firstKeys(
    map,
    const ['secondary_keys', 'keysecondary', 'secondarykeys'],
  );
  final constant = _asBool(map['constant']);
  final comment = _text(map['comment']);
  final explicitName = _text(map['name']);
  final firstKey = keys.isEmpty ? '' : keys.first;
  final name = explicitName.isNotEmpty
      ? explicitName
      : comment.isNotEmpty
          ? comment
          : firstKey.isNotEmpty
              ? firstKey
              : constant
                  ? '常驻条目'
                  : '无关键词条目';

  return LoreEntry(
    id: id,
    name: name,
    keys: keys,
    secondaryKeys: secondary,
    content: content,
    // Character cards use `enabled`; world-info files use `disable`.
    enabled: map.containsKey('enabled')
        ? _asBool(map['enabled'], fallback: true)
        : map.containsKey('disable')
            ? !_asBool(map['disable'])
            : true,
    constant: constant,
    selective: _asBool(map['selective']),
    order: _asInt(map['insertion_order']) ?? _asInt(map['order']) ?? 100,
    position: _position(map['position'] ?? extensions['position']),
    depth: _asInt(extensions['depth']) ?? _asInt(map['depth']) ?? 4,
    role: _role(extensions['role'] ?? map['role']),
    comment: comment,
  );
}

/// Exports a [Lorebook] as a SillyTavern `worlds/*.json` compatible file.
Map<String, dynamic> lorebookToWorldJson(Lorebook book) {
  final entries = <String, dynamic>{};
  for (var i = 0; i < book.entries.length; i++) {
    final e = book.entries[i];
    entries['$i'] = {
      'uid': i,
      'key': e.keys,
      'keysecondary': e.secondaryKeys,
      'comment': e.name.isNotEmpty
          ? e.name
          : e.comment.isNotEmpty
              ? e.comment
              : e.keys.isEmpty
                  ? '条目 $i'
                  : e.keys.first,
      'content': e.content,
      'constant': e.constant,
      'selective': e.selective,
      'order': e.order,
      'position': e.position == 'after' ? 1 : 0,
      'disable': !e.enabled,
      'depth': e.depth,
      'role': _roleIndex(e.role),
    };
  }
  return {
    'name': book.name,
    'entries': entries,
  };
}

List<String> _keys(dynamic value) {
  if (value is List) {
    return value.map(_text).where((e) => e.isNotEmpty).toList();
  }
  if (value is String) {
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

/// Character cards use `keys`/`secondary_keys`, ST worlds use
/// `key`/`keysecondary`; some hybrid exports carry both, so take the first
/// field that actually yields keywords instead of trusting a single key.
List<String> _firstKeys(Map<String, dynamic> map, List<String> fields) {
  for (final field in fields) {
    final parsed = _keys(map[field]);
    if (parsed.isNotEmpty) return parsed;
  }
  return const [];
}

String _text(dynamic value) => value == null ? '' : value.toString().trim();

String _fileStem(String fileName) {
  var name = fileName.replaceAll('\\', '/').split('/').last.trim();
  if (name.toLowerCase().endsWith('.json')) {
    name = name.substring(0, name.length - 5);
  }
  return name.trim();
}

int? _asInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
    }
  }
  return fallback;
}

/// ST `position`: 0 = before char, 1 = after char, 2+ = AN/depth variants.
/// The app only distinguishes before/after, so every non-zero value maps to
/// `after` (closest to ST's behaviour) instead of being dropped.
String _position(dynamic value) {
  if (value is num) return value.toInt() <= 0 ? 'before' : 'after';
  final text = _text(value).toLowerCase();
  if (text.isEmpty) return 'before';
  final number = int.tryParse(text);
  if (number != null) return number <= 0 ? 'before' : 'after';
  if (text.startsWith('before')) return 'before';
  return 'after';
}

/// ST `role`: 0 = system, 1 = user, 2 = assistant.
String _role(dynamic value) {
  if (value is num) {
    switch (value.toInt()) {
      case 1:
        return 'user';
      case 2:
        return 'assistant';
    }
    return 'system';
  }
  final text = _text(value).toLowerCase();
  if (text == '1' || text == 'user' || text == 'human') return 'user';
  if (text == '2' || text == 'assistant' || text == 'ai') return 'assistant';
  return 'system';
}

int _roleIndex(String role) {
  switch (role) {
    case 'user':
      return 1;
    case 'assistant':
      return 2;
    default:
      return 0;
  }
}
