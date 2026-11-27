import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/card_import.dart';
import 'package:tavern_app/core/character_png.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

DemoCharacter _char({String name = '林晚', String lorebook = '未绑定'}) =>
    DemoCharacter(
      name: name,
      initial: '林',
      title: '雾港的灯塔看守',
      tagline: '她记得每一次退潮。',
      creator: '小说生成',
      version: '1.0',
      description: '雾港最后一位灯塔看守，能听懂海雾里的低语。',
      greeting: '“潮水退了，你也该到了。”',
      tags: const ['奇幻', '悬疑'],
      lorebook: lorebook,
      preset: '默认',
      chats: 0,
      tokens: '30',
      colors: const [Color(0xFF1F3A4D), Color(0xFF5F8AA6)],
    );

Lorebook _book({
  required String id,
  String name = '雾港世界书',
  String? linked,
}) =>
    Lorebook(
      id: id,
      name: name,
      linked: linked,
      entries: [
        LoreEntry(
          id: '$id-e0',
          name: '灯塔',
          keys: const ['灯塔', '守塔人'],
          secondaryKeys: const ['夜航'],
          content: '灯塔建在雾港最北的礁石上，灯芯烧的是海鲸油。',
          order: 10,
          position: 'before',
        ),
        LoreEntry(
          id: '$id-e1',
          name: '常驻世界观',
          content: '雾港的潮汐被灯塔的火光牵引，火弱则潮涨。',
          constant: true,
          selective: true,
          order: 5,
          position: 'after',
          depth: 2,
          role: 'user',
        ),
        LoreEntry(
          id: '$id-e2',
          name: '深渊',
          keys: const ['深渊'],
          content: '深渊藏在雾港海沟底部，只在退潮时低语。',
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

  final store = AppStore.instance;

  // 只清理本文件注册的书，避免污染 AppStore 单例的其它数据。
  void cleanup() {
    store.lorebooks.removeWhere((b) => b.id.startsWith('wb-test-'));
  }

  group('lorebookForCharacter', () {
    setUp(cleanup);
    tearDown(cleanup);

    test('正向绑定：按书名或 ID 命中', () {
      final book = _book(id: 'wb-test-name');
      store.lorebooks.add(book);

      expect(store.lorebookForCharacter(_char(lorebook: book.name)), same(book));
      expect(store.lorebookForCharacter(_char(lorebook: book.id)), same(book));
    });

    test('正向绑定优先于反向绑定', () {
      final forward = _book(id: 'wb-test-forward', name: '正向书');
      final reverse = _book(id: 'wb-test-reverse', name: '反向书', linked: '林晚');
      store.lorebooks..add(forward)..add(reverse);

      expect(
        store.lorebookForCharacter(_char(lorebook: '正向书')),
        same(forward),
      );
    });

    test('反向绑定兜底：lorebook 为「未绑定」/空时按 linked 找书', () {
      final book = _book(id: 'wb-test-linked', linked: '林晚');
      store.lorebooks.add(book);

      expect(store.lorebookForCharacter(_char(lorebook: '未绑定')), same(book));
      expect(store.lorebookForCharacter(_char(lorebook: '')), same(book));
    });

    test('反向绑定的书没有条目时不兜底', () {
      store.lorebooks.add(
        Lorebook(
          id: 'wb-test-empty',
          name: '空世界书',
          linked: '林晚',
          entries: const [],
        ),
      );

      expect(store.lorebookForCharacter(_char(lorebook: '未绑定')), isNull);
    });

    test('未绑定（无正向无反向）返回 null', () {
      expect(store.lorebookForCharacter(_char(lorebook: '未绑定')), isNull);
      expect(store.lorebookForCharacter(_char(lorebook: '')), isNull);
      // 指向不存在的书名，且无反向绑定。
      expect(store.lorebookForCharacter(_char(lorebook: '不存在的书')), isNull);
    });

    test('「未绑定」不作为书名参与匹配', () {
      final book = _book(id: 'wb-test-unbound', name: '未绑定');
      store.lorebooks.add(book);

      expect(store.lorebookForCharacter(_char(lorebook: '未绑定')), isNull);
    });
  });

  group('PNG 角色卡导出带世界书', () {
    setUp(cleanup);
    tearDown(cleanup);

    test('buildCharacterCardPng(book:) 经 parseCharacterCard/parseCharacterBook 读回', () async {
      final book = _book(id: 'wb-test-rt');
      final character = _char(lorebook: book.name);

      // 无 avatar → 渐变占位图，生成真实 PNG。
      final png = await buildCharacterCardPng(character, book: book);
      final card = parseCharacterCard(png, 'card.png');
      expect(card, isNotNull);
      expect(card!.name, '林晚');
      expect(card.lorebook, '雾港世界书');

      final parsed = parseCharacterBook(card.rawJson, linked: card.name);
      expect(parsed, isNotNull);
      expect(parsed!.name, '雾港世界书');
      expect(parsed.entries.length, 3);

      final e0 = parsed.entries[0];
      expect(e0.name, '灯塔');
      expect(e0.keys, ['灯塔', '守塔人']);
      expect(e0.secondaryKeys, ['夜航']);
      expect(e0.content, '灯塔建在雾港最北的礁石上，灯芯烧的是海鲸油。');
      expect(e0.constant, isFalse);
      expect(e0.order, 10);
      expect(e0.position, 'before');
      expect(e0.depth, 4);
      expect(e0.enabled, isTrue);

      final e1 = parsed.entries[1];
      expect(e1.name, '常驻世界观');
      expect(e1.constant, isTrue);
      expect(e1.selective, isTrue);
      expect(e1.order, 5);
      expect(e1.position, 'after');
      expect(e1.depth, 2);
      expect(e1.role, 'user');

      final e2 = parsed.entries[2];
      expect(e2.name, '深渊');
      expect(e2.keys, ['深渊']);
      expect(e2.content, '深渊藏在雾港海沟底部，只在退潮时低语。');
      expect(e2.enabled, isFalse);
      expect(e2.order, 42);
      expect(e2.position, 'at_depth');
      expect(e2.depth, 7);
      expect(e2.role, 'assistant');
    });

    test('lorebookForCharacter 解析出的书随 PNG 一起导出（导出调用点行为）', () async {
      final book = _book(id: 'wb-test-e2e', linked: '林晚');
      store.lorebooks.add(book);

      // 正向绑定（书名）解析出的书嵌入 PNG。
      final bound = _char(lorebook: '雾港世界书');
      final resolved = store.lorebookForCharacter(bound);
      expect(resolved, same(book));
      final png = await buildCharacterCardPng(bound, book: resolved);
      final card = parseCharacterCard(png, 'card.png');
      expect(card, isNotNull);
      final parsed = parseCharacterBook(card!.rawJson, linked: card.name);
      expect(parsed, isNotNull);
      expect(parsed!.entries.length, 3);
      expect(parsed.entries[2].position, 'at_depth');

      // 未绑定角色：helper 返回 null，导出的 PNG 不含世界书。
      // （换一个角色名，避免上面 linked: '林晚' 的书反向兜底命中。）
      final unbound = _char(name: '沈溯', lorebook: '不存在的书');
      final noBook = store.lorebookForCharacter(unbound);
      expect(noBook, isNull);
      final plain = await buildCharacterCardPng(unbound, book: noBook);
      final plainCard = parseCharacterCard(plain, 'plain.png');
      expect(plainCard, isNotNull);
      expect(parseCharacterBook(plainCard!.rawJson), isNull);
    });
  });
}
