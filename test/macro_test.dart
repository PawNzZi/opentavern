import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/macros.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('macros expand character, user, variables and random', () {
    final character = DemoCharacter(
      name: 'Seraphina',
      initial: 'S',
      title: '',
      tagline: '',
      creator: '',
      version: '',
      description: '占星师',
      greeting: '',
      tags: const [],
      lorebook: '',
      preset: '',
      chats: 0,
      tokens: '',
      colors: const [],
    );
    final vars = <String, String>{};
    final out = MacroEngine.expand(
      '{{char}} / {{user}} / {{setvar::mood::rain}} / {{getvar::mood}}',
      character: character,
      settings: const AppSettings(userName: '旅人'),
      variables: vars,
    );
    expect(out, contains('Seraphina'));
    expect(out, contains('旅人'));
    expect(out, contains('rain'));
    expect(vars['mood'], 'rain');
  });
}
