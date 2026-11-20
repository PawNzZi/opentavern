import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/card_import.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('V2 card tags accept dynamic lists', () {
    final card = DemoCharacter.fromCardJson({
      'data': {
        'name': '测试角色',
        'tags': <dynamic>['奇幻', 42],
        'alternate_greetings': <dynamic>['第二开场'],
        'first_mes': '你好',
      },
    });
    expect(card.tags, ['奇幻', '42']);
    expect(card.alternateGreetings, ['第二开场']);
  });

  test('constant character book entries without keys are kept', () {
    final book = parseCharacterBook({
      'data': {
        'character_book': {
          'name': '测试书',
          'entries': [
            {
              'keys': <dynamic>[],
              'content': '常驻设定',
              'constant': true,
              'comment': '常驻',
            },
          ],
        },
      },
    });
    expect(book, isNotNull);
    expect(book!.entries.length, 1);
    expect(book.entries.first.constant, isTrue);
  });
}
