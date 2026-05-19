import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

final emojiRegexp = RegExp(r'\[emoji:([^\]]+)\]');

String stripEmojiMarkers(String text) {
  return text.replaceAllMapped(emojiRegexp, (m) => '[表情]');
}

InlineSpan buildEmojiTextSpan(
  String text, {
  TextStyle? style,
  double emojiSize = 22,
  TapGestureRecognizer? linkRecognizer,
}) {
  final emojiMatches = emojiRegexp.allMatches(text).toList();
  if (emojiMatches.isEmpty) {
    final cleaned = stripEmojiMarkers(text);
    return TextSpan(text: cleaned == text ? text : cleaned, style: style, recognizer: linkRecognizer);
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
        errorBuilder: (ctx, err, stack) => Container(
          width: emojiSize,
          height: emojiSize,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text('😀', style: TextStyle(fontSize: emojiSize * 0.6)),
        ),
      ),
    ));
    lastEnd = m.end;
  }
  if (lastEnd < text.length) {
    final remaining = text.substring(lastEnd);
    final cleaned = stripEmojiMarkers(remaining);
    spans.add(TextSpan(text: cleaned, style: style));
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
