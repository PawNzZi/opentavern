import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/png_card_export.dart';

void main() {
  test('PNG export embeds chara and ccv3 chunks', () {
    final source = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
      '/x8AAusB9Y9Zl1sAAAAASUVORK5CYII=',
    );
    final out = embedCardInPng(source, {
      'spec': 'chara_card_v2',
      'data': {'name': 'Test'},
    });
    final text = latin1.decode(out, allowInvalid: true);
    expect(text, contains('chara'));
    expect(text, contains('ccv3'));
    expect(out.length, greaterThan(source.length));
    final again = embedCardInPng(out, {
      'spec': 'chara_card_v2',
      'data': {'name': 'Test2'},
    });
    final againText = latin1.decode(again, allowInvalid: true);
    expect('chara'.allMatches(againText).length, lessThan(4));
    final expected = base64Encode(
      utf8.encode(
        jsonEncode({
          'spec': 'chara_card_v2',
          'data': {'name': 'Test2'},
        }),
      ),
    );
    expect(againText, contains(expected));
  });
}

