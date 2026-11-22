import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/prompt.dart';
import '../core/store.dart';
import '../data/demo.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

/// 「构建预览」页：只展示系统段落的顺序（可上下调整并写回
/// `settings.promptOrder`）以及 Token / 统计信息，不再罗列每条 prompt 的正文。
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

    String inactiveHint(String key) {
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

    Widget sectionRow(int index) {
      final key = _order[index];
      final section = built.sections[key];
      final active = section != null;
      return SettingRow(
        icon: Icons.drag_indicator_rounded,
        title: _labels[key] ?? key,
        subtitle: active
            ? '已拼接 · 约 ${estimateTokens(section)} tok${sourceHint(key)}'
            : inactiveHint(key),
        value: '${index + 1}',
        iconColor: active ? p.amber : p.textTertiary,
        chevron: false,
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
                  value: '${settings.maxContext}',
                  label: '上下文上限',
                ),
              ),
            ],
          ),
        ),
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
        const SectionLabel('固定位置'),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SettingRow(
            icon: Icons.lock_outline_rounded,
            title: _labels[_phiKey]!,
            subtitle: phi == null
                ? '未设置，发送时跳过'
                : '固定为历史消息之后的最后一条 system 消息',
            value: phi == null ? '未设置' : '${estimateTokens(phi)} tok',
            iconColor: p.amber,
            chevron: false,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '系统段落按上面的顺序拼成第一条 system 消息，空段落自动跳过；'
          'PHI 始终作为历史消息之后的最后一条 system 消息发送。'
          '点击上下箭头会立即保存到 settings.promptOrder。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
        ),
      ],
    );
  }
}
