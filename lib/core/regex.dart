import 'models.dart';

String applyRegexScripts(
  String text,
  List<RegexScript> scripts, {
  required String stage,
  String? characterName,
}) {
  var result = text;
  for (final script in scripts) {
    if (!script.enabled) continue;
    if (script.placement != 'both' && script.placement != stage) continue;
    final scope = script.scope.trim();
    if (scope.isNotEmpty &&
        scope != '全局' &&
        scope != 'global' &&
        scope != characterName) {
      continue;
    }
    final find = script.find.trim();
    if (find.isEmpty) continue;
    try {
      String pattern = find;
      var flags = '';
      if (find.startsWith('/') && find.lastIndexOf('/') > 0) {
        final last = find.lastIndexOf('/');
        pattern = find.substring(1, last);
        flags = find.substring(last + 1);
      }
      final regex = RegExp(
        pattern,
        caseSensitive: script.caseSensitive && !flags.contains('i'),
        multiLine: flags.contains('m'),
        dotAll: flags.contains('s'),
        unicode: flags.contains('u'),
      );
      result = result.replaceAllMapped(
        regex,
        (match) => _expandReplacement(script.replace, match),
      );
      if (result.length > 200000) break;
    } catch (_) {
      // Invalid user regex: skip it rather than breaking generation.
    }
  }
  return result;
}

/// 展开替换串里的捕获组引用，贴近 SillyTavern 的正则替换习惯：
/// `$1`–`$9` 取对应捕获组，`$&` 取整个匹配，`$$` 表示字面 `$`。
/// 其余字符按字面输出。
String _expandReplacement(String replacement, Match match) {
  final buffer = StringBuffer();
  for (var i = 0; i < replacement.length; i++) {
    final ch = replacement[i];
    if (ch == r'$' && i + 1 < replacement.length) {
      final next = replacement[i + 1];
      if (next == '&') {
        buffer.write(match.group(0) ?? '');
        i++;
        continue;
      }
      if (next == r'$') {
        buffer.write(r'$');
        i++;
        continue;
      }
      final digit = int.tryParse(next);
      if (digit != null && digit >= 1 && digit <= 9) {
        buffer.write(match.group(digit) ?? '');
        i++;
        continue;
      }
    }
    buffer.write(ch);
  }
  return buffer.toString();
}
