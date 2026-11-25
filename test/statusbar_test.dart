import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/statusbar.dart';

void main() {
  const initYaml = '''
时间:
  日期: 2024年12月6日
  时段: 下午
  星期: 周五
郑怡云:
  攻略阶段: 0
  当前位置: 公司
  警惕程度: 10
  是否怀孕: false
''';

  test('parseInit reads nested groups with typed scalars', () {
    final data = StatusBar.parseInit(initYaml);
    expect(data['时间'], isA<Map>());
    expect((data['时间'] as Map)['时段'], '下午');
    expect((data['郑怡云'] as Map)['攻略阶段'], 0);
    expect((data['郑怡云'] as Map)['警惕程度'], 10);
    expect((data['郑怡云'] as Map)['是否怀孕'], false);
    expect((data['郑怡云'] as Map)['当前位置'], '公司');
  });

  test('strip removes the UpdateVariable block but keeps the story', () {
    const reply = '她抬起头，眼神复杂。\n\n“你回来了。”\n\n'
        '<UpdateVariable>\n<Analysis>time passed</Analysis>\n'
        '<JSONPatch>\n[{"op":"delta","path":"/郑怡云/警惕程度","value":2}]\n'
        '</JSONPatch>\n</UpdateVariable>';
    final clean = StatusBar.strip(reply);
    expect(clean.contains('UpdateVariable'), false);
    expect(clean.contains('JSONPatch'), false);
    expect(clean.contains('她抬起头'), true);
    expect(clean.contains('“你回来了。”'), true);
  });

  test('extractOps + applyOps handles delta / replace / insert / remove / move', () {
    final data = StatusBar.parseInit(initYaml);
    const reply = '<UpdateVariable><JSONPatch>[\n'
        '{"op":"delta","path":"/郑怡云/警惕程度","value":3},\n'
        '{"op":"replace","path":"/时间/时段","value":"晚上"},\n'
        '{"op":"insert","path":"/郑怡云/新字段","value":"x"},\n'
        '{"op":"replace","path":"/郑怡云/攻略阶段","value":5},\n'
        '{"op":"remove","path":"/郑怡云/当前位置"},\n'
        '{"op":"move","from":"/时间/星期","to":"/时间/周几"}\n'
        ']</JSONPatch></UpdateVariable>';
    expect(StatusBar.hasUpdate(reply), true);
    final ops = StatusBar.extractOps(reply);
    expect(ops.length, 6);
    final next = StatusBar.applyOps(data, ops);
    final zheng = next['郑怡云'] as Map;
    final time = next['时间'] as Map;
    expect(zheng['警惕程度'], 13);
    expect(zheng['攻略阶段'], 5);
    expect(zheng['新字段'], 'x');
    expect(zheng.containsKey('当前位置'), false);
    expect(time['时段'], '晚上');
    expect(time['周几'], '周五');
    expect(time.containsKey('星期'), false);
    // 入参不被修改。
    expect((data['郑怡云'] as Map)['警惕程度'], 10);
  });

  test('applyOps skips readonly _ fields and tolerates invalid patches', () {
    final data = StatusBar.parseInit(initYaml);
    final ops = [
      {'op': 'replace', 'path': '/郑怡云/_readonly', 'value': 1},
      {'op': 'delta', 'path': '/郑怡云/警惕程度', 'value': 'not-a-number'},
    ];
    final next = StatusBar.applyOps(data, ops);
    expect((next['郑怡云'] as Map).containsKey('_readonly'), false);
    expect((next['郑怡云'] as Map)['警惕程度'], 10);
    expect(StatusBar.extractOps('no block here'), isEmpty);
    expect(StatusBar.extractOps('<UpdateVariable><JSONPatch>not json</JSONPatch></UpdateVariable>'), isEmpty);
  });

  test('format renders the tree back to indented text', () {
    final data = StatusBar.parseInit(initYaml);
    final text = StatusBar.format(data);
    expect(text.contains('时间:'), true);
    expect(text.contains('  时段: 下午'), true);
    expect(text.contains('郑怡云:'), true);
  });

  test('parseRanges extracts numeric max and drops the root wrapper', () {
    const rules = '''
<变量更新规则>
变量更新规则:
  郑怡云:
    攻略阶段:
      type: number
      range: 0~200
      category:
        0~15: 正常
    警惕程度:
      type: number
      range: 0~100
''';
    final ranges = StatusBar.parseRanges(rules);
    expect(ranges['郑怡云/攻略阶段'], 200);
    expect(ranges['郑怡云/警惕程度'], 100);
  });

  test('display keeps only story content; streaming partial block is hidden', () {
    const full = '她轻轻叹了口气。\n\n“这么晚了，怎么还不睡？”\n\n'
        '<UpdateVariable><Analysis>time passed</Analysis>'
        '<JSONPatch>[{"op":"replace","path":"/时间/时段","value":"深夜"}]</JSONPatch>'
        '</UpdateVariable>';
    expect(StatusBar.strip(full), '她轻轻叹了口气。\n\n“这么晚了，怎么还不睡？”');
    // 流式输出中：状态块还没闭合，也不应露出原始标签。
    const partial = '她轻轻叹了口气。\n\n<UpdateVariable><Analysis>calculating';
    expect(StatusBar.strip(partial), '她轻轻叹了口气。');
    // 没有状态栏的回复原样保留。
    expect(StatusBar.strip('普通回复，没有状态栏。'), '普通回复，没有状态栏。');
  });

  test('extractStatus parses <state> YAML block', () {
    const reply = '正文故事。\n<state>\n健康: 90\n理智: 80\n位置: 学校\n</state>';
    final s = StatusBar.extractStatus(reply);
    expect(s, isNotNull);
    expect(s!['健康'], 90);
    expect(s['位置'], '学校');
    expect(StatusBar.strip(reply), '正文故事。');
  });

  test('extractStatus parses <状态栏> pipe table', () {
    const reply = '故事。\n<状态栏>\n| 健康: 90 | 理智: 80 | 好感: 50 |\n</状态栏>';
    final s = StatusBar.extractStatus(reply);
    expect(s!['健康'], 90);
    expect(s['好感'], 50);
    expect(StatusBar.strip(reply), '故事。');
  });

  test('extractStatus parses status code fence', () {
    const reply = '故事。\n```\n健康: 90\n理智: 80\n```\n';
    final s = StatusBar.extractStatus(reply);
    expect(s!['健康'], 90);
    expect(StatusBar.strip(reply).contains('```'), false);
  });

  test('extractStatus parses trailing bare pipe table', () {
    const reply = '故事结尾。\n| 健康: 90 | 心情: 平静 |';
    final s = StatusBar.extractStatus(reply);
    expect(s!['健康'], 90);
    expect(s['心情'], '平静');
    expect(StatusBar.strip(reply), '故事结尾。');
  });

  test('strip removes placeholder and route_state markers', () {
    const reply = '故事。<StatusPlaceHolderImpl/>\n<route_state>ROUTE_STAGE=P1</route_state>';
    final clean = StatusBar.strip(reply);
    expect(clean.contains('StatusPlaceHolderImpl'), false);
    expect(clean.contains('route_state'), false);
    expect(clean.contains('故事'), true);
  });

  test('parseContent handles JSON object', () {
    final s = StatusBar.parseContent('{"健康": 90, "位置": "学校"}');
    expect(s!['健康'], 90);
    expect(s['位置'], '学校');
  });

  test('non-status code fence is preserved', () {
    const reply = '看这段代码：\n```python\nprint("hello")\nx = 1\n```';
    expect(StatusBar.strip(reply).contains('print'), true);
  });

  test('status-prefixed custom tag is detected (status keyword strategy)', () {
    const reply = '故事。\n<status_custom>\n好感: 50\n心情: 开心\n</status_custom>';
    final s = StatusBar.extractStatus(reply);
    expect(s!['好感'], 50);
    expect(s['心情'], '开心');
    expect(StatusBar.strip(reply), '故事。');
  });

  test('maintext narrative is preserved (no blank bubble), tags unwrapped', () {
    const greeting = '<maintext>\n她笑了，伸手<em></em>拍了拍你。\n</maintext>\n'
        '<details><summary>摘要</summary>\n时间：下午\n地点：家里\n</details>\n'
        '<Status_block>\n状态栏:\n  日期: "今天"\n</Status_block>';
    final stripped = StatusBar.strip(greeting);
    expect(stripped.contains('她笑了'), true);
    expect(stripped.contains('<maintext>'), false);
    expect(stripped.contains('<em>'), false);
    expect(stripped.contains('<details>'), false);
    expect(stripped.contains('摘要'), true);
    expect(stripped.contains('Status_block'), false);
    expect(stripped.trim().isEmpty, false);
  });

  test('card regex_scripts drive detection and stripping', () {
    final rawJson = {
      'data': {
        'extensions': {
          'regex_scripts': [
            {
              'findRegex': r'/<自定义状态>[\s\S]*?</自定义状态>/g',
              'replaceString': '',
            },
          ],
        },
      },
    };
    final patterns = StatusBar.cardPatterns(rawJson);
    expect(patterns, isNotEmpty);
    const reply = '正文。\n<自定义状态>\n体力: 80\n魔力: 60\n</自定义状态>';
    final s = StatusBar.extractStatus(reply, cardPatterns: patterns);
    expect(s!['体力'], 80);
    expect(s['魔力'], 60);
    expect(StatusBar.strip(reply, cardPatterns: patterns), '正文。');
  });

  test('markdown two-column table parses', () {
    const reply = '故事。\n```\n| 健康 | 90 |\n| 理智 | 80 |\n```';
    final s = StatusBar.extractStatus(reply);
    expect(s!['健康'], 90);
    expect(s['理智'], 80);
  });

  test('bracket 【键】值 format parses', () {
    final s = StatusBar.parseContent('【好感】50\n【心情】开心');
    expect(s!['好感'], 50);
    expect(s['心情'], '开心');
  });

  test('key=value format parses', () {
    final s = StatusBar.parseContent('hp=100\nmp=50');
    expect(s!['hp'], 100);
    expect(s['mp'], 50);
  });

  test('Status_block rich status is stripped and shown as readable raw text', () {
    const reply = '她抬头看了你一眼。\n\n'
        '<Status_block>\n'
        '📅 『日期：5月23日 星期三 | ⏰ 时间：晚上21点30分 | 📍 位置：家中客厅』\n'
        '<details><summary>[角色状态]</summary>\n'
        '```\n'
        '👨 『我的状态』\n'
        '- 🧑‍💼 当前行动：刚下班回到家。\n'
        '👧 『秦芷柔的状态』\n'
        '- 🧑‍💼 当前行动：坐在沙发一角。\n'
        '```\n'
        '</details>\n'
        '『剧情发展』\n'
        '1.[正常]继续观察。\n'
        '</Status_block>';
    // 剥离：回复正文里不再有状态块。
    final stripped = StatusBar.strip(reply);
    expect(stripped.contains('Status_block'), false);
    expect(stripped.contains('剧情发展'), false);
    expect(stripped.contains('她抬头看了你一眼'), true);
    // 提取：富文本 → __raw__，得到去掉 HTML/围栏的可读文本。
    final s = StatusBar.extractStatus(reply);
    expect(s, isNotNull);
    final raw = s!['__raw__'] as String;
    expect(raw.contains('日期'), true);
    expect(raw.contains('秦芷柔'), true);
    expect(raw.contains('<details>'), false);
    expect(raw.contains('```'), false);
  });

  test('simple key-value status still parses to fields (not raw)', () {
    const reply = '故事。\n<state>\n好感: 90\n心情: 开心\n</state>';
    final s = StatusBar.extractStatus(reply);
    expect(s!['好感'], 90);
    expect(s.containsKey('__raw__'), false);
  });
}
