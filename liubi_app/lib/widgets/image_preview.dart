import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/helpers.dart';
import '../widgets/app_toast.dart';

class ImagePreview {
  static void open(
    BuildContext context, {
    required String url,
    String? heroTag,
    Rect? sourceRect,
    String? liveVideoUrl,
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
          liveVideoUrl: liveVideoUrl,
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
  final String? liveVideoUrl;

  const _PreviewPage({
    required this.url,
    this.heroTag,
    this.sourceRect,
    required this.animation,
    this.liveVideoUrl,
  });

  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoCtrl;
  bool _videoPlaying = false;
  bool _videoInitialized = false;
  bool _isSavingImage = false;

  bool get _isLive => widget.liveVideoUrl != null && widget.liveVideoUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isLive) {
      _initVideo();
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    if (!_isLive || _videoCtrl != null) return;
    _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(fullUrl(widget.liveVideoUrl!)));
    try {
      await _videoCtrl!.initialize();
      _videoCtrl!.setLooping(false);
      _videoCtrl!.addListener(_onVideoEnd);
      if (mounted) setState(() => _videoInitialized = true);
    } catch (_) {
      _videoCtrl?.dispose();
      _videoCtrl = null;
    }
  }

  void _onVideoEnd() {
    if (_videoCtrl != null && !_videoCtrl!.value.isPlaying && _videoCtrl!.value.position >= _videoCtrl!.value.duration) {
      if (_videoPlaying && mounted) {
        setState(() => _videoPlaying = false);
      }
    }
  }

  void _toggleLivePlay() {
    if (_videoPlaying) {
      _videoCtrl?.pause();
      _videoCtrl?.seekTo(Duration.zero);
      setState(() => _videoPlaying = false);
    } else {
      if (!_videoInitialized) {
        _initVideo().then((_) {
          if (_videoCtrl != null && _videoInitialized) {
            _videoCtrl!.seekTo(Duration.zero);
            _videoCtrl!.play();
            setState(() => _videoPlaying = true);
          }
        });
      } else {
        _videoCtrl!.seekTo(Duration.zero);
        _videoCtrl!.play();
        setState(() => _videoPlaying = true);
      }
    }
  }

  void _showSaveDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 32, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Expanded(child: _actionItem(Icons.save_alt, '保存图片', const Color(0xFF333333), () {
                Navigator.pop(ctx);
                _saveImage();
              })),
            ]),
          ),
          const Divider(height: 0.5, color: Color(0xFFF0F0F0)),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(ctx),
            child: Container(
              width: double.infinity,
              height: 50,
              alignment: Alignment.center,
              child: const Text('取消', style: TextStyle(fontSize: 16, color: Color(0xFF666666), fontWeight: FontWeight.w500)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _actionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Future<void> _saveImage() async {
    if (_isSavingImage) return;
    setState(() => _isSavingImage = true);
    try {
      final response = await Dio().get(widget.url, options: Options(responseType: ResponseType.bytes));
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/liubi_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(response.data);
      await Gal.putImage(filePath, album: '留笔');
      if (mounted) {
        AppToast.success(context, message: '已保存到相册');
      }
      try { await file.delete(); } catch (_) {}
    } catch (e) {
      if (mounted) AppToast.error(context, message: '保存失败');
    } finally {
      if (mounted) setState(() => _isSavingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    Widget imageWidget = InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      onInteractionEnd: (details) {
        if (details.velocity.pixelsPerSecond.distance > 300) {
          Navigator.pop(context);
        }
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
                  onLongPress: _showSaveDialog,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox.expand(
                    child: widget.heroTag == null
                        ? FadeTransition(
                            opacity: CurvedAnimation(parent: widget.animation, curve: Curves.easeOut),
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: widget.animation, curve: Curves.easeOut)),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  imageWidget,
                                  if (_videoPlaying && _videoCtrl != null && _videoInitialized)
                                    Center(
                                      child: AspectRatio(
                                        aspectRatio: _videoCtrl!.value.aspectRatio,
                                        child: VideoPlayer(_videoCtrl!),
                                      ),
                                    ),
                                ],
                              ),
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
                if (_isLive)
                  Positioned(
                    left: 16,
                    bottom: bottomPad + 24,
                    child: FadeTransition(
                      opacity: CurvedAnimation(parent: widget.animation, curve: Curves.easeOut),
                      child: GestureDetector(
                        onTap: _toggleLivePlay,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _videoPlaying
                                ? const Color(0xFFFF2442).withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset('assets/icons/icon_live_photo.png', width: 14, height: 14, color: _videoPlaying ? Colors.white : const Color(0xFF333333)),
                              const SizedBox(width: 3),
                              Text('LIVE', style: TextStyle(fontSize: 10, color: _videoPlaying ? Colors.white : const Color(0xFF333333), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            ],
                          ),
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
