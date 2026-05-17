import 'dart:async';
import 'package:flutter/material.dart';

class InAppNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show({
    required BuildContext context,
    required String title,
    required String body,
    String? avatarUrl,
    IconData? icon,
    Color? iconColor,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    dismiss();

    OverlayState? overlay;
    try {
      overlay = Overlay.of(context);
    } catch (_) {
      return;
    }
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (ctx) => _NotificationBanner(
        title: title,
        body: body,
        avatarUrl: avatarUrl,
        icon: icon,
        iconColor: iconColor,
        onTap: () {
          dismiss();
          onTap?.call();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _NotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final String? avatarUrl;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _NotificationBanner({
    required this.title,
    required this.body,
    this.avatarUrl,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _opacityAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    _ctrl.reverse().then((_) {
      InAppNotification.dismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -80 * (1 - _slideAnim.value)),
            child: Opacity(
              opacity: _opacityAnim.value,
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
              _handleDismiss();
            }
          },
          child: Container(
            margin: EdgeInsets.only(top: topPadding + 6, left: 10, right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildLeading(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF666666),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFFBBBBBB),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading() {
    if (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          widget.avatarUrl!.startsWith('http')
              ? widget.avatarUrl!
              : 'http://36.140.128.103:3000${widget.avatarUrl!}',
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildIconFallback(),
        ),
      );
    }
    return _buildIconFallback();
  }

  Widget _buildIconFallback() {
    final color = widget.iconColor ?? const Color(0xFFFF2442);
    final icon = widget.icon ?? Icons.notifications;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
