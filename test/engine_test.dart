import 'package:flutter_test/flutter_test.dart';
import 'package:open_tavern/core/engine/memory.dart';
import 'package:open_tavern/core/engine/prompt.dart';
import 'package:open_tavern/core/engine/reply.dart';
import 'package:open_tavern/core/engine/variables.dart';
import 'package:open_tavern/core/engine/worldbook.dart';
import 'package:open_tavern/core/models/tavern_card.dart';
import 'package:open_tavern/core/settings/app_settings.dart';

TavernWorldEntry _entry({
  required String id,
  String comment = '',
  List<String> keys = const <String>[],
  String content = '',
  bool constant = false,
  int position = 0,
}) {
  return TavernWorldEntry(
    id: id,
    comment: comment,
    keys: keys,
    content: content,
    constant: constant,
    position: position,
  );
}

void main() {
  group('世界书激活', () {
    test('关键词命中与常驻', () {
      final List<ActivatedEntry> result = activateEntries(
        <TavernWorldEntry>[
          _entry(id: 'a', keys: <String>['书房'], content: '书房里有一盏台灯。'),
          _entry(id: 'b', keys: <String>['月亮'], content: '月亮很圆。'),
          _entry(id: 'c', constant: true, content: '常驻设定。'),
        ],
        recentTexts: <String>['我走进书房，看到你。'],
      );
      expect(result.map((ActivatedEntry e) => e.entry.id).toSet(), <String>{'a', 'c'});
    });

    test('递归激活', () {
      final List<ActivatedEntry> result = activateEntries(
        <TavernWorldEntry>[
          _entry(id: 'a', keys: <String>['书房'], content: '书房里有暗门。'),
          _entry(id: 'b', keys: <String>['暗门'], content: '暗门后面是密室。'),
        ],
        recentTexts: <String>['我进了书房。'],
        recursionDepth: 2,
      );
      expect(result.map((ActivatedEntry e) => e.entry.id).toSet(), <String>{'a', 'b'});
    });

    test('预算不够时不激活', () {
      final List<ActivatedEntry> result = activateEntries(
        <TavernWorldEntry>[
          _entry(id: 'a', keys: <String>['书房'], content: 'x' * 500),
        ],
        recentTexts: <String>['书房'],
        maxTokens: 10,
      );
      expect(result, isEmpty);
    });
  });

  group('宏替换', () {
    test('角色名与用户名', () {
      final String out = substituteMacros(
        '{{char}} 对 {{user}} 说：<user> 你好。',
        charName: '小龙',
        userName: '阿明',
      );
      expect(out, '小龙 对 阿明 说：阿明 你好。');
    });

    test('未知宏被清除', () {
      expect(
        substituteMacros('前缀 {{unknown}} 后缀', charName: 'A', userName: 'B'),
        '前缀  后缀',
      );
    });
  });

  group('回复解析', () {
    test('状态栏与快捷选项', () {
      final ParsedReply parsed = parseReply(
        '她笑了笑。\n<Status>好感: 12\n地点：书房</Status>\n<Options>继续 | 离开</Options>',
      );
      expect(parsed.text, '她笑了笑。');
      expect(parsed.statusLines.length, 2);
      expect(parsed.statusLines.first.label, '好感');
      expect(parsed.statusLines.first.value, '12');
      expect(parsed.quickOptions, <String>['继续', '离开']);
    });

    test('媒体标签被移除', () {
      final ParsedReply parsed = parseReply('正文<media_image>画面</media_image>');
      expect(parsed.text, '正文');
    });
  });

  group('提示词组装', () {
    test('按顺序拼段落并带历史', () {
      final AppSettings settings = AppSettings.instance;
      final BuiltPrompt prompt = buildPrompt(
        character: <String, dynamic>{
          'name': '小龙',
          'description': '一条小龙',
          'personality': '傲娇',
          'scenario': '山洞',
          'systemPrompt': '',
          'example': '',
        },
        worlds: <TavernWorld>[
          TavernWorld(
            id: 'w1',
            name: '世界',
            entries: <TavernWorldEntry>[
              TavernWorldEntry(id: 'e1', keys: <String>['山洞'], content: '山洞很冷。'),
            ],
          ),
        ],
        chat: <String, dynamic>{
          'messages': <dynamic>[
            <String, dynamic>{'id': 'm1', 'role': 'assistant', 'text': '你来了。'},
          ],
          'variables': <String, dynamic>{},
        },
        userText: '我进山洞了',
        settings: settings,
      );
      expect(prompt.system.contains('【角色描述】'), isTrue);
      expect(prompt.system.contains('山洞很冷。'), isTrue);
      expect(prompt.user.contains('小明') || prompt.user.contains('你'), isTrue);
    });
  });

  group('记忆压缩', () {
    test('只折叠逐字窗口之外的部分', () {
      final List<dynamic> messages = <dynamic>[
        for (int i = 0; i < 10; i++)
          <String, dynamic>{'id': 'm$i', 'role': i.isEven ? 'user' : 'assistant', 'text': '内容$i'},
      ];
      final MemoryPlan plan = planCompaction(messages: messages, historyLimit: 4, memory: null);
      expect(plan.tail, 4);
      expect(plan.foldable, 6);
      expect(plan.start, 0);
      expect(plan.end, 6);
    });

    test('已经压缩过的部分不重复折叠', () {
      final List<dynamic> messages = <dynamic>[
        for (int i = 0; i < 10; i++)
          <String, dynamic>{'id': 'm$i', 'role': 'user', 'text': '内容$i'},
      ];
      final MemoryPlan plan = planCompaction(
        messages: messages,
        historyLimit: 4,
        memory: <String, dynamic>{'throughMessageId': 'm2', 'summary': '旧摘要'},
      );
      expect(plan.start, 3);
      expect(plan.foldable, 3);
    });

    test('transcript 带说话人', () {
      final String text = transcriptOf(
        <dynamic>[
          <String, dynamic>{'id': 'm1', 'role': 'user', 'text': '你好'},
          <String, dynamic>{'id': 'm2', 'role': 'assistant', 'text': '嗯。'},
        ],
        0,
        2,
        userName: '阿明',
        characterName: '小龙',
      );
      expect(text, '阿明：你好\n小龙：嗯。');
    });
  });
}
