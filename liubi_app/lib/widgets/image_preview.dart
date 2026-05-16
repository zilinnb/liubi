import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImagePreview {
  static void open(
    BuildContext context, {
    required String url,
    String? heroTag,
    Rect? sourceRect,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, animation, secondaryAnimation) => _PreviewPage(
          url: url,
          heroTag: heroTag,
          sourceRect: sourceRect,
          animation: animation,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return child;
        },
      ),
    );
  }
}

class _PreviewPage extends StatefulWidget {
  final String url;
  final String? heroTag;
  final Rect? sourceRect;
  final Animation<double> animation;

  const _PreviewPage({
    required this.url,
    this.heroTag,
    this.sourceRect,
    required this.animation,
  });

  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  double _prevScale = 1.0;
  Offset _offset = Offset.zero;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final statusBarH = MediaQuery.of(context).padding.top;

    Widget imageWidget = InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      onInteractionStart: (details) {
        if (details.pointerCount == 1) {
          _prevScale = _scale;
        }
      },
      onInteractionUpdate: (details) {
        if (details.pointerCount == 1 && _scale == 1.0) {
          setState(() => _isDragging = true);
        }
      },
      onInteractionEnd: (details) {
        if (_scale <= 1.0 && details.velocity.pixelsPerSecond.distance > 300) {
          Navigator.pop(context);
          return;
        }
        setState(() => _isDragging = false);
      },
      child: CachedNetworkImage(
        imageUrl: widget.url,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(child: CupertinoActivityIndicator(radius: 8, color: Colors.white)),
        errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
      ),
    );

    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        flightShuttleBuilder: (_, animation, __, ___, ____) {
          return FadeTransition(
            opacity: animation,
            child: CachedNetworkImage(imageUrl: widget.url, fit: BoxFit.contain),
          );
        },
        child: imageWidget,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: widget.animation,
        builder: (_, __) {
          final bgOpacity = Curves.easeOut.transform(widget.animation.value);
          return Container(
            color: Colors.black.withValues(alpha: bgOpacity * 0.95),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox.expand(
                    child: widget.heroTag == null
                        ? FadeTransition(
                            opacity: CurvedAnimation(parent: widget.animation, curve: Curves.easeOut),
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: widget.animation, curve: Curves.easeOut)),
                              child: imageWidget,
                            ),
                          )
                        : Center(child: imageWidget),
                  ),
                ),
                Positioned(
                  top: statusBarH + 8,
                  left: 8,
                  child: FadeTransition(
                    opacity: CurvedAnimation(parent: widget.animation, curve: Curves.easeOut),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
