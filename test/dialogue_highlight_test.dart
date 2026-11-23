import 'package:flutter_test/flutter_test.dart';

/// 与 chat.dart `_RichMessage._dialogue` 保持一致的对话匹配规则。
final _dialogue = RegExp(
  '\u201c[^\u201d]*\u201d|\u300c[^\u300d]*\u300d|\u300e[^\u300f]*\u300f|"[^"]*"',
);

void main() {
  test('dialogue regex matches all supported quote styles', () {
    expect(_dialogue.allMatches('他说“你好呀”然后离开').map((m) => m.group(0)),
        ['“你好呀”']);
    expect(_dialogue.allMatches('「收到。」她点头').map((m) => m.group(0)),
        ['「收到。」']);
    expect(_dialogue.allMatches('『真的吗』').map((m) => m.group(0)),
        ['『真的吗』']);
    expect(_dialogue.allMatches('he said "hello" loudly').map((m) => m.group(0)),
        ['"hello"']);
  });

  test('multiple dialogue segments are all captured', () {
    final text = '“第一句”中间叙述「第二句」结尾';
    expect(
      _dialogue.allMatches(text).map((m) => m.group(0)).toList(),
      ['“第一句”', '「第二句」'],
    );
  });

  test('plain text without quotes has no matches', () {
    expect(_dialogue.allMatches('只是普通的叙述文字').isEmpty, isTrue);
  });
}
