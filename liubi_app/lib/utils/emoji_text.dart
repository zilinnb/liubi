import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

final _emojiRegexp = RegExp(r'\[emoji:([^\]]+)\]');

InlineSpan buildEmojiTextSpan(
  String text, {
  TextStyle? style,
  double emojiSize = 22,
  TapGestureRecognizer? linkRecognizer,
}) {
  final emojiMatches = _emojiRegexp.allMatches(text).toList();
  if (emojiMatches.isEmpty) {
    return TextSpan(text: text, style: style, recognizer: linkRecognizer);
  }

  final spans = <InlineSpan>[];
  int lastEnd = 0;
  for (final m in emojiMatches) {
    if (m.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, m.start), style: style));
    }
    final filename = m.group(1)!;
    final assetPath = 'assets/emojis/$filename';
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Image.asset(
        assetPath,
        width: emojiSize,
        height: emojiSize,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => SizedBox(width: emojiSize, height: emojiSize),
      ),
    ));
    lastEnd = m.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: style));
  }
  return TextSpan(children: spans, style: style);
}

Widget buildEmojiRichText(
  String text, {
  TextStyle? style,
  double emojiSize = 22,
  int? maxLines,
  TextOverflow overflow = TextOverflow.clip,
}) {
  return RichText(
    text: buildEmojiTextSpan(text, style: style, emojiSize: emojiSize),
    maxLines: maxLines,
    overflow: overflow,
  );
}
