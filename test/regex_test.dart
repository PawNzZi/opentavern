import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/regex.dart';

void main() {
  test('regex scripts apply by stage', () {
    final scripts = [
      RegexScript(
        id: 'r1',
        name: 'trim',
        find: r'/\n{3,}/g',
        replace: '\n\n',
        placement: 'display',
      ),
      RegexScript(
        id: 'r2',
        name: 'prompt only',
        find: 'secret',
        replace: 'hidden',
        placement: 'prompt',
      ),
    ];
    expect(
      applyRegexScripts('a\n\n\n\nb', scripts, stage: 'display'),
      'a\n\nb',
    );
    expect(
      applyRegexScripts('secret', scripts, stage: 'display'),
      'secret',
    );
    expect(
      applyRegexScripts('secret', scripts, stage: 'prompt'),
      'hidden',
    );
  });

  test('replacement expands capture groups like SillyTavern', () {
    final scripts = [
      RegexScript(
        id: 'g1',
        name: 'wrap',
        find: r'/\[(\w+)\]/g',
        replace: r'«$1»',
        placement: 'both',
      ),
    ];
    expect(
      applyRegexScripts('a [b] c [d]', scripts, stage: 'display'),
      'a «b» c «d»',
    );
  });

  test(r'$& inserts the whole match and $$ is a literal dollar', () {
    final scripts = [
      RegexScript(
        id: 'g2',
        name: 'dup',
        find: r'/\d+/g',
        replace: r'[$&]$$',
        placement: 'display',
      ),
    ];
    expect(applyRegexScripts('x42', scripts, stage: 'display'), r'x[42]$');
  });

  test('both placement applies at display and prompt; i flag ignores case', () {
    final scripts = [
      RegexScript(
        id: 'g3',
        name: 'ci',
        find: r'/hello/i',
        replace: 'hi',
        placement: 'both',
      ),
    ];
    expect(applyRegexScripts('HELLO', scripts, stage: 'display'), 'hi');
    expect(applyRegexScripts('Hello', scripts, stage: 'prompt'), 'hi');
  });

  test('disabled script is skipped', () {
    final scripts = [
      RegexScript(
        id: 'g4',
        name: 'off',
        find: 'a',
        replace: 'b',
        placement: 'both',
        enabled: false,
      ),
    ];
    expect(applyRegexScripts('a', scripts, stage: 'display'), 'a');
  });
}
