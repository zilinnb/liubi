import 'package:flutter/material.dart';

const String _baseUrl = 'http://36.140.128.103:3000';

String fullUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  return '$_baseUrl$url';
}

String fmtNum(int n) {
  if (n >= 10000) {
    return '${(n / 10000).toStringAsFixed(1)}w';
  } else if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(1)}k';
  }
  return n.toString();
}

String fmtTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  final date = DateTime.tryParse(dateStr);
  if (date == null) return '';
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inSeconds < 5) return '刚刚';
  if (diff.inSeconds < 60) return '${diff.inSeconds}秒前';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 30) return '${diff.inDays}天前';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}个月前';
  if (diff.inDays < 730) return '${(diff.inDays / 365).floor()}年前';
  return '${date.year}年${date.month}月${date.day}日';
}

String fmtVoiceTime(int? seconds) {
  if (seconds == null || seconds <= 0) return '0:00';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

const List<Color> avatarColors = [
  Color(0xFFFF2442),
  Color(0xFF1890FF),
  Color(0xFF52C41A),
  Color(0xFFFAAD14),
  Color(0xFF722ED1),
  Color(0xFF13C2C2),
];

Color getColorForId(int? id) {
  if (id == null || id <= 0) return avatarColors[0];
  return avatarColors[id % avatarColors.length];
}

const List<Map<String, String>> textTemplates = [
  {'bg': '#ffffff', 'color': '#222222'},
  {'bg': 'linear-gradient(135deg, #fff8e1, #ffecb3)', 'color': '#5d4037'},
  {'bg': 'linear-gradient(135deg, #e8f5e9, #c8e6c9)', 'color': '#2e7d32'},
  {'bg': 'linear-gradient(135deg, #1a1a2e, #16213e)', 'color': '#e0e0e0'},
  {'bg': 'linear-gradient(135deg, #fce4ec, #f8bbd0)', 'color': '#880e4f'},
  {'bg': 'linear-gradient(135deg, #e3f2fd, #bbdefb)', 'color': '#1565c0'},
  {'bg': 'linear-gradient(135deg, #efebe9, #d7ccc8)', 'color': '#3e2723'},
  {'bg': 'linear-gradient(135deg, #f3e5f5, #e1bee7)', 'color': '#6a1b9a'},
];

const List<Map<String, String>> cardTextTemplates = [
  {'bg': 'linear-gradient(145deg, #fff5f5, #ffe0e0)', 'color': '#c41d3a'},
  {'bg': 'linear-gradient(145deg, #f0f5ff, #d6e4ff)', 'color': '#1d39c4'},
  {'bg': 'linear-gradient(145deg, #f6ffed, #d9f7be)', 'color': '#389e0d'},
  {'bg': 'linear-gradient(145deg, #1a1a2e, #16213e)', 'color': '#e8e8e8'},
  {'bg': 'linear-gradient(145deg, #fff8e1, #ffecb3)', 'color': '#ad6800'},
  {'bg': 'linear-gradient(145deg, #f9f0ff, #efdbff)', 'color': '#531dab'},
  {'bg': 'linear-gradient(145deg, #e6fffb, #b5f5ec)', 'color': '#08979c'},
  {'bg': 'linear-gradient(145deg, #fff1f0, #ffccc7)', 'color': '#cf1322'},
];

const List<String> fallbackGradients = [
  'linear-gradient(145deg, #fafafa, #f0f0f0)',
  'linear-gradient(145deg, #fff5f5, #ffe8e8)',
  'linear-gradient(145deg, #f0f5ff, #e0eaff)',
  'linear-gradient(145deg, #f6ffed, #d9f7be)',
  'linear-gradient(145deg, #fff8e1, #ffe7ba)',
  'linear-gradient(145deg, #f9f0ff, #efdbff)',
];
