/// 「小说/文档 → 角色卡 + 世界书」的导出与入库。
///
/// 全部 API 不依赖 UI：草稿 → DemoCharacter / Lorebook 的映射是纯数据转换
/// （立绘只读本地文件），入库走 [AppStore]，PNG 导出走 `character_png.dart`。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;

import '../../data/demo.dart';
import '../character_png.dart';
import '../models.dart';
import '../store.dart';
import 'novel_types.dart';

/// [publishGenerated] 的结果：实际保存的角色与世界书。
class PublishOutcome {
  const PublishOutcome({
    required this.characters,
    this.book,
    this.replacedNames = const [],
  });

  /// 已保存（selected）的角色卡，顺序与草稿一致。
  final List<DemoCharacter> characters;

  /// 已保存的世界书；没有 selected 条目时为 null。
  final Lorebook? book;

  /// 因同名而被覆盖的既有角色名（`addCharacter` 按 name 覆盖）。
  final List<String> replacedNames;
}

/// 把一张成稿草稿映射为 [DemoCharacter]。
///
/// [bookName] 非空时绑定该世界书名，否则为「未绑定」。立绘路径非空且文件存在
/// 时读字节转 base64（JPEG 也可以，导出 PNG 时会再解码转码）；文件不存在或
/// 读取失败时保持 null，导出走渐变占位图。
Future<DemoCharacter> draftToCharacter(
  DraftCard draft, {
  String bookName = '',
}) async {
  String? avatarBase64;
  if (draft.avatarPath.trim().isNotEmpty) {
    try {
      final file = File(draft.avatarPath);
      if (await file.exists()) {
        avatarBase64 = base64Encode(await file.readAsBytes());
      }
    } catch (_) {
      avatarBase64 = null;
    }
  }
  final name = draft.name.trim().isEmpty ? '未命名' : draft.name.trim();
  return DemoCharacter(
    name: name,
    initial: String.fromCharCode(name.runes.first),
    title: draft.creatorNotes,
    tagline: draft.description.split('\n').first,
    creator: '小说生成',
    version: '1.0',
    description: draft.description,
    greeting: draft.firstMes,
    tags: draft.tags,
    lorebook: bookName.trim().isEmpty ? '未绑定' : bookName.trim(),
    preset: '默认',
    chats: 0,
    tokens:
        '${((draft.description.length + draft.firstMes.length) / 2).round()}',
    colors: const [
      Color(0xFF2A2E5C),
      Color(0xFF6F6BB0),
      Color(0xFF14152B),
    ],
    personality: draft.personality,
    scenario: draft.scenario,
    exampleDialogue: draft.mesExample,
    systemPrompt: draft.systemPrompt,
    alternateGreetings: draft.alternateGreetings,
    avatarBase64: avatarBase64,
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
}

/// 把生成结果里 **selected** 的世界书条目映射为 [Lorebook]。
///
/// 书名用 `result.bookName`；为空时退回到「<角色名> 世界书」或「小说世界书」
/// （更贴切的书名应由调用方通过 `GenResult.bookName` 传入）。id 由书名与
/// 序号派生，同一本书重复发布时稳定，`addLorebook` 会按 id 原地覆盖。
Lorebook draftToLorebook(
  GenResult result, {
  String linkedCharacterName = '',
}) {
  final name = result.bookName.trim().isNotEmpty
      ? result.bookName.trim()
      : linkedCharacterName.trim().isNotEmpty
          ? '${linkedCharacterName.trim()} 世界书'
          : '小说世界书';
  final selected = result.lore.where((e) => e.selected).toList();
  return Lorebook(
    id: 'novel-book-$name',
    name: name,
    linked: linkedCharacterName.trim().isEmpty ? null : linkedCharacterName,
    entries: [
      for (var i = 0; i < selected.length; i++)
        LoreEntry(
          id: 'novel-entry-$name-$i',
          name: selected[i].name,
          keys: selected[i].keys,
          secondaryKeys: selected[i].secondaryKeys,
          content: selected[i].content,
          constant: selected[i].constant,
          order: selected[i].order,
          position: selected[i].position,
          depth: selected[i].depth,
        ),
    ],
  );
}

/// 把生成结果落地：只保存 selected 的卡与条目，建立双向绑定并写入 [AppStore]。
///
/// * 有 selected 世界书条目才建书；书的 `linked` 指向第一张保存的卡，每张卡的
///   `lorebook` 指向书名。
/// * 同名角色沿用 `addCharacter` 的按 name 覆盖语义，被覆盖的名字放进
///   [PublishOutcome.replacedNames] 供调用方提示。
Future<PublishOutcome> publishGenerated(
  GenResult result, {
  required String bookName,
}) async {
  final store = AppStore.instance;
  final selectedCards = result.cards.where((c) => c.selected).toList();
  final firstName = selectedCards.isEmpty
      ? ''
      : selectedCards.first.name.trim().isEmpty
          ? '未命名'
          : selectedCards.first.name.trim();

  final effectiveName = bookName.trim().isNotEmpty
      ? bookName.trim()
      : result.bookName.trim().isNotEmpty
          ? result.bookName.trim()
          : firstName.isNotEmpty
              ? '$firstName 世界书'
              : '小说世界书';

  Lorebook? book;
  if (result.lore.any((e) => e.selected)) {
    book = draftToLorebook(
      GenResult(
        bookName: effectiveName,
        cards: result.cards,
        lore: result.lore,
      ),
      linkedCharacterName: firstName,
    );
    await store.addLorebook(book);
  }

  final replacedNames = <String>[];
  final saved = <DemoCharacter>[];
  for (final draft in selectedCards) {
    final character = await draftToCharacter(
      draft,
      bookName: book == null ? '' : book.name,
    );
    if (store.characters.any((c) => c.name == character.name)) {
      replacedNames.add(character.name);
    }
    await store.addCharacter(character);
    saved.add(character);
  }
  return PublishOutcome(
    characters: saved,
    book: book,
    replacedNames: replacedNames,
  );
}

/// 导出「角色卡 + 世界书」合一的 PNG（薄封装，见 [buildCharacterCardPng]）。
Future<Uint8List> buildCardPng(
  DemoCharacter character, {
  Lorebook? book,
}) =>
    buildCharacterCardPng(character, book: book);
