import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../utils/helpers.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onTap;
  final ValueChanged<Post>? onLike;

  const PostCard({super.key, required this.post, this.onTap, this.onLike});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  AnimationController? _likeCtrl;
  AnimationController? _particleCtrl;
  bool _showParticles = false;

  AnimationController get _likeController => _likeCtrl ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  AnimationController get _particleController => _particleCtrl ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void dispose() {
    _likeCtrl?.dispose();
    _particleCtrl?.dispose();
    super.dispose();
  }

  double _coverHeight() {
    if (widget.post.postType == 1) return 120;
    if (widget.post.voiceUrl != null && widget.post.voiceUrl!.isNotEmpty && widget.post.images.isEmpty) return 80;
    if (widget.post.images.isNotEmpty) {
      final ratio = widget.post.images.first.ratio ?? 1.2;
      final hRatio = 1.0 / ratio;
      final h = 170.0 * hRatio.clamp(0.65, 2.0);
      return h.clamp(110.0, 340.0);
    }
    return 120;
  }

  void _handleLike() {
    if (widget.onLike != null) {
      widget.onLike!(widget.post);
    }
    _likeController.forward(from: 0);
    if (!widget.post.isLiked) {
      setState(() => _showParticles = true);
      _particleController.forward(from: 0).then((_) {
        if (mounted) setState(() => _showParticles = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0x08000000),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCover(p),
            _buildBody(p),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(Post p) {
    if (p.postType == 1 && p.textTemplate != null && p.textTemplate! >= 0) {
      return _buildTextCover(p);
    }
    if (p.voiceUrl != null && p.voiceUrl!.isNotEmpty && p.images.isEmpty) {
      return _buildVoiceCover(p);
    }
    if (p.images.isNotEmpty) {
      return _buildImageCover(p);
    }
    if (p.postType == 1) {
      return _buildTextCover(p);
    }
    return _buildFallbackCover(p);
  }

  Widget _buildImageCover(Post p) {
    final h = _coverHeight();
    final isLive = p.images.isNotEmpty && p.images.first.videoUrl.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: fullUrl(p.images.first.url),
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFFF5F5F5)),
            errorWidget: (_, __, ___) => Container(color: const Color(0xFFF0F0F0), child: const Icon(Icons.image_not_supported, color: Color(0xFFCCCCCC), size: 24)),
          ),
          if (isLive)
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/icons/icon_live_photo.png', width: 12, height: 12),
                    const SizedBox(width: 2),
                    const Text('LIVE', style: TextStyle(fontSize: 9, color: Color(0xFF333333), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          if (p.images.length > 1)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${p.images.length}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
              ),
            ),
          Positioned(
            left: 6,
            bottom: 6,
            child: _buildViewBadge(p),
          ),
          if (p.voiceUrl != null && p.voiceUrl!.isNotEmpty)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [SizedBox(width: 1.5, height: 4, child: Container(color: Colors.white, width: 1.5)), SizedBox(width: 1.5, height: 7, child: Container(color: Colors.white, width: 1.5)), SizedBox(width: 1.5, height: 4, child: Container(color: Colors.white, width: 1.5))]),
                    const SizedBox(width: 3),
                    Text(fmtVoiceTime(p.voiceDuration), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextCover(Post p) {
    final title = p.title ?? '';
    final content = p.content ?? '';
    final displayTitle = title.isNotEmpty ? title : (content.isNotEmpty ? content : '');
    return Stack(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120, maxHeight: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: const BoxDecoration(color: Color(0xFFFFF0F0)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayTitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, color: Color(0xFFFF2442), fontWeight: FontWeight.w700, height: 1.6),
              ),
              if (content.isNotEmpty && title.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: const Color(0xFFFF2442).withValues(alpha: 0.6), height: 1.5),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 6,
          bottom: 6,
          child: _buildViewBadge(p),
        ),
      ],
    );
  }

  Widget _buildVoiceCover(Post p) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: const BoxDecoration(color: Color(0xFFFFF0F0)),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: Color(0xFFFF2442), shape: BoxShape.circle),
                child: const Center(child: Icon(Icons.play_arrow, color: Colors.white, size: 14)),
              ),
              const SizedBox(width: 8),
              Expanded(child: _buildWaveBars()),
              Text(fmtVoiceTime(p.voiceDuration), style: const TextStyle(fontSize: 13, color: Color(0xFFFF2442), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Positioned(
          left: 6,
          bottom: 6,
          child: _buildViewBadge(p),
        ),
      ],
    );
  }

  Widget _buildFallbackCover(Post p) {
    final text = p.content ?? p.title ?? '';
    final firstChar = text.isNotEmpty ? text[0] : '';
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: const BoxDecoration(color: Color(0xFFFFF0F0)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (firstChar.isNotEmpty)
                Text(firstChar, style: const TextStyle(fontSize: 48, color: Color(0x30FF2442), fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFFFF2442), height: 1.8),
              ),
            ],
          ),
        ),
        Positioned(
          left: 6,
          bottom: 6,
          child: _buildViewBadge(p),
        ),
      ],
    );
  }

  Widget _buildWaveBars() {
    return LayoutBuilder(builder: (_, c) {
      final count = (c.maxWidth / 5).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(count.clamp(1, 40), (i) {
          final h = (6.0 + (i * 7.0 + i * i * 3.0) % 18.0).clamp(4.0, 24.0);
          return Padding(
            padding: const EdgeInsets.only(right: 2.5),
            child: Container(width: 2.5, height: h, decoration: BoxDecoration(color: const Color(0xFFFF2442).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(1.5))),
          );
        }),
      );
    });
  }

  Widget _buildViewBadge(Post p) {
    final isPrivate = p.isPrivate == 1;
    if (p.viewsCount <= 0 && !isPrivate) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPrivate) ...[
            const Icon(Icons.lock_outline, size: 9, color: Colors.white),
            const SizedBox(width: 2),
          ],
          if (p.viewsCount > 0) ...[
            const Icon(Icons.visibility, size: 10, color: Colors.white),
            const SizedBox(width: 3),
            Text(fmtNum(p.viewsCount), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(Post p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.title != null && p.title!.isNotEmpty)
            Text(
              p.title!.length > 30 ? '${p.title!.substring(0, 30)}...' : p.title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF222222), height: 1.5),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildAvatar(p),
                    const SizedBox(width: 6),
                    Expanded(child: Text(p.nickname ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF666666), fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _handleLike,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 2, top: 4, bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: TweenSequence<double>([
                          TweenSequenceItem(tween: Tween(begin: 1, end: 1.35), weight: 20),
                          TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 30),
                          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 25),
                          TweenSequenceItem(tween: Tween(begin: 1.1, end: 1), weight: 25),
                        ]).animate(CurvedAnimation(parent: _likeController, curve: Curves.easeInOut)),
                        child: Icon(p.isLiked ? Icons.favorite : Icons.favorite_border, size: 17, color: p.isLiked ? const Color(0xFFFF2442) : const Color(0xFFBBBBBB)),
                      ),
                      const SizedBox(width: 3),
                      Text(fmtNum(p.likesCount), style: TextStyle(fontSize: 12, color: p.isLiked ? const Color(0xFFFF2442) : const Color(0xFFBBBBBB), fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Post p) {
    if (p.avatar != null && p.avatar!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: fullUrl(p.avatar),
          width: 22,
          height: 22,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _buildAvatarFallback(p),
        ),
      );
    }
    return _buildAvatarFallback(p);
  }

  Widget _buildAvatarFallback(Post p) {
    final color = getColorForId(p.userId);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          (p.nickname ?? '?').substring(0, 1),
          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildParticles() {
    final ctrl = _particleCtrl;
    if (ctrl == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(6, (i) {
            final angle = i * 60.0 * 3.14159 / 180;
            final dist = 14.0 * ctrl.value;
            final opacity = 1.0 - ctrl.value;
            return Transform.translate(
              offset: Offset(Math.cos(angle) * dist, Math.sin(angle) * dist),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(width: 3, height: 3, decoration: const BoxDecoration(color: Color(0xFFFF2442), shape: BoxShape.circle)),
              ),
            );
          }),
        );
      },
    );
  }
}

const List<Color> _fallbackColors = [
  Color(0xFFF5F5F5),
  Color(0xFFFFF0F0),
  Color(0xFFF0F5FF),
  Color(0xFFF0FFF0),
  Color(0xFFFFF8F0),
];

LinearGradient _parseGradient(String bg) {
  if (!bg.contains('gradient')) {
    return LinearGradient(colors: [_parseColor(bg), _parseColor(bg)]);
  }
  final hexPattern = RegExp(r'#[0-9a-fA-F]{6}');
  final matches = hexPattern.allMatches(bg).map((m) => _parseColor(m.group(0)!)).toList();
  if (matches.isEmpty) return LinearGradient(colors: [Colors.white, Colors.white]);
  if (matches.length == 1) return LinearGradient(colors: [matches[0], matches[0]]);
  return LinearGradient(
    begin: bg.contains('145') ? Alignment.topLeft : Alignment.topLeft,
    end: bg.contains('145') ? Alignment.bottomRight : Alignment.bottomRight,
    colors: [matches[0], matches[1]],
  );
}

Color _parseColor(String hex) {
  final h = hex.replaceAll('#', '');
  if (h.length != 6) return Colors.white;
  return Color(int.parse('FF$h', radix: 16));
}
