import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/regex.dart';

void main() {
  test('regex scope limits to a character', () {
    final scripts = [
      RegexScript(
        id: 'r1',
        name: 'scoped',
        find: 'cat',
        replace: 'dog',
        placement: 'both',
        scope: 'Alice',
      ),
    ];
    expect(
      applyRegexScripts('cat', scripts, stage: 'display', characterName: 'Bob'),
      'cat',
    );
    expect(
      applyRegexScripts('cat', scripts, stage: 'display', characterName: 'Alice'),
      'dog',
    );
  });
}
