import 'dart:math';

import '../data/demo.dart';
import 'regex.dart';
import 'statusbar.dart';
import 'store.dart';
import 'macros.dart';
import 'models.dart';

class BuiltPrompt {
  BuiltPrompt({
    required this.messages,
    required this.approxTokens,
    required this.droppedMessages,
    this.sections = const {},
    this.mainSource = '',
    this.lore = const PromptLoreStats(),
  });

  final List<Map<String, dynamic>> messages;
  final int approxTokens;
  final int droppedMessages;

  /// 实际拼接进 prompt 的系统段落，按发送顺序排列。
  ///
  /// `jailbreak`（角色卡的 post_history_instructions / PHI）固定排在最后：
  /// 它作为历史消息之后的最后一条 system 消息发送。
  final Map<String, String> sections;

  /// 主提示词的实际来源（预设名或全局设置），供「构建预览」展示。
  final String mainSource;

  /// 世界书扫描与注入的统计信息。
  final PromptLoreStats lore;
}

/// 世界书扫描 / 注入的诊断结果。
///
/// 「构建预览」用它解释世界书段落为什么有内容或为什么被跳过，避免用户只能
/// 面对一个「该段落为空」的结论。
class PromptLoreStats {
  const PromptLoreStats({
    this.scopeBooks = const [],
    this.scopeEntries = 0,
    this.matched = const [],
    this.injected = const [],
  });

  /// 本次参与扫描的世界书名（角色绑定 / 全局 / 角色卡绑定）。
  final List<String> scopeBooks;

  /// 扫描范围内启用的条目总数。
  final int scopeEntries;

  /// 关键词命中、有资格进入 prompt 的条目（预算裁剪前）。
  final List<LoreEntry> matched;

  /// 最终实际进入 prompt 的条目（预算裁剪后）。
  final List<LoreEntry> injected;

  int get droppedByBudget => matched.length - injected.length;

  int get atDepthCount =>
      injected.where((e) => e.position == 'at_depth').length;
}

int estimateTokens(String text) {
  var cjk = 0;
  var other = 0;
  for (final rune in text.runes) {
    if ((rune >= 0x2E80 && rune <= 0x9FFF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        (rune >= 0x3040 && rune <= 0x30FF)) {
      cjk++;
    } else {
      other++;
    }
  }
  return cjk + (other / 4).ceil();
}

class PromptBuilder {
  static BuiltPrompt build({
    required DemoCharacter character,
    required ChatSession session,
    required AppSettings settings,
  }) {
    String lastUser = '';
    String lastAny = '';
    for (final m in session.messages.reversed) {
      if (lastAny.isEmpty && m.text.trim().isNotEmpty) lastAny = m.text;
      if (lastUser.isEmpty && m.isUser && m.text.trim().isNotEmpty) {
        lastUser = m.text;
      }
      if (lastAny.isNotEmpty && lastUser.isNotEmpty) break;
    }
    String macro(String input) {
      // 状态栏变量树通过 {{format_message_variable::stat_data}} 注入，
      // 让模型在更新变量前能读到当前值。
      final withStat = input.replaceAllMapped(
        RegExp(r'\{\{\s*format_message_variable::stat_data\s*\}\}'),
        (_) => StatusBar.format(session.statData),
      );
      return MacroEngine.expand(
        withStat,
        character: character,
        settings: settings,
        variables: session.variables,
        userInput: lastUser,
        lastMessage: lastAny,
      );
    }

    final preset = AppStore.instance.presetForCharacter(character);
    // 预设是主提示词的唯一来源：一旦绑定了预设，即使预设的主提示词为空也
    // 不再回退到全局设置。否则用户在「提示词」里清空主提示词后，仍会收到
    // 一条在 UI 里看不到的默认提示词（「主提示词明明为空却有内容」）。
    final main = preset?.mainPrompt ?? settings.mainPrompt;
    final mainSource = preset == null
        ? '全局设置（未绑定预设）'
        : '预设「${preset.name}」';
    final effectiveAuthorNote =
        session.authorNoteOverride ? session.authorNote : settings.authorNote;
    final userLabel = settings.userName.trim().isNotEmpty
        ? settings.userName.trim()
        : settings.personaName.trim().isNotEmpty
            ? settings.personaName.trim()
            : 'User';
    final rawSummary = session.summary.trim();
    final summaryText = rawSummary.isEmpty ? '' : macro(rawSummary).trim();
    final postHistory = character.postHistoryInstructions.trim().isEmpty
        ? ''
        : '\n[越狱 / PHI]\n${macro(character.postHistoryInstructions).trim()}';
    final rawMaxPrompt =
        settings.maxContext - settings.api.maxTokens - settings.tokenPadding;
    final maxPrompt = rawMaxPrompt < 256 ? 256 : rawMaxPrompt;

    // 世界书关键词扫描：除了最近 8 条对话，也扫描角色卡字段、人格、作者笔记
    // 与摘要。角色卡和世界书通常共享同一批专有名词，只扫描对话会让「新聊天
    // 里明明有设定却一条都没命中」。
    final recentText = session.messages
        .where((m) => !m.hidden && m.text.trim().isNotEmpty)
        .toList()
        .reversed
        .take(8)
        .map((m) => m.text)
        .join('\n');
    final loreContext = [
      character.name,
      character.description,
      character.personality,
      character.scenario,
      userLabel,
      settings.personaDescription,
      effectiveAuthorNote,
      summaryText,
      recentText,
    ].where((part) => part.trim().isNotEmpty).map(macro).join('\n');
    final loreScan = _scanLore(character, loreContext);

    final presetEntries = preset == null
        ? const <PromptEntry>[]
        : (preset.entries.where((e) => e.enabled).toList()
          ..sort((a, b) => a.order.compareTo(b.order)));
    // 预设条目只展开一次宏：既用于 Token 估算，也用于真正拼接，避免
    // {{setvar}} / {{addvar}} 这类有副作用的宏被执行两次。
    final expandedEntries = <String, String>{
      for (final entry in presetEntries)
        entry.id: macro(entry.content).trim(),
    };

    // 世界书正文同样要展开宏（{{user}} / {{char}} / 变量……），否则角色卡
    // 世界书里的占位符会原样发给模型。
    final expandedLore = <String, String>{
      for (final entry in loreScan.matched)
        entry.id: macro(entry.content).trim(),
    };
    // 世界书预算：loreMaxTokens=0 = 「无限制」，所有命中条目全部注入，不做
    // 任何裁剪（与酒馆 world_info_budget_cap=0=不限 一致）；>0 按该绝对上限
    // 裁剪。无限制时若世界书很大，需要把「最大上下文」调大，否则历史会被挤掉。
    final loreEntries = settings.loreMaxTokens > 0
        ? _applyLoreBudget(
            loreScan.matched,
            expandedLore,
            settings.loreMaxTokens,
          )
        : loreScan.matched;
    final loreAtDepth =
        loreEntries.where((e) => e.position == 'at_depth').toList();
    final loreBefore = loreEntries
        .where((e) => e.position != 'after' && e.position != 'at_depth')
        .map((e) => expandedLore[e.id] ?? '')
        .where((e) => e.isNotEmpty)
        .join('\n\n');
    final loreAfter = loreEntries
        .where((e) => e.position == 'after')
        .map((e) => expandedLore[e.id] ?? '')
        .where((e) => e.isNotEmpty)
        .join('\n\n');

    final sections = <String, String>{};
    if (main.trim().isNotEmpty) {
      sections['main'] = macro(main).trim();
    }
    if (character.systemPrompt.trim().isNotEmpty) {
      sections['charSystemPrompt'] =
          '\n[角色专属提示词]\n${macro(character.systemPrompt).trim()}';
    }
    if (loreBefore.isNotEmpty) {
      sections['worldInfoBefore'] = '\n[世界设定 · 角色前]\n$loreBefore';
    }
    if (character.description.trim().isNotEmpty) {
      sections['charDescription'] =
          '\n[角色描述]\n${macro(character.description).trim()}';
    }
    if (character.personality.trim().isNotEmpty) {
      sections['charPersonality'] =
          '\n[性格]\n${macro(character.personality).trim()}';
    }
    if (character.scenario.trim().isNotEmpty) {
      sections['scenario'] = '\n[场景]\n${macro(character.scenario).trim()}';
    }
    if (loreAfter.isNotEmpty) {
      sections['worldInfoAfter'] = '\n[世界设定 · 角色后]\n$loreAfter';
    }
    if (settings.personaDescription.trim().isNotEmpty) {
      sections['personaDescription'] =
          '\n[用户设定]\n名字：$userLabel\n'
          '${macro(settings.personaDescription).trim()}';
    }
    if (character.exampleDialogue.trim().isNotEmpty) {
      sections['dialogueExamples'] =
          '\n[对话示例]\n${macro(character.exampleDialogue).trim()}';
    }
    if (summaryText.isNotEmpty && settings.summaryPosition == 'in_prompt') {
      sections['summary'] = '\n[前情提要]\n$summaryText';
    }
    if (effectiveAuthorNote.trim().isNotEmpty) {
      sections['authorsNote'] =
          '\n[作者笔记]\n${macro(effectiveAuthorNote).trim()}';
    }
    final system = StringBuffer();
    final usedSections = <String, String>{};
    for (final key in settings.promptOrder) {
      final section = sections.remove(key);
      if (section != null && section.trim().isNotEmpty) {
        system.writeln(section);
        usedSections[key] = section.trim();
      }
    }
    for (final entry in sections.entries) {
      if (entry.value.trim().isNotEmpty) {
        system.writeln(entry.value);
        usedSections[entry.key] = entry.value.trim();
      }
    }

    final extra = <Map<String, String>>[];
    for (final entry in presetEntries) {
      final content = expandedEntries[entry.id] ?? '';
      if (content.isEmpty) continue;
      if (entry.role == 'system') {
        system.writeln('\n[${entry.name}]\n$content');
      } else {
        extra.add({
          'role': entry.role == 'assistant' ? 'assistant' : 'user',
          'content': content,
        });
      }
    }

    var used = estimateTokens(system.toString());
    // PHI 在历史之后发送，但同样占用上下文预算。
    if (postHistory.trim().isNotEmpty) used += estimateTokens(postHistory);
    // 预设里的 user/assistant 条目插在历史之前，也要计入。
    for (final entry in extra) {
      used += estimateTokens(entry['content'] ?? '') + 4;
    }
    var history = <Map<String, dynamic>>[];
    var dropped = 0;
    var imageCount = 0;
    final cardPatterns = StatusBar.cardPatterns(character.rawJson);

    for (var i = session.messages.length - 1; i >= 0; i--) {
      final m = session.messages[i];
      if (m.hidden || m.isSystem) continue;
      if (m.text.trim().isEmpty && m.attachments.isEmpty) continue;
      // 历史消息以原始文本存储，发送前才展开宏，这样 {{user}} / {{char}}
      // 不会原样进入上下文，同时聊天记录仍保留用户输入的原文。
      // 状态块单独渲染，发送时剥离以节省上下文（含卡自带 regex 规则）。
      var content = macro(StatusBar.strip(m.text, cardPatterns: cardPatterns));
      content = m.isUser ? _formatUserRoleplay(content) : content;
      content = applyRegexScripts(
        content,
        AppStore.instance.regexScripts,
        stage: 'prompt',
        characterName: character.name,
      );
      for (final att in m.attachments.where((a) => !a.isImage)) {
        if (att.text.trim().isEmpty) continue;
        content += '\n\n[附件 ${att.name}]\n${att.text.trim()}';
      }
      final includedImages = <ChatAttachment>[];
      for (final att in m.attachments.where((a) => a.isImage)) {
        if (imageCount >= 2) break;
        includedImages.add(att);
        imageCount++;
      }
      final tokens =
          estimateTokens(content) + 4 + includedImages.length * 850;
      if (used + tokens > maxPrompt) {
        dropped = i + 1;
        break;
      }
      history.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': includedImages.isEmpty
            ? content
            : <Map<String, dynamic>>[
                {'type': 'text', 'text': content},
                for (final att in includedImages)
                  {
                    'type': 'image',
                    'mime': att.mime,
                    'base64': att.base64,
                  },
              ],
      });
      used += tokens;
    }
    history = history.reversed.toList();
    for (final entry in loreAtDepth) {
      final role = entry.role == 'user'
          ? 'user'
          : entry.role == 'assistant'
              ? 'assistant'
              : 'system';
      final index =
          (history.length - entry.depth).clamp(0, history.length);
      final content = expandedLore[entry.id] ?? entry.content.trim();
      history.insert(index, {
        'role': role,
        'content': content,
      });
      used += estimateTokens(content) + 4;
    }
    final summaryMessages = <Map<String, dynamic>>[];
    if (summaryText.isNotEmpty && settings.summaryPosition != 'in_prompt') {
      final role = settings.summaryRole == 'user'
          ? 'user'
          : settings.summaryRole == 'assistant'
              ? 'assistant'
              : 'system';
      final summaryMessage = {
        'role': role,
        'content': '[前情提要]\n$summaryText',
      };
      if (settings.summaryPosition == 'at_depth') {
        final depth = settings.summaryDepth.clamp(0, history.length);
        final index = (history.length - depth).clamp(0, history.length);
        history.insert(index, summaryMessage);
      } else {
        summaryMessages.add(summaryMessage);
      }
      used += estimateTokens(summaryText) + 4;
    }

    return BuiltPrompt(
      messages: [
        {'role': 'system', 'content': system.toString().trim()},
        ...extra,
        ...history,
        ...summaryMessages,
        // 与 SillyTavern 的 post-history instructions 一致：PHI 是历史之后
        // 的最后一条 system 消息，而不是混在开头那条 system 里。
        if (postHistory.trim().isNotEmpty)
          {'role': 'system', 'content': postHistory.trim()},
      ],
      approxTokens: used,
      droppedMessages: dropped,
      mainSource: mainSource,
      lore: PromptLoreStats(
        scopeBooks: loreScan.scopeBooks,
        scopeEntries: loreScan.scopeEntries,
        matched: loreScan.matched,
        injected: loreEntries,
      ),
      sections: {
        ...usedSections,
        if (postHistory.trim().isNotEmpty) 'jailbreak': postHistory.trim(),
      },
    );
  }

  /// Converts roleplay shorthand in user messages:
  /// “...” becomes explicit user speech and （...） an environment/action note.
  static String _formatUserRoleplay(String text) {
    var result = text;
    result = result.replaceAllMapped(
      RegExp(r'“([^”]*)”'),
      (match) => '[用户发言] ${match.group(1)!.trim()}',
    );
    result = result.replaceAllMapped(
      RegExp(r'（([^）]*)）'),
      (match) => '[用户环境/动作] ${match.group(1)!.trim()}',
    );
    return result;
  }

  /// 世界书是否属于本次对话的扫描范围。
  ///
  /// 只有「全局」世界书、绑定了当前角色的世界书，或角色卡上标记了该书
  /// （名称 / id）的世界书才会被扫描。未绑定且非全局的世界书不会生效，
  /// 「构建预览」会把这种情况单独提示出来。
  static bool _bookInScope(DemoCharacter character, Lorebook book) {
    if (book.isGlobal) return true;
    final linked = (book.linked ?? '').trim();
    if (linked.isNotEmpty && linked == character.name) return true;
    final bound = character.lorebook.trim();
    if (bound.isEmpty || bound == '未绑定') return false;
    return bound == book.name || bound == book.id;
  }

  static _LoreScan _scanLore(
    DemoCharacter character,
    String text,
  ) {
    final selected = <LoreEntry>[];
    final selectedIds = <String>{};
    final scopeBookList = AppStore.instance.lorebooks
        .where((book) => book.enabled && _bookInScope(character, book))
        .toList();
    final scopeBooks = scopeBookList.map((book) => book.name).toList();
    var scopeEntries = scopeBookList.fold<int>(
      0,
      (sum, book) =>
          sum +
          book.entries
              .where((e) => e.enabled && e.content.trim().isNotEmpty)
              .length,
    );

    bool containsKey(String haystack, LoreEntry entry, String key) {
      final raw = key.trim();
      if (raw.isEmpty) return false;
      final ignoreCase = !entry.caseSensitive;
      final source = ignoreCase ? haystack.toLowerCase() : haystack;
      if (raw.length >= 2 && raw.startsWith('/') && raw.endsWith('/')) {
        try {
          final pattern = RegExp(
            raw.substring(1, raw.length - 1),
            caseSensitive: !ignoreCase,
          );
          return pattern.hasMatch(source);
        } catch (_) {
          return false;
        }
      }
      final needle = ignoreCase ? raw.toLowerCase() : raw;
      if (!entry.matchWholeWords) return source.contains(needle);
      final escaped = RegExp.escape(needle);
      final pattern = RegExp(
        '(?<![A-Za-z0-9_])$escaped(?![A-Za-z0-9_])',
        caseSensitive: !ignoreCase,
      );
      return pattern.hasMatch(source);
    }

    bool primaryMatch(LoreEntry entry, String haystack) {
      if (entry.constant) return true;
      return entry.keys.any((key) => containsKey(haystack, entry, key));
    }

    bool secondaryMatch(LoreEntry entry, String haystack) {
      if (!entry.selective || entry.secondaryKeys.isEmpty) return true;
      final hits = entry.secondaryKeys
          .where((key) => containsKey(haystack, entry, key))
          .length;
      switch (entry.selectiveLogic) {
        case 'AND_ALL':
          return hits == entry.secondaryKeys.length;
        case 'NOT_ANY':
          return hits == 0;
        case 'NOT_ALL':
          return hits != entry.secondaryKeys.length;
        case 'AND_ANY':
        default:
          return hits > 0;
      }
    }

    bool probabilityPass(LoreEntry entry) {
      if (entry.probability >= 100) return true;
      if (entry.probability <= 0) return false;
      final seed = entry.id.hashCode ^ text.hashCode;
      return Random(seed).nextInt(100) < entry.probability;
    }

    void scanBooks(String haystack, {required bool recursionPass}) {
      for (final book in scopeBookList) {
        for (final entry in book.entries) {
          if (!entry.enabled || entry.content.trim().isEmpty) continue;
          if (selectedIds.contains(entry.id)) continue;
          if (recursionPass && entry.preventRecursion) continue;
          if (!primaryMatch(entry, haystack)) continue;
          if (!secondaryMatch(entry, haystack)) continue;
          if (!probabilityPass(entry)) continue;
          selected.add(entry);
          selectedIds.add(entry.id);
        }
      }
    }

    scanBooks(text, recursionPass: false);

    // Card fallback when the embedded book was never materialised.
    final raw = character.rawJson;
    if (selected.isEmpty && raw != null) {
      final data = raw['data'] is Map ? raw['data'] as Map : raw;
      final book = data['character_book'];
      if (book is Map) {
        final entries = book['entries'];
        if (entries is List) {
          var embedded = 0;
          for (final item in entries.whereType<Map>()) {
            if (item['enabled'] == false) continue;
            final keys = item['keys'] is List
                ? (item['keys'] as List).map((e) => e.toString()).toList()
                : <String>[];
            if (keys.isEmpty) continue;
            final matched = keys.any(
              (k) => k.trim().isNotEmpty && text.toLowerCase().contains(k.toLowerCase()),
            );
            if (!matched) continue;
            final content = (item['content'] ?? '').toString().trim();
            if (content.isEmpty) continue;
            final entry = LoreEntry(
              id: 'embedded-${selected.length}',
              name: item['comment']?.toString() ?? '',
              keys: keys,
              content: content,
              constant: item['constant'] == true,
              position: item['position'] == 'after_char' ? 'after' : 'before',
            );
            selected.add(entry);
            selectedIds.add(entry.id);
            embedded++;
          }
          if (embedded > 0) {
            scopeBooks.add('角色卡内嵌世界书');
            scopeEntries += embedded;
          }
        }
      }
    }

    // Recursive scan: activated content can trigger further entries.
    for (var pass = 0; pass < 5; pass++) {
      final recursionText = selected
          .where((e) => !e.excludeRecursion)
          .map((e) => e.content)
          .join('\n');
      if (recursionText.trim().isEmpty) break;
      final before = selected.length;
      scanBooks(recursionText, recursionPass: true);
      if (selected.length == before) break;
    }

    // Grouped entries: keep the highest-weight entry from each group.
    final grouped = <String, LoreEntry>{};
    final result = <LoreEntry>[];
    for (final entry in selected) {
      if (entry.group.trim().isEmpty) {
        result.add(entry);
      } else {
        final current = grouped[entry.group];
        if (current == null || entry.groupWeight > current.groupWeight) {
          grouped[entry.group] = entry;
        }
      }
    }
    result.addAll(grouped.values);
    result.sort((a, b) => b.order.compareTo(a.order));
    return _LoreScan(
      matched: result,
      scopeBooks: scopeBooks,
      scopeEntries: scopeEntries,
    );
  }

  static List<LoreEntry> _applyLoreBudget(
    List<LoreEntry> entries,
    Map<String, String> contents,
    int maxTokens,
  ) {
    if (maxTokens <= 0) return const <LoreEntry>[];
    final sorted = [...entries]..sort((a, b) => b.order.compareTo(a.order));
    final result = <LoreEntry>[];
    var used = 0;
    for (final entry in sorted) {
      final cost =
          estimateTokens(contents[entry.id] ?? entry.content) + 2;
      if (used + cost > maxTokens) continue;
      result.add(entry);
      used += cost;
    }
    return result;
  }
}

class _LoreScan {
  const _LoreScan({
    required this.matched,
    required this.scopeBooks,
    required this.scopeEntries,
  });

  final List<LoreEntry> matched;
  final List<String> scopeBooks;
  final int scopeEntries;
}

