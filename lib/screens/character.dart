import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../core/character_png.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';
import 'automation.dart';
import 'character_editor.dart';
import 'lore.dart';
import 'presets.dart';
import 'chat.dart';

/// 复制角色时生成不会互相覆盖的名字。
String _uniqueCopyName(String base) {
  final names = AppStore.instance.characters.map((c) => c.name).toSet();
  if (!names.contains('$base 副本')) return '$base 副本';
  var index = 2;
  while (names.contains('$base 副本 $index')) {
    index++;
  }
  return '$base 副本 $index';
}

/// 复制角色卡与设定并真正落盘；关闭入口时可以顺带返回上一页。
Future<void> _copyCharacter(
  BuildContext context,
  DemoCharacter character, {
  bool closeAfter = false,
}) async {
  final copy = character.copyWith(
    name: _uniqueCopyName(character.name),
    chats: 0,
    unread: 0,
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
  await AppStore.instance.addCharacter(copy);
  if (!context.mounted) return;
  showTavernToast(context, '已复制为「${copy.name}」');
  if (closeAfter) Navigator.of(context).pop();
}

String _formatDate(int? timestamp) {
  if (timestamp == null) return '未知';
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({
    super.key,
    required this.character,
    this.initialTab = 0,
  });

  final DemoCharacter character;
  final int initialTab;

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  late int _tab = widget.initialTab;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_syncStore);
  }

  void _syncStore() {
    if (mounted) setState(() {});
  }

  /// The store replaces character objects on every edit/favorite toggle, so
  /// always render the newest copy instead of the one passed at push time.
  DemoCharacter _resolveCharacter() {
    final store = AppStore.instance;
    final createdAt = widget.character.createdAt;
    if (createdAt != null) {
      for (final candidate in store.characters) {
        if (candidate.createdAt == createdAt) return candidate;
      }
    }
    for (final candidate in store.characters) {
      if (candidate.name == widget.character.name) return candidate;
    }
    return widget.character;
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_syncStore);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = _resolveCharacter();
    final width = MediaQuery.sizeOf(context).width;
    final chatCount = AppStore.instance.sessions
        .where((s) => s.characterName == c.name)
        .length;
    return TavernScaffold(
      intensity: 1.2,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 410,
            child: Portrait(
              initial: c.initial,
              colors: c.colors,
              avatarBase64: c.avatarBase64,
              radius: 0,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 420,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      p.canvasTop.withValues(alpha: .15),
                      p.canvasTop.withValues(alpha: .86),
                      p.canvasTop,
                    ],
                    stops: const [0, .45, .82, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      p.canvasTop.withValues(alpha: .78),
                      p.canvasTop.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 292, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHARACTER · V${c.version}',
                    style: appText(
                      10,
                      FontWeight.w600,
                      p.amber,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.name,
                    style: appText(
                      40,
                      FontWeight.w700,
                      p.textPrimary,
                      letterSpacing: -1.6,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'by ${c.creator} · ${c.title}',
                    style: appText(13, FontWeight.w400, p.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final t in c.tags) GlassPill(label: t, height: 30),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _Stats(character: c, chatCount: chatCount),
                  const SizedBox(height: 16),
                  GlassPrimaryButton(
                    label: '开始新对话',
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: () => _startChat(context, c),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Glass(
                          radius: 22,
                          blur: 20,
                          shadow: false,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onTap: () => _continueChat(context, c),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 15,
                                color: p.textSecondary,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                '继续上次对话',
                                style: appText(
                                  13,
                                  FontWeight.w500,
                                  p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GlassCircleButton(
                        icon: Icons.edit_outlined,
                        size: 44,
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => CharacterEditorPage(
                                character: c,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailTabs(
                    index: _tab,
                    onChanged: (i) {
                      setState(() => _tab = i);
                    },
                  ),
                  const SizedBox(height: 6),
                  _tabContent(context, c, width),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      c.createdAt == null
                          ? '本地角色 · ${c.tokens} tokens'
                          : '本地角色 · 创建于 ${_formatDate(c.createdAt)} · ${c.tokens} tokens',
                      style: appText(10.5, FontWeight.w400, p.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: SizedBox(
                      width: width * .3,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: p.textTertiary.withValues(alpha: .5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                children: [
                  GlassCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 40,
                    iconSize: 15,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const Spacer(),
                  GlassCircleButton(
                    icon: c.favorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 40,
                    iconSize: 18,
                    iconColor: c.favorite ? p.amber : p.textPrimary,
                    tint: c.favorite ? p.amber : null,
                    onTap: () async {
                      final latest = _resolveCharacter();
                      await AppStore.instance.addCharacter(
                        latest.copyWith(favorite: !latest.favorite),
                      );
                      if (context.mounted) {
                        showTavernToast(
                          context,
                          latest.favorite
                              ? '已取消收藏 ${latest.name}'
                              : '已收藏 ${latest.name}',
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  GlassCircleButton(
                    icon: Icons.more_horiz_rounded,
                    size: 40,
                    onTap: () => _showMore(context, c),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCharacterPng(
    BuildContext context,
    DemoCharacter character,
  ) async {
    final bytes = await buildCharacterCardPng(character);
    final uri = await FilePickerPlatform.instance.saveFile(
      fileName: '${character.name}.png',
      bytes: bytes,
      mimeType: 'image/png',
      dialogTitle: '导出角色卡 PNG',
    );
    if (!context.mounted) return;
    showTavernToast(context, uri == null ? '已取消导出' : 'PNG 角色卡已导出');
  }

  Future<void> _exportCharacterMenu(
    BuildContext context,
    DemoCharacter character,
  ) async {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => _ExportCardPage(
          character: character,
          onPng: () => _exportCharacterPng(context, character),
          onJson: () => _exportCharacterJson(context, character),
        ),
      ),
    );
  }

  Future<void> _exportCharacterJson(
    BuildContext context,
    DemoCharacter character,
  ) async {
    final bytes = Uint8List.fromList(
      utf8.encode(jsonEncode(character.toCardJson())),
    );
    final uri = await FilePickerPlatform.instance.saveFile(
      fileName: '${character.name}.json',
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: '导出角色卡 JSON',
    );
    if (!context.mounted) return;
    showTavernToast(context, uri == null ? '已取消导出' : '角色卡已导出');
  }

  void _showMore(BuildContext context, DemoCharacter character) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => _CharacterMorePage(
          character: character,
          onExport: () => _exportCharacterMenu(context, character),
        ),
      ),
    );
  }

  Future<void> _continueChat(BuildContext context, DemoCharacter c) async {
    final sessions = AppStore.instance.sessions
        .where((s) => s.characterName == c.name)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (sessions.isEmpty) {
      await _startChat(context, c);
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatScreen(
          character: c,
          sessionId: sessions.first.id,
        ),
      ),
    );
  }

  Future<void> _startChat(BuildContext context, DemoCharacter c) async {
    final greetings = <String>[
      if (c.greeting.trim().isNotEmpty) c.greeting,
      ...c.alternateGreetings.where((g) => g.trim().isNotEmpty),
    ];
    String? chosen;
    if (greetings.length > 1) {
      final index = await Navigator.of(context).push<int>(
        CupertinoPageRoute(
          builder: (_) => _GreetingPickerPage(
            character: c,
            greetings: greetings,
          ),
        ),
      );
      if (index == null) return;
      chosen = greetings[index];
    } else if (greetings.isNotEmpty) {
      chosen = greetings.first;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatScreen(
          character: c,
          newSession: true,
          initialGreeting: chosen,
        ),
      ),
    );
  }

  Widget _tabContent(BuildContext context, DemoCharacter c, double width) {
    final p = AppPalette.of(context);
    Lorebook? book;
    for (final b in AppStore.instance.lorebooks) {
      if (b.name == c.lorebook) book = b;
    }
    final loreEntries = book?.entries ?? const <LoreEntry>[];
    final activePreset = AppStore.instance.activePreset;
    final charRegex = AppStore.instance.regexScripts
        .where((r) => r.scope == c.name)
        .length;
    final descTokens = (c.description.length / 2).round();
    final exampleTokens = (c.exampleDialogue.length / 2).round();
    final scenarioTokens = ((c.personality.length + c.scenario.length) / 2).round();
    final greetingTokens = (c.greeting.length / 2).round();
    final maxTokens = [descTokens, exampleTokens, scenarioTokens, greetingTokens]
        .fold<int>(1, (a, b) => b > a ? b : a);
    switch (_tab) {
      case 1:
        return Column(
          key: const ValueKey(1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('绑定的世界书'),
            Glass(
              radius: 22,
              blur: 22,
              padding: const EdgeInsets.all(13),
              onTap: () {
                if (book == null) {
                  openGlassPage(context, const LoreScreen());
                  return;
                }
                openGlassPage(context, LorebookPage(book: book));
              },
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: LinearGradient(
                        colors: [
                          p.amber.withValues(alpha: .85),
                          p.rose.withValues(alpha: .5),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.lorebook,
                          style: appText(14, FontWeight.w600, p.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          book == null
                              ? '未绑定或已删除'
                              : '${loreEntries.length} 条 · 本地世界书',
                          style: appText(9.5, FontWeight.w400, p.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: p.textTertiary,
                  ),
                ],
              ),
            ),
            SettingsGroup(
              title: '世界书条目',
              children: [
                if (loreEntries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('没有条目'),
                  )
                else
                  for (var i = 0; i < loreEntries.take(4).length; i++) ...[
                    _LoreEntryRow(
                      entry: loreEntries[i],
                      onTap: () {
                        final boundBook = book;
                        if (boundBook == null) return;
                        openGlassPage(
                          context,
                          LoreEntryEditorPage(
                            book: boundBook,
                            entry: loreEntries[i],
                          ),
                        );
                      },
                    ),
                    if (i != loreEntries.take(4).length - 1)
                      const Hairline(indent: 12),
                  ],
              ],
            ),

          ],
        );
      case 2:
        return Column(
          key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsGroup(
              title: '提示词与预设',
              children: [
                SettingRow(
                  icon: Icons.layers_outlined,
                  title: '默认预设',
                  value: activePreset?.name ?? '默认',
                  iconColor: p.violet,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const PresetsPage()),
                  ),
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.subject_rounded,
                  title: '主提示词覆盖',
                  value: c.systemPrompt.trim().isEmpty ? '未设置' : '已设置',
                  iconColor: p.amber,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => CharacterEditorPage(character: c),
                    ),
                  ),
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.gavel_rounded,
                  title: 'Post-History Instructions',
                  value: c.postHistoryInstructions.trim().isEmpty ? '未设置' : '已设置',
                  iconColor: p.rose,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => CharacterEditorPage(character: c),
                    ),
                  ),
                ),

              ],
            ),
            SettingsGroup(
              title: '角色正则',
              children: [
                SettingRow(
                  icon: Icons.find_replace_rounded,
                  title: '角色正则',
                  value: '$charRegex 条脚本',
                  iconColor: const Color(0xFFA9A0E8),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const AutomationPage()),
                  ),
                ),
              ],
            ),
          ],
        );
      case 3:
        return Column(
          key: const ValueKey(3),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Token 分布'),
            Glass(
              radius: 22,
              blur: 22,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                children: [
                  _TokenBar(label: '描述', value: descTokens, ratio: descTokens / maxTokens, color: const Color(0xFFF0B36A)),
                  const SizedBox(height: 12),
                  _TokenBar(label: '示例对话', value: exampleTokens, ratio: exampleTokens / maxTokens, color: const Color(0xFFA9A0E8)),
                  const SizedBox(height: 12),
                  _TokenBar(label: '性格 + 场景', value: scenarioTokens, ratio: scenarioTokens / maxTokens, color: const Color(0xFF8FD0BE)),
                  const SizedBox(height: 12),
                  _TokenBar(label: '开场白', value: greetingTokens, ratio: greetingTokens / maxTokens, color: const Color(0xFFEE9AA8)),
                ],
              ),
            ),
            SettingsGroup(
              title: '管理',
              children: [
                SettingRow(
                  icon: Icons.edit_outlined,
                  title: '编辑角色',
                  value: '全部字段',
                  iconColor: p.amber,
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => CharacterEditorPage(character: c),
                      ),
                    );
                  },
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.copy_rounded,
                  title: '复制角色',
                  value: '角色卡与设定',
                  iconColor: p.sage,
                  onTap: () => _copyCharacter(context, c),
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.ios_share_rounded,
                  title: '导出角色卡',
                  value: 'PNG / JSON',
                  iconColor: p.violet,
                  onTap: () => _exportCharacterMenu(context, c),
                ),
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.delete_outline_rounded,
                  title: '删除角色',
                  value: '同时删除其聊天',
                  iconColor: p.danger,
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除角色'),
                        content: Text('删除「${c.name}」及其全部聊天？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await AppStore.instance.deleteCharacter(c, deleteChats: true);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Glass(
              radius: 20,
              blur: 20,
              shadow: false,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                children: [
                  _MetaRow(
                    label: '创建者',
                    value: c.creator.trim().isEmpty ? '未知' : c.creator,
                  ),
                  const SizedBox(height: 7),
                  _MetaRow(label: '版本', value: 'v${c.version}'),
                  const SizedBox(height: 7),
                  _MetaRow(label: '创建时间', value: _formatDate(c.createdAt)),
                  const SizedBox(height: 7),
                  _MetaRow(
                    label: '来源',
                    value: c.rawJson != null ? '导入的角色卡' : '本地创建',
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('角色设定'),
            Text(
              c.description,
              style: appText(
                14.5,
                FontWeight.w400,
                p.textSecondary,
                height: 1.65,
              ),
            ),
            const SectionLabel('开场白'),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: p.amber.withValues(alpha: .7),
                      width: 2,
                    ),
                  ),
                  color: Colors.white.withValues(alpha: p.isDark ? .03 : .25),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                child: Text(
                  c.greeting,
                  style: appText(
                    14,
                    FontWeight.w400,
                    p.textPrimary,
                    height: 1.55,
                    style: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const SectionLabel('已绑定'),
            Glass(
              radius: 22,
              blur: 24,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SettingRow(
                    icon: Icons.auto_stories_rounded,
                    title: '世界书',
                    value: c.lorebook,
                    iconColor: p.sage,
                    onTap: () {
                      if (book == null) {
                        openGlassPage(context, const LoreScreen());
                        return;
                      }
                      openGlassPage(context, LorebookPage(book: book));
                    },
                  ),
                  const Hairline(indent: 56),
                  SettingRow(
                    icon: Icons.tune_rounded,
                    title: '预设',
                    value: activePreset?.name ?? '默认',
                    iconColor: p.violet,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const PresetsPage()),
                    ),
                  ),

                ],
              ),
            ),
          ],
        );
    }
  }
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const labels = ['概览', '世界书', '预设', '高级'];
    return Glass(
      radius: 15,
      blur: 18,
      shadow: false,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: i == index
                        ? p.amber.withValues(alpha: .18)
                        : Colors.transparent,
                    border: i == index
                        ? Border.all(
                            color: p.amber.withValues(alpha: .28),
                            width: .8,
                          )
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: appText(
                      12,
                      i == index ? FontWeight.w600 : FontWeight.w400,
                      i == index ? p.amber : p.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.character, required this.chatCount});

  final DemoCharacter character;
  final int chatCount;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget cell(String value, String label) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: appText(17, FontWeight.w600, p.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: appText(10, FontWeight.w400, p.textTertiary),
            ),
          ],
        ),
      );
    }

    return Glass(
      radius: 22,
      blur: 24,
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          cell('$chatCount', '段对话'),
          Container(width: .6, height: 24, color: p.divider),
          cell(character.tokens, 'tokens'),
          Container(width: .6, height: 24, color: p.divider),
          cell('${character.tags.length}', '个标签'),
        ],
      ),
    );
  }
}

class _LoreEntryRow extends StatelessWidget {
  const _LoreEntryRow({required this.entry, this.onTap});

  final LoreEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final title = entry.name.isEmpty
        ? entry.keys.join(' · ')
        : entry.name;
    final badge = entry.constant
        ? '常驻'
        : entry.enabled
            ? '启用'
            : '关闭';
    final badgeColor = entry.constant
        ? const Color(0xFF8FD0BE)
        : entry.enabled
            ? p.amber
            : p.textTertiary;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: badgeColor.withValues(alpha: .14),
              ),
              child: Icon(
                Icons.bolt_rounded,
                size: 14,
                color: badgeColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(12.5, FontWeight.w500, p.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.keys.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(9, FontWeight.w400, p.textTertiary),
                  ),
                ],
              ),
            ),
            TagBadge(badge, color: badgeColor),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: p.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenBar extends StatelessWidget {
  const _TokenBar({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  final String label;
  final int value;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: appText(10, FontWeight.w400, p.textSecondary),
          ),
        ),
        Expanded(
          child: ProgressLine(value: ratio, height: 5, color: color),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: appText(10, FontWeight.w600, p.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        Text(
          label,
          style: appText(10.5, FontWeight.w400, p.textTertiary),
        ),
        const Spacer(),
        Text(
          value,
          style: appText(10.5, FontWeight.w500, p.textSecondary),
        ),
      ],
    );
  }
}

class _CharacterMorePage extends StatelessWidget {
  const _CharacterMorePage({
    required this.character,
    required this.onExport,
  });

  final DemoCharacter character;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'CHARACTER',
      title: '更多操作',
      subtitle: character.name,
      children: [
        const SizedBox(height: 12),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              SettingRow(
                icon: Icons.edit_outlined,
                title: '编辑角色',
                iconColor: p.amber,
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => CharacterEditorPage(character: character),
                  ),
                ),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.copy_rounded,
                title: '复制角色',
                iconColor: p.sage,
                onTap: () => _copyCharacter(context, character, closeAfter: true),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.ios_share_rounded,
                title: '导出角色卡',
                value: 'PNG / JSON',
                iconColor: p.violet,
                onTap: onExport,
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.delete_outline_rounded,
                title: '删除角色',
                value: '同时删除其聊天',
                iconColor: p.danger,
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('删除角色'),
                      content: Text('删除「${character.name}」及其全部聊天？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await AppStore.instance.deleteCharacter(
                    character,
                    deleteChats: true,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GreetingPickerPage extends StatelessWidget {
  const _GreetingPickerPage({
    required this.character,
    required this.greetings,
  });

  final DemoCharacter character;
  final List<String> greetings;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'GREETING',
      title: '选择开场白',
      subtitle: character.name,
      children: [
        const SizedBox(height: 12),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < greetings.length; i++) ...[
                _GreetingOption(
                  index: i,
                  text: greetings[i],
                  color: p.amber,
                  onChoose: () => Navigator.of(context).pop(i),
                ),
                if (i != greetings.length - 1) const Hairline(indent: 18),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ExportCardPage extends StatelessWidget {
  const _ExportCardPage({
    required this.character,
    required this.onPng,
    required this.onJson,
  });

  final DemoCharacter character;
  final VoidCallback onPng;
  final VoidCallback onJson;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DetailPage(
      eyebrow: 'EXPORT',
      title: '导出角色卡',
      subtitle: character.name,
      children: [
        const SizedBox(height: 12),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              SettingRow(
                icon: Icons.image_outlined,
                title: 'PNG 角色卡',
                subtitle: '写入 chara / ccv3 元数据，可直接分享',
                iconColor: p.amber,
                onTap: () {
                  Navigator.of(context).pop();
                  onPng();
                },
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.data_object_rounded,
                title: 'JSON 数据',
                subtitle: '仅导出角色卡字段',
                iconColor: p.sage,
                onTap: () {
                  Navigator.of(context).pop();
                  onJson();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GreetingOption extends StatefulWidget {
  const _GreetingOption({
    required this.index,
    required this.text,
    required this.color,
    required this.onChoose,
  });

  final int index;
  final String text;
  final Color color;
  final VoidCallback onChoose;

  @override
  State<_GreetingOption> createState() => _GreetingOptionState();
}

class _GreetingOptionState extends State<_GreetingOption> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final preview = widget.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          onTap: () => setState(() => _expanded = !_expanded),
          child: SizedBox(
            height: 58,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: widget.color.withValues(alpha: .16),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: widget.color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '开场白 ${widget.index + 1}',
                          style: appText(13, FontWeight.w600, p.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preview.isEmpty ? '（空）' : preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appText(10.5, FontWeight.w400, p.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: p.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(58, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.text.isEmpty ? '（空开场白）' : widget.text,
                      style: appText(12.5, FontWeight.w400, p.textSecondary, height: 1.55),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GlassPill(
                    label: '使用这个开场白',
                    icon: Icons.check_rounded,
                    height: 30,
                    onTap: widget.onChoose,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
