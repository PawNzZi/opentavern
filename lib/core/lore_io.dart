import 'dart:convert';
import 'dart:typed_data';

import 'models.dart';

/// Reads SillyTavern `worlds/<name>.json` style files.
Lorebook? parseWorldInfo(Uint8List bytes, String fileName) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    final entriesRaw = map['entries'];
    final entries = <LoreEntry>[];
    if (entriesRaw is Map) {
      for (final entry in entriesRaw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final parsed = _entry(Map<String, dynamic>.from(value), '${entry.key}');
        if (parsed != null) entries.add(parsed);
      }
    } else if (entriesRaw is List) {
      for (var i = 0; i < entriesRaw.length; i++) {
        final value = entriesRaw[i];
        if (value is! Map) continue;
        final parsed = _entry(Map<String, dynamic>.from(value), '$i');
        if (parsed != null) entries.add(parsed);
      }
    }
    final name = (map['name'] ?? fileName.replaceAll('.json', '')).toString();
    return Lorebook(
      id: 'book-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      entries: entries,
    );
  } catch (_) {
    return null;
  }
}

LoreEntry? _entry(Map<String, dynamic> map, String fallbackId) {
  final content = (map['content'] ?? '').toString().trim();
  if (content.isEmpty) return null;
  final keys = _keys(map['key'] ?? map['keys']);
  if (keys.isEmpty) return null;
  final secondary = _keys(map['keysecondary'] ?? map['secondary_keys']);
  final position = map['position'];
  final depth = (map['depth'] as num?)?.toInt() ?? 4;
  return LoreEntry(
    id: 'entry-${DateTime.now().microsecondsSinceEpoch}-$fallbackId',
    name: (map['comment'] ?? map['name'] ?? keys.first).toString(),
    keys: keys,
    secondaryKeys: secondary,
    content: content,
    enabled: map['disable'] != true,
    constant: map['constant'] == true,
    selective: map['selective'] != false,
    order: (map['order'] as num?)?.toInt() ?? 100,
    position: (position == 1 || position == 'after' || position == 'after_char')
        ? 'after'
        : 'before',
    depth: depth,
    role: 'system',
    comment: (map['comment'] ?? '').toString(),
  );
}

List<String> _keys(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
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

Map<String, dynamic> lorebookToWorldJson(Lorebook book) {
  final entries = <String, dynamic>{};
  for (var i = 0; i < book.entries.length; i++) {
    final e = book.entries[i];
    entries['$i'] = {
      'uid': i,
      'key': e.keys,
      'keysecondary': e.secondaryKeys,
      'comment': e.name,
      'content': e.content,
      'constant': e.constant,
      'selective': e.selective,
      'order': e.order,
      'position': e.position == 'after' ? 1 : 0,
      'disable': !e.enabled,
      'depth': e.depth,
      'role': 0,
    };
  }
  return {
    'name': book.name,
    'entries': entries,
  };
}
