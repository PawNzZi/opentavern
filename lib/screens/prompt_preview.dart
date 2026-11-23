import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/prompt.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';
import '../design/toast.dart';

/// 「构建预览」页：展示系统段落的顺序（可上下调整并写回
/// `settings.promptOrder`），并给出每段实际发送的文本与统计信息。
///
/// 世界书相关的段落可以点开查看扫描范围、关键词命中、预算丢弃等诊断信息，
/// 用来回答「世界书 / 性格 / 场景为什么没有内容」这类问题。
///
/// 通过 [character] / [session] 传入当前打开的聊天时，预览会使用真实会话的
/// 作者笔记、摘要与消息数；两者都为空时回退到 store 里的第一组角色 / 会话。
class PromptPreviewPage extends StatefulWidget {
  const PromptPreviewPage({super.key, this.character, this.session});

  final DemoCharacter? character;
  final ChatSession? session;

  @override
  State<PromptPreviewPage> createState() => _PromptPreviewPageState();
}

class _PromptPreviewPageState extends State<PromptPreviewPage> {
  static const _labels = <String, String>{
    'main': '主提示词 / 规则',
    'worldInfoBefore': '世界书（角色前）',
    'personaDescription': '用户设定（Persona）',
    'charDescription': '角色描述',
    'charPersonality': '性格',
    'scenario': '场景',
    'charSystemPrompt': '角色专属提示词',
    'worldInfoAfter': '世界书（角色后）',
    'dialogueExamples': '示例对话',
    'summary': '前情提要',
    'authorsNote': '作者笔记',
    'jailbreak': '越狱 / PHI（历史后）',
  };

  /// PHI 固定放在历史消息之后，不参与系统段落排序。
  static const _phiKey = 'jailbreak';

  /// 可上下移动的系统段落（顺序即写入 settings.promptOrder 的顺序）。
  static const _movable = <String>[
    'main',
    'worldInfoBefore',
    'personaDescription',
    'charDescription',
    'charPersonality',
    'scenario',
    'charSystemPrompt',
    'worldInfoAfter',
    'dialogueExamples',
    'summary',
    'authorsNote',
  ];

  late List<String> _order;

  @override
  void initState() {
    super.initState();
    _order = _normalize(AppStore.instance.settings.promptOrder);
  }

  /// 去掉未知 / 固定段落，并补齐缺失段落，保证可调段落齐全。
  List<String> _normalize(List<String> stored) {
    final result = <String>[];
    for (final key in stored) {
      if (_movable.contains(key) && !result.contains(key)) result.add(key);
    }
    for (final key in _movable) {
      if (!result.contains(key)) result.add(key);
    }
    return result;
  }

  Future<void> _saveOrder() async {
    final settings = AppStore.instance.settings.copyWith(
      // jailbreak 仍保留在 promptOrder 末尾以便配置往返；实际发送位置固定。
      promptOrder: [..._order, _phiKey],
    );
    AppStore.instance.settings = settings;
    await AppStore.instance.saveSettings();
  }

  Future<void> _move(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _order.length) return;
    setState(() {
      final item = _order.removeAt(index);
      _order.insert(target, item);
    });
    await _saveOrder();
  }

  Future<void> _reset() async {
    setState(() {
      _order = _normalize(kDefaultPromptOrder);
    });
    await _saveOrder();
  }

  /// 优先使用调用方传入的角色；否则用会话的角色名反查；再退回第一个角色。
  DemoCharacter _resolveCharacter(AppStore store) {
    final provided = widget.character;
    if (provided != null) return provided;
    final session = widget.session;
    if (session != null) {
      for (final c in store.characters) {
        if (c.name == session.characterName) return c;
      }
    }
    return store.characters.first;
  }

  /// 优先使用调用方传入的会话；否则取该角色最近的会话；再退回打招呼的预览会话。
  ChatSession _resolveSession(DemoCharacter character) {
    final provided = widget.session;
    if (provided != null) return provided;
    for (final s in AppStore.instance.sessions) {
      if (s.characterName == character.name) return s;
    }
    return ChatSession(
      id: 'preview',
      characterName: character.name,
      title: '预览',
      messages: [
        if (character.greeting.trim().isNotEmpty)
          ChatMessage(id: 'preview-greet', text: character.greeting),
      ],
    );
  }

  String _positionLabel(String position) {
    switch (position) {
      case 'after':
        return '角色后';
      case 'at_depth':
        return '按深度';
      default:
        return '角色前';
    }
  }

  /// 打开某个系统段落的正文。
  void _showSection(String key, String content, String subtitle) {
    final p = AppPalette.of(context);
    showTavernSheet<void>(
      context,
      title: _labels[key] ?? key,
      subtitle: subtitle,
      heightFactor: .82,
      child: Glass(
        radius: 18,
        blur: 18,
        shadow: false,
        padding: const EdgeInsets.all(14),
        child: SelectionArea(
          child: Text(
            content,
            style: appText(12.5, FontWeight.w400, p.textSecondary, height: 1.6),
          ),
        ),
      ),
    );
  }

  /// 把一条消息的 content 截断到前 50 个字符（多模态数组逐段处理）。
  dynamic _truncateContent(dynamic content, bool full) {
    String clip(String text) {
      if (full || text.length <= 50) return text;
      return '${text.substring(0, 50)}…（共 ${text.length} 字）';
    }

    if (content is String) return clip(content);
    if (content is List) {
      return [
        for (final part in content)
          if (part is Map)
            {
              'type': part['type'],
              if (part['type'] == 'text') 'text': clip('${part['text']}'),
              if (part['type'] == 'image')
                'image': '<base64 图片，${('${part['base64']}').length} 字符>',
            }
          else
            part,
      ];
    }
    return content;
  }

  /// 真实发送的 messages 数组（JSON）。full=false 时每条 content 只取前 50 字。
  String _messagesJson(BuiltPrompt built, bool full) {
    final list = [
      for (final m in built.messages)
        {
          'role': m['role'],
          'content': _truncateContent(m['content'], full),
        },
    ];
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  Map<String, dynamic> _requestParams(AppSettings settings) {
    final api = settings.api;
    return {
      'model': api.model,
      'provider': api.provider,
      'temperature': api.temperature,
      'max_tokens（最大回复长度）': api.maxTokens,
      'stream': api.streaming,
      'max_context（最大上下文）': settings.maxContext,
      'token_padding（回复预留）': settings.tokenPadding,
      'lore_max_tokens（世界书上限）': settings.loreMaxTokens,
    };
  }

  /// 打开「真实 messages 数组」面板：请求参数 + 可切换截断/全文的 JSON。
  void _showMessagesJson(
    BuiltPrompt built,
    AppSettings settings,
    DemoCharacter character,
  ) {
    final p = AppPalette.of(context);
    var full = false;
    showTavernSheet<void>(
      context,
      title: '真实 messages 数组',
      subtitle: '${character.name} · ${built.messages.length} 条 · 约 '
          '${built.approxTokens} tokens',
      heightFactor: .9,
      child: StatefulBuilder(
        builder: (context, setState) {
          final json = _messagesJson(built, full);
          final params = const JsonEncoder.withIndent('  ')
              .convert(_requestParams(settings));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '请求参数（决定回复是否被截断）',
                      style: appText(12, FontWeight.w600, p.textPrimary),
                    ),
                  ),
                  GlassPill(
                    label: full ? '截断 50 字' : '显示全文',
                    icon: full
                        ? Icons.compress_rounded
                        : Icons.expand_rounded,
                    height: 30,
                    onTap: () => setState(() => full = !full),
                  ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Glass(
                    radius: 16,
                    blur: 16,
                    shadow: false,
                    padding: const EdgeInsets.all(12),
                    child: SelectionArea(
                      child: Text(
                        params,
                        style: appText(11.5, FontWeight.w400, p.textSecondary,
                            height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'messages 数组${full ? '（全文）' : '（content 仅前 50 字）'}',
                    style: appText(12, FontWeight.w600, p.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Glass(
                    radius: 16,
                    blur: 16,
                    shadow: false,
                    padding: const EdgeInsets.all(12),
                    child: SelectionArea(
                      child: Text(
                        json,
                        style: appText(11, FontWeight.w400, p.textSecondary,
                            height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GlassPill(
                          label: '复制 JSON',
                          icon: Icons.copy_rounded,
                          height: 36,
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: json));
                            showTavernToast(context, '已复制 messages JSON');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GlassPill(
                          label: '导出文件',
                          icon: Icons.ios_share_rounded,
                          height: 36,
                          onTap: () async {
                            final payload = const JsonEncoder.withIndent('  ')
                                .convert({
                              'request': _requestParams(settings),
                              'messages': [
                                for (final m in built.messages)
                                  {
                                    'role': m['role'],
                                    'content': m['content'],
                                  },
                              ],
                            });
                            final uri =
                                await FilePickerPlatform.instance.saveFile(
                              fileName: 'messages-${character.name}.json',
                              bytes: Uint8List.fromList(utf8.encode(payload)),
                              mimeType: 'application/json',
                              dialogTitle: '导出 messages 数组',
                            );
                            if (context.mounted) {
                              showTavernToast(
                                context,
                                uri == null ? '已取消导出' : '已导出完整 JSON',
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
        },
      ),
    );
  }

  /// 世界书诊断：扫描了哪些书、命中多少条、为什么没注入。
  void _showLoreSheet(PromptLoreStats lore) {
    final p = AppPalette.of(context);
    final scope = lore.scopeBooks.isEmpty
        ? '没有绑定或全局世界书'
        : lore.scopeBooks.join('、');
    final injectedIds = {for (final e in lore.injected) e.id};
    final children = <Widget>[
      _LoreInfoLine(label: '扫描范围', value: scope),
      _LoreInfoLine(label: '启用条目', value: '${lore.scopeEntries} 条'),
      _LoreInfoLine(label: '关键词命中', value: '${lore.matched.length} 条'),
      _LoreInfoLine(label: '实际注入', value: '${lore.injected.length} 条'),
      if (lore.droppedByBudget > 0)
        _LoreInfoLine(
          label: '预算丢弃',
          value: '${lore.droppedByBudget} 条',
          color: p.rose,
        ),
      const SizedBox(height: 12),
      if (lore.matched.isEmpty)
        Text(
          '没有条目命中。世界书会扫描最近 8 条对话、角色卡（名字 / 描述 / '
          '性格 / 场景）、人格、作者笔记与摘要；非常驻条目需要在其中出现关键词'
          '才会注入。可以给条目加上关键词，或打开条目的「常驻」。',
          style: appText(11.5, FontWeight.w400, p.textSecondary, height: 1.6),
        )
      else ...[
        Text('命中条目', style: appText(12, FontWeight.w600, p.textPrimary)),
        const SizedBox(height: 6),
        for (final entry in lore.matched)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              '· ${entry.name}（${_positionLabel(entry.position)} · 约 '
              '${estimateTokens(entry.content)} tok）'
              '${injectedIds.contains(entry.id) ? '' : ' · 未注入'}',
              style: appText(
                11,
                FontWeight.w400,
                injectedIds.contains(entry.id) ? p.textSecondary : p.textTertiary,
                height: 1.5,
              ),
            ),
          ),
      ],
    ];
    showTavernSheet<void>(
      context,
      title: '世界书扫描',
      subtitle: lore.matched.isEmpty
          ? '没有命中，所以世界书段落为空'
          : '命中 ${lore.matched.length} 条 · 注入 ${lore.injected.length} 条',
      heightFactor: .8,
      child: Glass(
        radius: 18,
        blur: 18,
        shadow: false,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final store = AppStore.instance;
    if (store.characters.isEmpty) {
      return DetailPage(
        eyebrow: 'PROMPT INSPECTOR',
        title: '构建预览',
        subtitle: '先导入或创建一个角色。',
        children: const [
          SizedBox(height: 40),
          Center(child: Text('还没有角色，无法构建 Prompt。')),
        ],
      );
    }
    final settings = store.settings;
    final character = _resolveCharacter(store);
    final session = _resolveSession(character);
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: settings,
    );
    final phi = built.sections[_phiKey];
    final lore = built.lore;

    final boundKey = character.lorebook.trim();
    final boundMissing = boundKey.isNotEmpty &&
        boundKey != '未绑定' &&
        !store.lorebooks.any(
          (book) => book.name == boundKey || book.id == boundKey,
        );
    final unboundBooks = store.lorebooks
        .where(
          (book) =>
              book.enabled &&
              !book.isGlobal &&
              (book.linked ?? '').trim().isEmpty,
        )
        .toList();

    String summaryHint() {
      if (settings.summaryPosition == 'after_history') {
        return '历史消息之后（角色 ${settings.summaryRole}）';
      }
      if (settings.summaryPosition == 'at_depth') {
        return '最近 ${settings.summaryDepth.clamp(1, 20)} 条消息之前'
            '（角色 ${settings.summaryRole}）';
      }
      return '系统段落「前情提要」';
    }

    String worldInfoHint() {
      if (lore.scopeBooks.isEmpty) return '没有绑定世界书，也没有全局世界书';
      if (lore.scopeEntries == 0) return '世界书没有启用的条目';
      if (lore.matched.isEmpty) return '没有条目命中关键词（世界书不是常驻）';
      if (lore.injected.isEmpty) {
        return '命中 ${lore.matched.length} 条，全部超出 Token 预算';
      }
      return '命中的条目都按深度注入了历史';
    }

    String inactiveHint(String key) {
      if (key == 'main') {
        return '主提示词为空（来自${built.mainSource}），发送时跳过';
      }
      if (key == 'worldInfoBefore' || key == 'worldInfoAfter') {
        return worldInfoHint();
      }
      if (key == 'summary' && settings.summaryPosition != 'in_prompt') {
        return '摘要改在${summaryHint()}注入';
      }
      return '该段落为空，发送时跳过';
    }

    String sourceHint(String key) {
      if (key == 'authorsNote') {
        return session.authorNoteOverride ? ' · 本聊天' : ' · 跟随全局';
      }
      return '';
    }

    String activeSubtitle(String key, String section) {
      final tokens = estimateTokens(section);
      if (key == 'main') {
        return '已拼接 · 约 $tokens tok · 来自${built.mainSource}';
      }
      if (key == 'worldInfoBefore' || key == 'worldInfoAfter') {
        final count = lore.injected
            .where(
              (e) => key == 'worldInfoBefore'
                  ? (e.position != 'after' && e.position != 'at_depth')
                  : e.position == 'after',
            )
            .length;
        return '已拼接 $count 条 · 约 $tokens tok · 点按查看详情';
      }
      return '已拼接 · 约 $tokens tok${sourceHint(key)}';
    }

    final atDepthTokens = lore.injected
        .where((e) => e.position == 'at_depth')
        .fold<int>(
          0,
          (sum, entry) => sum + estimateTokens(entry.content) + 4,
        );

    Widget sectionRow(int index) {
      final key = _order[index];
      final section = built.sections[key];
      final isWorldInfo = key == 'worldInfoBefore' || key == 'worldInfoAfter';
      return SettingRow(
        icon: isWorldInfo
            ? Icons.auto_stories_rounded
            : Icons.drag_indicator_rounded,
        title: _labels[key] ?? key,
        subtitle: section != null
            ? activeSubtitle(key, section)
            : inactiveHint(key),
        value: '${index + 1}',
        iconColor: section != null ? p.amber : p.textTertiary,
        chevron: false,
        onTap: isWorldInfo
            ? () => _showLoreSheet(lore)
            : section != null
                ? () => _showSection(
                      key,
                      section,
                      activeSubtitle(key, section),
                    )
                : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassCircleButton(
              icon: Icons.keyboard_arrow_up_rounded,
              size: 28,
              iconSize: 15,
              blur: 0,
              onTap: () => _move(index, -1),
            ),
            const SizedBox(width: 2),
            GlassCircleButton(
              icon: Icons.keyboard_arrow_down_rounded,
              size: 28,
              iconSize: 15,
              blur: 0,
              onTap: () => _move(index, 1),
            ),
          ],
        ),
      );
    }

    return DetailPage(
      eyebrow: 'PROMPT INSPECTOR',
      title: '构建预览',
      subtitle: '${character.name} · 约 ${built.approxTokens} tokens',
      children: [
        const SizedBox(height: 12),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: MiniStat(
                  value: '${built.messages.length}',
                  label: '条消息',
                ),
              ),
              Expanded(
                child: MiniStat(
                  value: '${built.droppedMessages}',
                  label: '丢弃历史',
                ),
              ),
              Expanded(
                child: MiniStat(
                  value: '${lore.injected.length}',
                  label: '世界书注入',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Glass(
          radius: 20,
          blur: 20,
          shadow: false,
          onTap: () => _showMessagesJson(built, settings, character),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.data_object_rounded, size: 18, color: p.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '查看真实 messages 数组',
                      style: appText(13.5, FontWeight.w600, p.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '实际发送给模型的 JSON · 可截断 50 字 / 全文 · 复制 / 导出',
                      style: appText(10.5, FontWeight.w400, p.textTertiary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: p.textTertiary),
            ],
          ),
        ),
        if (store.presets.isEmpty) ...[
          const SizedBox(height: 10),
          HintCard(
            text: '还没有任何预设：主提示词直接使用内置的全局设置，无法在这里清空。'
                '打开「设置 → 提示词」会自动创建一个可编辑的预设，之后就能改写或'
                '清空主提示词。',
            icon: Icons.tune_rounded,
            color: p.amber,
          ),
        ],
        if (widget.session != null) ...[
          const SizedBox(height: 10),
          HintCard(
            text: '正在预览「${session.title}」：${session.messages.length} 条消息；'
                '作者笔记来自${session.authorNoteOverride ? '本聊天' : '全局'}；'
                '摘要注入：${summaryHint()}。',
            icon: Icons.forum_outlined,
            color: p.amber,
          ),
        ],
        if (boundMissing) ...[
          const SizedBox(height: 10),
          HintCard(
            text: '角色绑定的世界书「$boundKey」在本机不存在（可能已删除，或角色卡'
                '引用了一本尚未导入的世界书），因此不会被扫描。请在角色编辑里'
                '重新绑定一本本地世界书。',
            icon: Icons.link_off_rounded,
            color: p.danger,
          ),
        ],
        if (unboundBooks.isNotEmpty) ...[
          const SizedBox(height: 10),
          HintCard(
            text: '有 ${unboundBooks.length} 本世界书既没有绑定角色、也没有开启'
                '「全局世界书」，所以不会参与任何对话：'
                '${unboundBooks.map((b) => b.name).take(3).join('、')}'
                '${unboundBooks.length > 3 ? ' 等' : ''}。',
            icon: Icons.info_outline_rounded,
            color: p.textTertiary,
          ),
        ],
        const SectionLabel('系统段落顺序'),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < _order.length; i++) ...[
                sectionRow(i),
                if (i != _order.length - 1) const Hairline(indent: 56),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: GlassPill(
            label: '恢复默认顺序',
            icon: Icons.restart_alt_rounded,
            height: 30,
            onTap: _reset,
          ),
        ),
        const SectionLabel('世界书与固定位置'),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              SettingRow(
                icon: Icons.travel_explore_rounded,
                title: '世界书扫描',
                subtitle: lore.scopeBooks.isEmpty
                    ? '没有绑定世界书，也没有全局世界书'
                    : '扫描 ${lore.scopeBooks.length} 本 · 启用 '
                        '${lore.scopeEntries} 条 · 命中 ${lore.matched.length} 条',
                value: lore.droppedByBudget > 0
                    ? '丢弃 ${lore.droppedByBudget}'
                    : '注入 ${lore.injected.length}',
                iconColor: lore.injected.isEmpty ? p.textTertiary : p.sage,
                onTap: () => _showLoreSheet(lore),
              ),
              const Hairline(indent: 56),
              SettingRow(
                icon: Icons.lock_outline_rounded,
                title: _labels[_phiKey]!,
                subtitle: phi == null
                    ? '未设置，发送时跳过'
                    : '固定为历史消息之后的最后一条 system 消息',
                value: phi == null ? '未设置' : '${estimateTokens(phi)} tok',
                iconColor: p.amber,
                chevron: false,
                onTap: phi == null ? null : () => _showSection(
                      _phiKey,
                      phi,
                      '历史消息之后的最后一条 system 消息',
                    ),
              ),
              if (lore.atDepthCount > 0) ...[
                const Hairline(indent: 56),
                SettingRow(
                  icon: Icons.vertical_align_bottom_rounded,
                  title: '世界书（按深度）',
                  subtitle: '${lore.atDepthCount} 条插入最近对话之前',
                  value: '$atDepthTokens tok',
                  iconColor: p.sage,
                  onTap: () => _showLoreSheet(lore),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '点按已拼接的段落可以查看实际发送的文本；世界书相关行会列出扫描范围、'
          '关键词命中和预算丢弃。系统段落按上面的顺序拼成第一条 system 消息，'
          '空段落自动跳过；PHI 始终作为历史消息之后的最后一条 system 消息发送。'
          '点击上下箭头会立即保存到 settings.promptOrder。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
        ),
      ],
    );
  }
}

class _LoreInfoLine extends StatelessWidget {
  const _LoreInfoLine({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: appText(
                11.5,
                FontWeight.w500,
                color ?? p.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
