import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/macros.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/prompt.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

DemoCharacter _character({
  String name = '契约角色',
  String description = '',
  String personality = '',
  String scenario = '',
  String lorebook = '',
  String preset = '',
}) =>
    DemoCharacter(
      name: name,
      initial: '契',
      title: '',
      tagline: '',
      creator: '',
      version: '',
      description: description,
      personality: personality,
      scenario: scenario,
      greeting: '',
      tags: const [],
      lorebook: lorebook,
      preset: preset,
      chats: 0,
      tokens: '',
      colors: const [],
    );

ChatSession _session(
  DemoCharacter character, {
  List<ChatMessage> messages = const [],
}) =>
    ChatSession(
      id: 'session-${character.name}',
      characterName: character.name,
      title: 't',
      messages: messages,
    );

void main() {
  final store = AppStore.instance;

  setUp(() {
    store.presets.clear();
    store.activePresetId = '';
    store.lorebooks.clear();
  });

  tearDown(() {
    store.presets.clear();
    store.activePresetId = '';
    store.lorebooks.clear();
  });

  test('a bound preset with an empty main prompt sends no main prompt', () {
    store.presets.add(
      PromptPreset(id: 'empty-main', name: '空主提示词', mainPrompt: ''),
    );
    store.activePresetId = 'empty-main';

    final character = _character();
    final built = PromptBuilder.build(
      character: character,
      session: _session(
        character,
        messages: [ChatMessage(id: 'm1', text: '你好', isUser: true)],
      ),
      settings: const AppSettings(mainPrompt: 'GLOBAL_MAIN_PROMPT'),
    );

    expect(built.sections.containsKey('main'), isFalse);
    expect(
      built.messages.first['content'].toString(),
      isNot(contains('GLOBAL_MAIN_PROMPT')),
    );
    expect(built.mainSource, contains('空主提示词'));
  });

  test('world book content expands macros before it reaches the prompt', () {
    final character = _character(lorebook: '契约书');
    store.lorebooks.add(
      Lorebook(
        id: 'book-contract',
        name: '契约书',
        linked: character.name,
        entries: [
          LoreEntry(
            id: 'entry-contract',
            keys: const ['契约'],
            content: '{{user}} 与 {{char}} 签下了契约。',
          ),
        ],
      ),
    );

    final built = PromptBuilder.build(
      character: character,
      session: _session(
        character,
        messages: [ChatMessage(id: 'm1', text: '契约', isUser: true)],
      ),
      settings: const AppSettings(userName: '阿明'),
    );

    final system = built.messages.first['content'].toString();
    expect(system, contains('阿明 与 契约角色 签下了契约。'));
    expect(system, isNot(contains('{{user}}')));
    expect(system, isNot(contains('{{char}}')));
    expect(built.lore.injected.length, 1);
  });

  test('chat history expands macros before it is sent', () {
    final character = _character();

    final built = PromptBuilder.build(
      character: character,
      session: _session(
        character,
        messages: [
          ChatMessage(id: 'm1', text: '{{user}} 坐下。', isUser: true),
          ChatMessage(id: 'm2', text: '{{char}} 抬起头。'),
        ],
      ),
      settings: const AppSettings(
        userName: '阿明',
        mainPrompt: '',
      ),
    );

    final contents = built.messages.map((m) => m['content'].toString()).join('\n');
    expect(contents, contains('阿明 坐下。'));
    expect(contents, contains('契约角色 抬起头。'));
    expect(contents, isNot(contains('{{user}}')));
    expect(contents, isNot(contains('{{char}}')));
  });

  test('at_depth world book entries expand macros too', () {
    final character = _character();
    store.lorebooks.add(
      Lorebook(
        id: 'book-depth',
        name: '深度书',
        linked: character.name,
        entries: [
          LoreEntry(
            id: 'entry-depth',
            keys: const ['契约'],
            content: '{{char}} 记得 {{user}}。',
            position: 'at_depth',
            depth: 1,
          ),
        ],
      ),
    );

    final built = PromptBuilder.build(
      character: character,
      session: _session(
        character,
        messages: [
          ChatMessage(id: 'm1', text: '契约', isUser: true),
          ChatMessage(id: 'm2', text: '嗯'),
        ],
      ),
      settings: const AppSettings(userName: '阿明'),
    );

    final contents = built.messages.map((m) => m['content'].toString()).join('\n');
    expect(contents, contains('契约角色 记得 阿明。'));
    expect(contents, isNot(contains('{{user}}')));
  });

  test('world book keys also match the character card fields', () {
    final character = _character(
      description: '他守护着白塔。',
      lorebook: '白塔书',
    );
    store.lorebooks.add(
      Lorebook(
        id: 'book-tower',
        name: '白塔书',
        entries: [
          LoreEntry(id: 'entry-tower', keys: const ['白塔'], content: '白塔很高。'),
        ],
      ),
    );

    final built = PromptBuilder.build(
      character: character,
      session: _session(
        character,
        messages: [ChatMessage(id: 'm1', text: '你好', isUser: true)],
      ),
      settings: const AppSettings(),
    );

    expect(built.messages.first['content'], contains('白塔很高。'));
    expect(built.lore.matched.length, 1);
  });

  test('an unbound non-global world book is reported as out of scope', () {
    final character = _character();
    store.lorebooks.add(
      Lorebook(
        id: 'book-inert',
        name: '未绑定书',
        entries: [
          LoreEntry(id: 'entry-inert', keys: const ['契约'], content: '未绑定内容。'),
        ],
      ),
    );

    final built = PromptBuilder.build(
      character: character,
      session: _session(
        character,
        messages: [ChatMessage(id: 'm1', text: '契约', isUser: true)],
      ),
      settings: const AppSettings(),
    );

    expect(built.messages.first['content'], isNot(contains('未绑定内容。')));
    expect(built.lore.scopeBooks, isEmpty);
    expect(built.lore.scopeEntries, 0);
    expect(built.lore.matched, isEmpty);
  });

  test('entries dropped by the lore token budget are still reported', () {
    final character = _character(lorebook: '预算书');
    store.lorebooks.add(
      Lorebook(
        id: 'book-budget',
        name: '预算书',
        linked: character.name,
        entries: [
          LoreEntry(
            id: 'entry-budget',
            keys: const ['契约'],
            content: '这是一条很长很长、绝对超过一个 token 的条目内容。',
          ),
        ],
      ),
    );

    final built = PromptBuilder.build(
      character: character,
      session: _session(
        character,
        messages: [ChatMessage(id: 'm1', text: '契约', isUser: true)],
      ),
      settings: const AppSettings(loreMaxTokens: 1),
    );

    expect(built.messages.first['content'], isNot(contains('绝对超过')));
    expect(built.lore.matched.length, 1);
    expect(built.lore.injected, isEmpty);
    expect(built.lore.droppedByBudget, 1);
  });

  test('display expansion only touches identity macros', () {
    final text = MacroEngine.expandIdentity(
      '{{user}} 看着 {{char}}，{{random::a,b}} 与 {{time}} 保持不变。',
      charName: '契约角色',
      userName: '阿明',
    );
    expect(text, startsWith('阿明 看着 契约角色，'));
    expect(text, contains('{{random::a,b}}'));
    expect(text, contains('{{time}}'));
  });
}
