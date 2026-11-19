import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/prompt.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

void main() {
  test('active preset contributes main prompt and extra entries', () {
    final character = DemoCharacter(
      name: '预设测试',
      initial: '预',
      title: '',
      tagline: '',
      creator: '',
      version: '',
      description: '',
      greeting: '',
      tags: const [],
      lorebook: '',
      preset: '',
      chats: 0,
      tokens: '',
      colors: const [],
    );
    final preset = PromptPreset(
      id: 'preset-test',
      name: 'Test',
      mainPrompt: 'PRESET MAIN',
      entries: [
        PromptEntry(
          id: 'e1',
          name: 'Style',
          content: 'EXTRA STYLE',
          role: 'system',
        ),
      ],
    );
    final store = AppStore.instance;
    store.presets
      ..clear()
      ..add(preset);
    store.activePresetId = preset.id;
    final built = PromptBuilder.build(
      character: character,
      session: ChatSession(
        id: 's1',
        characterName: character.name,
        title: 'test',
        messages: const [],
      ),
      settings: const AppSettings(),
    );
    final system = built.messages.first['content']!;
    expect(system, contains('PRESET MAIN'));
    expect(system, contains('EXTRA STYLE'));
  });
}
