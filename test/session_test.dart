import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('sessions can be created and branched independently', () {
    final character = DemoCharacter(
      name: '会话测试',
      initial: '测',
      title: '',
      tagline: '',
      creator: '',
      version: '',
      description: '',
      greeting: '你好',
      tags: const [],
      lorebook: '',
      preset: '',
      chats: 0,
      tokens: '',
      colors: const [],
    );
    final store = AppStore.instance;
    store.sessions.clear();
    final first = store.createSession(character);
    final second = store.createSession(character);
    expect(store.sessions.length, 2);
    expect(first.id, isNot(second.id));
    first.messages.add(ChatMessage(id: 'm1', text: 'one'));
    first.messages.add(ChatMessage(id: 'm2', text: 'two'));
    final branch = store.branchSession(first, throughIndex: 1);
    expect(branch.messages.length, 2);
    expect(branch.title, contains('分支'));
    expect(branch.id, isNot(first.id));
  });
}
