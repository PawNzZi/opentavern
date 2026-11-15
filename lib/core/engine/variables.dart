/// 文本宏替换：`{{char}}`、`{{user}}`、`<bot>`、`<user>` 与自定义变量。
library;

String substituteMacros(
  String input, {
  required String charName,
  required String userName,
  Map<String, dynamic> variables = const <String, dynamic>{},
  Map<String, String> outlets = const <String, String>{},
}) {
  String output = input
      .replaceAll(RegExp(r'\{\{\s*char\s*\}\}', caseSensitive: false), charName)
      .replaceAll(RegExp(r'\{\{\s*user\s*\}\}', caseSensitive: false), userName)
      .replaceAll(RegExp(r'<(?:bot|char)>', caseSensitive: false), charName)
      .replaceAll(RegExp(r'<user>', caseSensitive: false), userName);

  for (final MapEntry<String, dynamic> entry in variables.entries) {
    output = output.replaceAll(
      RegExp('\\{\\{\\s*${RegExp.escape(entry.key)}\\s*\\}\\}'),
      '${entry.value ?? ''}',
    );
  }

  if (outlets.isNotEmpty) {
    output = output.replaceAllMapped(
      RegExp(r'\{\{\s*outlet::([^}]+)\}\}', caseSensitive: false),
      (Match match) => outlets[match.group(1)!.trim()] ?? '',
    );
  }

  // 未识别的宏直接去掉（避免把 {{x}} 原样发给模型）
  return output.replaceAll(RegExp(r'\{\{[^{}]+\}\}'), '');
}
