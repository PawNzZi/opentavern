import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('renaming a character replaces it and updates sessions', () async {
    const oldChar = DemoCharacter(
      name: '旧名',
      initial: '旧',
      title: '',
      tagline: '',
      creator: '',
      version: '1',
      description: '',
      greeting: '',
      tags: [],
      lorebook: '',
      preset: '',
      chats: 0,
      tokens: '0',
      colors: [],
    );
    final store = AppStore.instance;
    store.characters
      ..clear()
      ..add(oldChar);
    store.sessions
      ..clear()
      ..add(ChatSession(
        id: 'rename-session',
        characterName: '旧名',
        title: 't',
      ));
    await store.replaceCharacter(
      oldChar.copyWith(name: '新名'),
      previousName: '旧名',
    );
    expect(store.characters.length, 1);
    expect(store.characters.first.name, '新名');
    expect(store.sessions.first.characterName, '新名');
    store.characters.clear();
    store.sessions.clear();
  });
}
