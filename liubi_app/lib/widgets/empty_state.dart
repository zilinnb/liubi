import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String icon;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon = '!',
    required this.message,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Color(0xFFF0F0F0), shape: BoxShape.circle),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 18, color: Color(0xFFCCCCCC)))),
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFF999999))),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 15),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(18)),
                child: Text(actionText!, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
