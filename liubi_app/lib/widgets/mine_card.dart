import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../utils/helpers.dart';

class MineCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onTap;
  final ValueChanged<Post>? onLike;

  const MineCard({super.key, required this.post, this.onTap, this.onLike});

  @override
  State<MineCard> createState() => _MineCardState();
}

class _MineCardState extends State<MineCard> with TickerProviderStateMixin {
  late AnimationController _likeCtrl;
  late AnimationController _particleCtrl;
  bool _showParticles = false;

  @override
  void initState() {
    super.initState();
    _likeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _likeCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  double _coverHeight() {
    if (widget.post.postType == 1) return 120;
    if (widget.post.voiceUrl != null && widget.post.voiceUrl!.isNotEmpty && widget.post.images.isEmpty) return 80;
    if (widget.post.images.isNotEmpty) {
      final ratio = widget.post.images.first.ratio ?? 1.2;
      final hRatio = 1.0 / ratio;
      final h = 170.0 * hRatio.clamp(0.65, 1.5);
      return h.clamp(110.0, 255.0);
    }
    return 120;
  }

  void _handleLike() {
    if (widget.onLike != null) widget.onLike!(widget.post);
    if (!widget.post.isLiked) {
      _likeCtrl.forward(from: 0);
      setState(() => _showParticles = true);
      _particleCtrl.forward(from: 0).then((_) => setState(() => _showParticles = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
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
    if (p.postType == 1 && p.textTemplate != null && p.textTemplate! >= 0) return _buildTextCover(p);
    if (p.voiceUrl != null && p.voiceUrl!.isNotEmpty && p.images.isEmpty) return _buildVoiceCover(p);
    if (p.images.isNotEmpty) return _buildImageCover(p);
    if (p.postType == 1) return _buildTextCover(p);
    return _buildFallbackCover(p);
  }

  Widget _buildImageCover(Post p) {
    final h = _coverHeight();
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
          if (p.status == 0)
            Positioned.fill(child: Center(child: _statusTag('审核中', const Color(0xFFFAAD14)))),
          if (p.status == 3)
            Positioned.fill(child: Center(child: _statusTag('已下架', Colors.black.withValues(alpha: 0.55)))),
        ],
      ),
    );
  }

  Widget _statusTag(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTextCover(Post p) {
    final idx = (p.textTemplate ?? 0) % cardTextTemplates.length;
    final tpl = cardTextTemplates[idx];
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 100, maxHeight: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(gradient: _parseGradient(tpl['bg']!)),
      child: Center(
        child: Text(p.content ?? '', maxLines: 5, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: _parseColor(tpl['color']!), height: 1.8)),
      ),
    );
  }

  Widget _buildVoiceCover(Post p) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF5F5), Color(0xFFFFE8E8)])),
      child: Row(
        children: [
          Container(width: 24, height: 24, decoration: const BoxDecoration(color: Color(0xFFFF2442), shape: BoxShape.circle), child: const Center(child: Icon(Icons.play_arrow, color: Colors.white, size: 14))),
          const SizedBox(width: 8),
          Expanded(child: _buildWaveBars()),
          Text(fmtVoiceTime(p.voiceDuration), style: const TextStyle(fontSize: 15, color: Color(0xFFFF2442), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFallbackCover(Post p) {
    final idx = (p.id ?? 0) % fallbackGradients.length;
    return Container(
      width: double.infinity,
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(gradient: _parseGradient(fallbackGradients[idx])),
      child: Center(child: Text(p.content ?? p.title ?? '', maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.8))),
    );
  }

  Widget _buildWaveBars() {
    return LayoutBuilder(builder: (_, c) {
      final count = (c.maxWidth / 6).floor();
      return Row(
        children: List.generate(count.clamp(1, 40), (i) {
          final h = (6.0 + (i * 7.0 + i * i * 3.0) % 18.0).clamp(4.0, 24.0);
          return Padding(padding: const EdgeInsets.only(right: 3), child: Container(width: 3, height: h, decoration: BoxDecoration(color: const Color(0xFFFF2442).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(1.5))));
        }),
      );
    });
  }

  Widget _buildBody(Post p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.title != null && p.title!.isNotEmpty)
            Text(p.title!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF222222), height: 1.5)),
          const SizedBox(height: 5),
          Row(
            children: [
              if (p.viewsCount > 0) ...[
                Icon(Icons.visibility_outlined, size: 11, color: const Color(0xFFBBBBBB)),
                const SizedBox(width: 2),
                Text(fmtNum(p.viewsCount), style: const TextStyle(fontSize: 10, color: Color(0xFFBBBBBB))),
              ],
              const Spacer(),
              GestureDetector(
                onTap: _handleLike,
                child: SizedBox(
                  width: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_showParticles) _buildParticles(),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(p.isLiked ? Icons.favorite : Icons.favorite_border, size: 12, color: p.isLiked ? const Color(0xFFFF2442) : const Color(0xFFBBBBBB)),
                        const SizedBox(width: 3),
                        Text(fmtNum(p.likesCount), style: TextStyle(fontSize: 11, color: p.isLiked ? const Color(0xFFFF2442) : const Color(0xFFBBBBBB))),
                      ]),
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

  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _particleCtrl,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(6, (i) {
            final angle = i * 60.0 * 3.14159 / 180;
            final dist = 14.0 * _particleCtrl.value;
            final opacity = 1.0 - _particleCtrl.value;
            return Transform.translate(
              offset: Offset(Math.cos(angle) * dist, Math.sin(angle) * dist),
              child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: Container(width: 3, height: 3, decoration: const BoxDecoration(color: Color(0xFFFF2442), shape: BoxShape.circle))),
            );
          }),
        );
      },
    );
  }
}

LinearGradient _parseGradient(String bg) {
  if (!bg.contains('gradient')) return LinearGradient(colors: [_parseColor(bg), _parseColor(bg)]);
  final hexPattern = RegExp(r'#[0-9a-fA-F]{6}');
  final matches = hexPattern.allMatches(bg).map((m) => _parseColor(m.group(0)!)).toList();
  if (matches.isEmpty) return LinearGradient(colors: [Colors.white, Colors.white]);
  if (matches.length == 1) return LinearGradient(colors: [matches[0], matches[0]]);
  return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [matches[0], matches[1]]);
}

Color _parseColor(String hex) {
  final h = hex.replaceAll('#', '');
  if (h.length != 6) return Colors.white;
  return Color(int.parse('FF$h', radix: 16));
}
