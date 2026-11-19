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
      result = result.replaceAllMapped(regex, (_) => script.replace);
      if (result.length > 200000) break;
    } catch (_) {
      // Invalid user regex: skip it rather than breaking generation.
    }
  }
  return result;
}
