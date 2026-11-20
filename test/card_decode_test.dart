import 'package:flutter_test/flutter_test.dart';
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
}
