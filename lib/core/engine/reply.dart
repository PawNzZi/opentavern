/// 回复解析：剥离状态栏与快捷选项，留下正文。
library;

class StatusLine {
  StatusLine(this.label, this.value);

  final String label;
  final String value;

  Map<String, dynamic> toJson() => <String, dynamic>{'label': label, 'value': value};

  static StatusLine? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final String label = '${raw['label'] ?? ''}'.trim();
    final String value = '${raw['value'] ?? ''}'.trim();
    if (label.isEmpty && value.isEmpty) return null;
    return StatusLine(label, value);
  }
}

class ParsedReply {
  ParsedReply({
    required this.text,
    required this.statusLines,
    required this.quickOptions,
  });

  final String text;
  final List<StatusLine> statusLines;
  final List<String> quickOptions;
}

/// 解析模型回复里的结构化片段。
///
/// 支持的标签（与旧版酒馆一致）：
/// - `<Status>名称: 值 ／ 名称：值</Status>` 或 `<StatusBlock>`
/// - `<Options>选项一 | 选项二</Options>`（也支持换行分隔）
ParsedReply parseReply(String raw) {
  final List<StatusLine> statusLines = <StatusLine>[];
  final List<String> options = <String>[];
  String text = raw;

  final RegExp statusPattern = RegExp(
    r'<(Status|StatusBlock)>([\s\S]*?)</\1>',
    caseSensitive: false,
  );
  text = text.replaceAllMapped(statusPattern, (Match match) {
    final String body = match.group(2) ?? '';
    for (final String line in body.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final int idx = trimmed.indexOf(RegExp(r'[:：]'));
      if (idx <= 0) {
        statusLines.add(StatusLine('', trimmed));
        continue;
      }
      final String label = trimmed.substring(0, idx).trim();
      final String value = trimmed.substring(idx + 1).trim();
      if (label.isEmpty && value.isEmpty) continue;
      statusLines.add(StatusLine(label, value));
    }
    return '';
  });

  final RegExp optionsPattern = RegExp(
    r'<Options>([\s\S]*?)</Options>',
    caseSensitive: false,
  );
  text = text.replaceAllMapped(optionsPattern, (Match match) {
    final String body = match.group(1) ?? '';
    for (final String piece in body.split(RegExp(r'[|\n]'))) {
      final String trimmed = piece.trim();
      if (trimmed.isNotEmpty) options.add(trimmed);
    }
    return '';
  });

  // 媒体标签在单机版没有对应实现，直接去掉避免漏给用户
  text = text.replaceAll(RegExp(r'<media_(?:image|voice)>[\s\S]*?</media_(?:image|voice)>', caseSensitive: false), '');

  return ParsedReply(
    text: text.trim(),
    statusLines: statusLines.take(12).toList(growable: false),
    quickOptions: options.take(6).toList(growable: false),
  );
}
