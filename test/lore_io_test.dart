import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/lore_io.dart';
import 'package:tavern_app/core/models.dart';

void main() {
  test('world info JSON round trip', () {
    final book = Lorebook(
      id: 'b',
      name: '测试世界书',
      entries: [
        LoreEntry(
          id: 'e',
          name: '王都',
          keys: const ['王都', '雨'],
          content: '王都常年下雨。',
          constant: true,
          order: 42,
        ),
      ],
    );
    final json = jsonEncode(lorebookToWorldJson(book));
    final parsed = parseWorldInfo(
      Uint8List.fromList(utf8.encode(json)),
      'test.json',
    );
    expect(parsed, isNotNull);
    expect(parsed!.name, '测试世界书');
    expect(parsed.entries.length, 1);
    expect(parsed.entries.first.keys, contains('王都'));
    expect(parsed.entries.first.constant, isTrue);
    expect(parsed.entries.first.order, 42);
  });
}
