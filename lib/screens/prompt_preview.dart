import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/prompt.dart';
import '../core/store.dart';
import '../design/glass.dart';
import '../design/scaffold.dart';
import '../design/settings_kit.dart';
import '../design/theme.dart';

class PromptPreviewPage extends StatefulWidget {
  const PromptPreviewPage({super.key});

  @override
  State<PromptPreviewPage> createState() => _PromptPreviewPageState();
}

class _PromptPreviewPageState extends State<PromptPreviewPage> {
  static const _labels = <String, String>{
    'main': '主提示词',
    'character': '角色卡设定',
    'summary': '前情提要',
    'lore': '世界书',
    'persona': '用户人格',
    'examples': '对话示例',
    'authorNote': '作者笔记',
  };

  late List<String> _order;

  @override
  void initState() {
    super.initState();
    final stored = AppStore.instance.settings.promptOrder;
    _order = stored.isEmpty ? _labels.keys.toList() : List.of(stored);
  }

  Future<void> _move(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _order.length) return;
    setState(() {
      final item = _order.removeAt(index);
      _order.insert(target, item);
    });
    final settings = AppStore.instance.settings.copyWith(
      promptOrder: List.of(_order),
    );
    AppStore.instance.settings = settings;
    await AppStore.instance.saveSettings();
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
    final character = store.characters.first;
    ChatSession? session;
    for (final s in store.sessions) {
      if (s.characterName == character.name) {
        session = s;
        break;
      }
    }
    session ??= ChatSession(
      id: 'preview',
      characterName: character.name,
      title: '预览',
      messages: [
        if (character.greeting.trim().isNotEmpty)
          ChatMessage(id: 'preview-greet', text: character.greeting),
      ],
    );
    final built = PromptBuilder.build(
      character: character,
      session: session,
      settings: store.settings,
    );
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
                  value: '${store.settings.maxContext}',
                  label: '上下文上限',
                ),
              ),
            ],
          ),
        ),
        const SectionLabel('系统段落顺序'),
        Glass(
          radius: 22,
          blur: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < _order.length; i++) ...[
                SettingRow(
                  icon: Icons.drag_indicator_rounded,
                  title: _labels[_order[i]] ?? _order[i],
                  value: '${i + 1}',
                  iconColor: p.amber,
                  chevron: false,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GlassCircleButton(
                        icon: Icons.keyboard_arrow_up_rounded,
                        size: 28,
                        iconSize: 15,
                        blur: 0,
                        onTap: () => _move(i, -1),
                      ),
                      const SizedBox(width: 2),
                      GlassCircleButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        size: 28,
                        iconSize: 15,
                        blur: 0,
                        onTap: () => _move(i, 1),
                      ),
                    ],
                  ),
                ),
                if (i != _order.length - 1) const Hairline(indent: 56),
              ],
            ],
          ),
        ),
        const SectionLabel('最终发送顺序'),
        for (var i = 0; i < built.messages.length; i++) ...[
          _PromptMessage(
            index: i,
            message: built.messages[i],
            palette: p,
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Text(
          '系统段落按上面的顺序拼接；预设附加条目排在系统消息之后、历史消息之前。',
          style: appText(10.5, FontWeight.w400, p.textTertiary, height: 1.5),
        ),
      ],
    );
  }
}

class _PromptMessage extends StatelessWidget {
  const _PromptMessage({
    required this.index,
    required this.message,
    required this.palette,
  });

  final int index;
  final Map<String, dynamic> message;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final role = (message['role'] ?? 'user').toString();
    final content = message['content'];
    final text = content is String
        ? content
        : content is List
            ? content
                .whereType<Map>()
                .map((e) => e['text']?.toString() ?? '[图片]')
                .join('\n')
            : content?.toString() ?? '';
    return Glass(
      radius: 20,
      blur: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TagBadge(
                '$index · ${role.toUpperCase()}',
                color: role == 'system'
                    ? palette.amber
                    : role == 'assistant'
                        ? palette.violet
                        : palette.sage,
              ),
              const Spacer(),
              Text(
                '${estimateTokens(text)} tok',
                style: appText(9.5, FontWeight.w400, palette.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text.isEmpty ? '（空）' : text,
            style: appText(11.5, FontWeight.w400, palette.textSecondary, height: 1.55),
          ),
        ],
      ),
    );
  }
}
