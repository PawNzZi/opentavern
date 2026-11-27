import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/card_import.dart';
import 'package:tavern_app/core/character_png.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/novel/novel_types.dart';
import 'package:tavern_app/core/novel/publish.dart';
import 'package:tavern_app/core/png_card_export.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

DemoCharacter _char({String lorebook = '未绑定'}) => DemoCharacter(
      name: '林晚',
      initial: '林',
      title: '旧城的女史官',
      tagline: '她记录一切被遗忘的事。',
      creator: '小说生成',
      version: '1.0',
      description: '旧城最后的女史官，随身带着一支不会干涸的笔。',
      greeting: '“你来晚了三年。不过没关系，故事才刚开始。”',
      tags: const ['奇幻', '悬疑'],
      lorebook: lorebook,
      preset: '默认',
      chats: 0,
      tokens: '30',
      colors: const [Color(0xFF2A2E5C), Color(0xFF6F6BB0)],
    );

Lorebook _book() => Lorebook(
      id: 'test-book',
      name: '旧城世界书',
      entries: [
        LoreEntry(
          id: 'e0',
          name: '王都',
          keys: const ['王都', '首都'],
          secondaryKeys: const ['国王'],
          content: '王都建在旧城的废墟之上，城墙由白色巨石砌成。',
          order: 10,
          position: 'before',
        ),
        LoreEntry(
          id: 'e1',
          name: '常驻世界观',
          content: '这个世界里魔法真实存在，但被史官院垄断。',
          constant: true,
          selective: true,
          order: 5,
          position: 'after',
          depth: 2,
          role: 'user',
          probability: 80,
          group: 'g1',
          groupWeight: 60,
          sticky: 3,
          cooldown: 2,
          delay: 1,
          caseSensitive: true,
          matchWholeWords: true,
          selectiveLogic: 'NOT_ANY',
          excludeRecursion: true,
          preventRecursion: true,
        ),
        LoreEntry(
          id: 'e2',
          name: '深渊',
          keys: const ['深渊'],
          content: '深渊在旧城地底低语，只有史官能听见。',
          enabled: false,
          order: 42,
          position: 'at_depth',
          depth: 7,
          role: 'assistant',
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('toCardJson character_book', () {
    test('without book keeps the previous shape (no character_book)', () {
      final json = _char(lorebook: '旧城世界书').toCardJson();
      final data = json['data'] as Map<String, dynamic>;
      expect(data.containsKey('character_book'), isFalse);
      expect(json.containsKey('character_book'), isFalse);
      expect((data['extensions'] as Map)['world'], '旧城世界书');
      expect(json['spec'], 'chara_card_v2');
      expect(data['first_mes'], '“你来晚了三年。不过没关系，故事才刚开始。”');
    });

    test('with book writes standard ST fields aligned with lore_io', () {
      final book = _book();
      final json = _char(lorebook: book.name).toCardJson(book: book);
      final data = json['data'] as Map<String, dynamic>;
      final cb = data['character_book'] as Map<String, dynamic>;
      expect(cb['name'], '旧城世界书');
      expect(cb['scan_depth'], isA<int>());
      expect(cb['token_budget'], isA<int>());
      expect(cb['recursive_scanning'], false);
      expect(cb['extensions'], isA<Map>());
      final entries = cb['entries'] as List;
      expect(entries.length, 3);
      final e0 = entries[0] as Map<String, dynamic>;
      expect(e0['keys'], ['王都', '首都']);
      expect(e0['secondary_keys'], ['国王']);
      expect(e0['insertion_order'], 10);
      expect(e0['position'], 0);
      expect(e0['enabled'], true);
      expect(e0['id'], 0);
      final e1 = entries[1] as Map<String, dynamic>;
      expect(e1['position'], 1);
      expect(e1['constant'], true);
      final ext1 = e1['extensions'] as Map<String, dynamic>;
      expect(ext1['depth'], 2);
      expect(ext1['role'], 1); // user
      expect(ext1['selective_logic'], 2); // NOT_ANY
      final e2 = entries[2] as Map<String, dynamic>;
      expect(e2['position'], 4); // at_depth
      expect(e2['enabled'], false);
      expect((e2['extensions'] as Map)['role'], 2); // assistant
      // 顶层 extensions.world 仍保留书名。
      expect((data['extensions'] as Map)['world'], '旧城世界书');
    });
  });

  group('PNG round trip', () {
    test('embedCardInPng → parseCharacterCard → parseCharacterBook', () async {
      final book = _book();
      final character = _char(lorebook: book.name);
      // 无 avatar → 渐变占位图，生成真实 PNG。
      final png = await buildCharacterCardPng(character);
      final embedded = embedCardInPng(png, character.toCardJson(book: book));

      final card = parseCharacterCard(embedded, 'card.png');
      expect(card, isNotNull);
      expect(card!.name, '林晚');
      expect(card.lorebook, '旧城世界书');

      final parsed = parseCharacterBook(card.rawJson, linked: card.name);
      expect(parsed, isNotNull);
      expect(parsed!.name, '旧城世界书');
      expect(parsed.linked, '林晚');
      expect(parsed.entries.length, 3);

      final e0 = parsed.entries[0];
      expect(e0.name, '王都');
      expect(e0.keys, ['王都', '首都']);
      expect(e0.secondaryKeys, ['国王']);
      expect(e0.content, '王都建在旧城的废墟之上，城墙由白色巨石砌成。');
      expect(e0.constant, false);
      expect(e0.order, 10);
      expect(e0.position, 'before');
      expect(e0.depth, 4);
      expect(e0.enabled, true);

      final e1 = parsed.entries[1];
      expect(e1.keys, isEmpty);
      expect(e1.constant, true);
      expect(e1.selective, true);
      expect(e1.order, 5);
      expect(e1.position, 'after');
      expect(e1.depth, 2);
      expect(e1.role, 'user');
      expect(e1.probability, 80);
      expect(e1.group, 'g1');
      expect(e1.groupWeight, 60);
      expect(e1.sticky, 3);
      expect(e1.cooldown, 2);
      expect(e1.delay, 1);
      expect(e1.caseSensitive, true);
      expect(e1.matchWholeWords, true);
      expect(e1.selectiveLogic, 'NOT_ANY');
      expect(e1.excludeRecursion, true);
      expect(e1.preventRecursion, true);

      final e2 = parsed.entries[2];
      expect(e2.keys, ['深渊']);
      expect(e2.content, '深渊在旧城地底低语，只有史官能听见。');
      expect(e2.enabled, false);
      expect(e2.order, 42);
      expect(e2.position, 'at_depth');
      expect(e2.depth, 7);
      expect(e2.role, 'assistant');
    });

    test('buildCharacterCardPng(book:) / buildCardPng carry the book', () async {
      final book = _book();
      final character = _char(lorebook: book.name);
      final png = await buildCharacterCardPng(character, book: book);
      final card = parseCharacterCard(png, 'card.png');
      expect(card, isNotNull);
      final parsed = parseCharacterBook(card!.rawJson, linked: card.name);
      expect(parsed, isNotNull);
      expect(parsed!.entries.length, 3);
      expect(parsed.entries[2].position, 'at_depth');

      final png2 = await buildCardPng(character, book: book);
      final card2 = parseCharacterCard(png2, 'card2.png');
      final parsed2 = parseCharacterBook(card2!.rawJson, linked: card2.name);
      expect(parsed2!.entries.length, 3);

      // 不带 book 的 PNG 不应解析出世界书。
      final plain = await buildCharacterCardPng(character);
      final plainCard = parseCharacterCard(plain, 'plain.png');
      expect(parseCharacterBook(plainCard!.rawJson), isNull);
    });
  });

  group('draftToLorebook', () {
    test('keeps only selected entries and maps fields', () {
      const result = GenResult(
        bookName: '旧城世界书',
        lore: [
          DraftLoreEntry(
            name: '王都',
            keys: ['王都', '首都'],
            secondaryKeys: ['国王'],
            content: '王都建在旧城的废墟之上。',
            order: 10,
          ),
          DraftLoreEntry(
            name: '未勾选',
            keys: ['丢弃'],
            content: '不应入库。',
            selected: false,
          ),
          DraftLoreEntry(
            name: '深渊',
            keys: ['深渊'],
            content: '深渊在旧城地底低语。',
            constant: true,
            order: 42,
            position: 'at_depth',
            depth: 7,
          ),
        ],
      );
      final book = draftToLorebook(result, linkedCharacterName: '林晚');
      expect(book.name, '旧城世界书');
      expect(book.linked, '林晚');
      expect(book.entries.length, 2);
      expect(book.entries[0].name, '王都');
      expect(book.entries[0].keys, ['王都', '首都']);
      expect(book.entries[0].secondaryKeys, ['国王']);
      expect(book.entries[0].content, '王都建在旧城的废墟之上。');
      expect(book.entries[0].order, 10);
      expect(book.entries[0].position, 'before');
      expect(book.entries[1].constant, true);
      expect(book.entries[1].order, 42);
      expect(book.entries[1].position, 'at_depth');
      expect(book.entries[1].depth, 7);
      // id 稳定：同一输入两次生成的 id 相同。
      final again = draftToLorebook(result, linkedCharacterName: '林晚');
      expect(again.id, book.id);
      expect(again.entries.map((e) => e.id), book.entries.map((e) => e.id));
    });

    test('empty bookName falls back to a sensible default', () {
      const result = GenResult(
        lore: [DraftLoreEntry(name: 'a', content: 'b')],
      );
      expect(
        draftToLorebook(result, linkedCharacterName: '林晚').name,
        '林晚 世界书',
      );
      expect(draftToLorebook(result).name, '小说世界书');
    });
  });

  group('draftToCharacter', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('novel_publish_test');
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    const draft = DraftCard(
      name: '林晚',
      description: '旧城最后的女史官。',
      personality: '冷静、好奇',
      scenario: '旧城图书馆',
      firstMes: '“你来晚了三年。”',
      mesExample: '<START>\n{{user}}: 你好\n{{char}}: 你好。',
      alternateGreetings: ['“又见面了。”'],
      systemPrompt: '扮演林晚。',
      creatorNotes: '旧城的女史官',
      tags: ['奇幻', '悬疑'],
    );

    test('maps fields; missing avatar file does not crash', () async {
      final missing = draft.copyWith(
        avatarPath: '${tmp.path}${Platform.pathSeparator}missing.png',
      );
      final c = await draftToCharacter(missing, bookName: '旧城世界书');
      expect(c.name, '林晚');
      expect(c.description, draft.description);
      expect(c.personality, '冷静、好奇');
      expect(c.scenario, '旧城图书馆');
      expect(c.greeting, draft.firstMes);
      expect(c.exampleDialogue, draft.mesExample);
      expect(c.alternateGreetings, ['“又见面了。”']);
      expect(c.systemPrompt, '扮演林晚。');
      expect(c.title, '旧城的女史官');
      expect(c.tags, ['奇幻', '悬疑']);
      expect(c.creator, '小说生成');
      expect(c.version, '1.0');
      expect(c.createdAt, isNotNull);
      expect(c.lorebook, '旧城世界书');
      expect(c.avatarBase64, isNull);

      final unbound = await draftToCharacter(draft);
      expect(unbound.lorebook, '未绑定');
    });

    test('existing avatar file is stored as base64', () async {
      final bytes = [137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3];
      final file = File('${tmp.path}${Platform.pathSeparator}avatar.png');
      await file.writeAsBytes(bytes);
      final c = await draftToCharacter(draft.copyWith(avatarPath: file.path));
      expect(c.avatarBase64, base64Encode(bytes));
    });
  });

  group('publishGenerated', () {
    const charName = '测试Publish林晚';
    const bookName = '测试Publish世界书';
    final store = AppStore.instance;

    void cleanup() {
      store.characters.removeWhere((c) => c.name == charName);
      store.lorebooks.removeWhere((b) => b.name == bookName);
    }

    setUp(cleanup);
    tearDown(cleanup);

    test('saves selected cards + book with two-way binding', () async {
      const result = GenResult(
        bookName: bookName,
        cards: [
          DraftCard(name: charName, firstMes: '“你来晚了三年。”'),
          DraftCard(name: '未勾选角色', selected: false),
        ],
        lore: [
          DraftLoreEntry(name: '王都', keys: ['王都'], content: '白色巨石之城。'),
          DraftLoreEntry(name: '丢弃', content: '不入库。', selected: false),
          DraftLoreEntry(
            name: '深渊',
            keys: ['深渊'],
            content: '地底低语。',
            position: 'at_depth',
            depth: 7,
          ),
        ],
      );
      final outcome = await publishGenerated(result, bookName: bookName);
      expect(outcome.characters.length, 1);
      expect(outcome.characters.first.name, charName);
      expect(outcome.replacedNames, isEmpty);
      expect(outcome.book, isNotNull);
      expect(outcome.book!.name, bookName);
      expect(outcome.book!.entries.length, 2);
      expect(outcome.book!.linked, charName);
      expect(outcome.characters.first.lorebook, bookName);
      expect(store.characters.any((c) => c.name == charName), isTrue);
      expect(store.lorebooks.any((b) => b.name == bookName), isTrue);
      expect(store.characters.any((c) => c.name == '未勾选角色'), isFalse);

      // 再发布一次：按 name 覆盖，且调用方能从 replacedNames 得知。
      final again = await publishGenerated(result, bookName: bookName);
      expect(again.replacedNames, [charName]);
      expect(
        store.characters.where((c) => c.name == charName).length,
        1,
      );
      expect(store.lorebooks.where((b) => b.name == bookName).length, 1);
    });

    test('no selected lore → no book, cards unbound', () async {
      const result = GenResult(
        cards: [DraftCard(name: charName)],
        lore: [DraftLoreEntry(name: 'x', content: 'y', selected: false)],
      );
      final outcome = await publishGenerated(result, bookName: bookName);
      expect(outcome.book, isNull);
      expect(outcome.characters.single.lorebook, '未绑定');
      expect(store.lorebooks.any((b) => b.name == bookName), isFalse);
    });
  });
}
