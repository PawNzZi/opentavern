/// 台词高亮：把成对引号里的内容（含引号）染成 #00AF69。
library;

import 'package:flutter/material.dart';

import 'theme.dart';

final RegExp _quotePattern = RegExp(
  r'''("[^"]*"|“[^”]*”|'[^']*'|‘[^’]*’|「[^」]*」)''',
);

class QuoteText extends StatelessWidget {
  const QuoteText(this.text, {super.key, required this.style, this.enabled = true});

  final String text;
  final TextStyle style;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || text.isEmpty) {
      return Text(text, style: style);
    }
    final List<TextSpan> spans = <TextSpan>[];
    int last = 0;
    for (final RegExpMatch match in _quotePattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: style.copyWith(color: TavernColors.quote),
      ));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    if (spans.isEmpty) {
      return Text(text, style: style);
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
