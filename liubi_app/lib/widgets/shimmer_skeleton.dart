import 'dart:math';
import 'package:flutter/material.dart';

class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final swipe = LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, -0.3),
              end: Alignment(-1.0 + 2.0 * _ctrl.value + 0.6, 0.3),
              colors: const [
                Color(0xFFE8E8E8),
                Color(0xFFF5F5F5),
                Color(0xFFE8E8E8),
              ],
              stops: const [0.0, 0.5, 1.0],
            );
            return swipe.createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: height,
            color: const Color(0xFFE8E8E8),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 13,
                  decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 120,
                  height: 13,
                  decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(color: Color(0xFFDDDDDD), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 50,
                      height: 11,
                      decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(4)),
                    ),
                    const Spacer(),
                    Container(
                      width: 30,
                      height: 11,
                      decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MasonrySkeletonGrid extends StatelessWidget {
  final int count;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsets padding;

  const MasonrySkeletonGrid({
    super.key,
    this.count = 6,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 6,
    this.mainAxisSpacing = 8,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 0),
  });

  @override
  Widget build(BuildContext context) {
    final rng = Random(42);
    final heights = List.generate(count, (_) => 100.0 + rng.nextDouble() * 120.0);

    return ShimmerLoading(
      child: Padding(
        padding: padding,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(crossAxisCount, (col) {
                final colItems = <int>[];
                for (int i = col; i < count; i += crossAxisCount) {
                  colItems.add(i);
                }
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: col == 0 ? 0 : crossAxisSpacing / 2,
                      right: col == crossAxisCount - 1 ? 0 : crossAxisSpacing / 2,
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < colItems.length; i++) ...[
                          SkeletonCard(height: heights[colItems[i]]),
                          if (i < colItems.length - 1) SizedBox(height: mainAxisSpacing),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
