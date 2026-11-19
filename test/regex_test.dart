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
}
