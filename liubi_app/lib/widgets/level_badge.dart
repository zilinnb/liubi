import 'package:flutter/material.dart';
import '../models/user.dart';

class LevelBadge extends StatelessWidget {
  final LevelInfo? levelInfo;
  final double fontSize;
  final double iconSize;
  final bool showTitle;

  const LevelBadge({
    super.key,
    required this.levelInfo,
    this.fontSize = 10,
    this.iconSize = 10,
    this.showTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (levelInfo == null) return const SizedBox.shrink();
    final level = levelInfo!.level;
    final title = levelInfo!.title;

    // 等级颜色：1-3灰色, 4-6蓝色, 7-9紫色, 10-12金色
    Color bgColor;
    Color textColor;
    if (level >= 10) {
      bgColor = const Color(0xFFFFF8E1);
      textColor = const Color(0xFFFF8F00);
    } else if (level >= 7) {
      bgColor = const Color(0xFFF3E5F5);
      textColor = const Color(0xFF8E24AA);
    } else if (level >= 4) {
      bgColor = const Color(0xFFE3F2FD);
      textColor = const Color(0xFF1565C0);
    } else {
      bgColor = const Color(0xFFF5F5F5);
      textColor = const Color(0xFF666666);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize + 1, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(fontSize * 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Lv.$level', style: TextStyle(fontSize: fontSize, color: textColor, fontWeight: FontWeight.w700, height: 1.2)),
          if (showTitle && title.isNotEmpty) ...[
            SizedBox(width: 2),
            Text(title, style: TextStyle(fontSize: fontSize - 1, color: textColor.withValues(alpha: 0.8), fontWeight: FontWeight.w500, height: 1.2)),
          ],
        ],
      ),
    );
  }
}
