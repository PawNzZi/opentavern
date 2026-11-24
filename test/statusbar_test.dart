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
}
