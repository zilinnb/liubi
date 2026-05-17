import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class WaterfallGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback? onLoadMore;
  final bool noMore;
  final bool loading;

  const WaterfallGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onLoadMore,
    this.noMore = false,
    this.loading = false,
  });

  static double estimateItemHeight(dynamic item) {
    double h = 5;
    final p = item;
    try {
      final images = p.images as List?;
      final postType = p.postType as int? ?? 0;
      final voiceUrl = p.voiceUrl as String?;
      final content = p.content as String?;
      final title = p.title as String?;
      if (images != null && images.isNotEmpty) {
        final ratio = (images[0].ratio ?? 1.2) as double;
        final hRatio = 1.0 / ratio;
        h += 170.0 * hRatio.clamp(0.65, 1.5);
      } else if (postType == 1) {
        h += 120;
      } else if (voiceUrl != null && voiceUrl!.isNotEmpty && (content == null || content.isEmpty)) {
        h += 80;
      } else {
        h += 120;
      }
      if (title != null && title.isNotEmpty) {
        h += title.length > 14 ? 34 : 22;
      }
      h += 36;
    } catch (_) {
      h += 120;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: items.length,
            itemBuilder: (ctx, idx) {
              return itemBuilder(ctx, items[idx], idx);
            },
          ),
        ),
        if (loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoActivityIndicator(radius: 8),
                const SizedBox(width: 8),
                const Text('加载中...', style: TextStyle(fontSize: 11, color: Color(0xFFCCCCCC))),
              ],
            ),
          ),
        if (noMore && items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
            child: const Text('- 已经到底了 -', style: TextStyle(fontSize: 11, color: Color(0xFFCCCCCC))),
          ),
      ],
    );
  }
}

class WaterfallScrollController extends ScrollController {
  void attachLoadMore(VoidCallback onLoadMore, {int threshold = 5}) {
    addListener(() {
      if (!hasClients) return;
      final max = position.maxScrollExtent;
      final current = offset;
      if (max - current < threshold * 200) {
        onLoadMore();
      }
    });
  }
}
