import 'package:flutter/material.dart';

class BackTopButton extends StatefulWidget {
  final bool show;
  final VoidCallback onTap;

  const BackTopButton({super.key, required this.show, required this.onTap});

  @override
  State<BackTopButton> createState() => _BackTopButtonState();
}

class _BackTopButtonState extends State<BackTopButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
  }

  @override
  void didUpdateWidget(covariant BackTopButton old) {
    super.didUpdateWidget(old);
    if (widget.show && !old.show) {
      _ctrl.forward();
    } else if (!widget.show && old.show) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show && !_ctrl.isAnimating) return const SizedBox.shrink();
    return Positioned(
      right: 16,
      bottom: 90,
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF2442).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
