import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> with TickerProviderStateMixin {
  List<Post> _hotPosts = [];
  List<Post> _latestPosts = [];
  bool _loading = true;
  int _sortIdx = 0;
  bool _showBackTop = false;
  final ValueNotifier<double> _collapse = ValueNotifier(0);

  late TabController _sortTabCtrl;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _sortTabCtrl = TabController(length: 2, vsync: this);
    _sortTabCtrl.addListener(() {
      if (_sortTabCtrl.indexIsChanging) return;
      final newIdx = _sortTabCtrl.index;
      if (newIdx != _sortIdx) {
        setState(() { _sortIdx = newIdx; });
        if (_currentPosts.isEmpty) _loadTrending();
      }
    });
    _loadTrending();
  }

  @override
  void dispose() {
    _sortTabCtrl.dispose();
    _scrollCtrl.dispose();
    _collapse.dispose();
    super.dispose();
  }

  List<Post> get _currentPosts => _sortIdx == 0 ? _hotPosts : _latestPosts;

  void _scrollToTop() {
    _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  Future<void> _loadTrending() async {
    setState(() => _loading = true);
    try {
      final type = _sortIdx == 0 ? 'hot' : 'latest';
      final res = await ApiService().get('/posts/trending', queryParameters: {'type': type, 'limit': 100});
      if (res['code'] == 200 && mounted) {
        final data = res['data'] as List? ?? [];
        setState(() {
          final posts = data.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
          if (_sortIdx == 0) { _hotPosts = posts; } else { _latestPosts = posts; }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                final show = notification.metrics.pixels > 300;
                if (show != _showBackTop) {
                  setState(() => _showBackTop = show);
                }
              }
              return false;
            },
            child: NestedScrollView(
              controller: _scrollCtrl,
              headerSliverBuilder: (ctx, _) => [
                SliverAppBar(
                  expandedHeight: statusBarH + 140,
                  pinned: true,
                  floating: false,
                  snap: false,
                  toolbarHeight: 44,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  leadingWidth: 46,
                  titleSpacing: 0,
                  leading: _buildNavLeading(),
                  title: _buildNavTitle(),
                  flexibleSpace: _buildFlexibleSpace(statusBarH),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TrendingTabDelegate(tabCtrl: _sortTabCtrl),
                ),
              ],
              body: TabBarView(
                controller: _sortTabCtrl,
                children: [
                  _buildPostList(_hotPosts),
                  _buildPostList(_latestPosts),
                ],
              ),
            ),
          ),
          if (_showBackTop)
            Positioned(
              right: 16, bottom: 80,
              child: GestureDetector(
                onTap: _scrollToTop,
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFFFF2442).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 28),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavLeading() {
    return ValueListenableBuilder<double>(
      valueListenable: _collapse,
      builder: (_, cp, __) {
        final iconColor = Color.lerp(Colors.white, const Color(0xFF333333), cp);
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(Icons.arrow_back, size: 22, color: iconColor),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavTitle() {
    return ValueListenableBuilder<double>(
      valueListenable: _collapse,
      builder: (_, cp, __) {
        return Opacity(
          opacity: cp.clamp(0.0, 1.0),
          child: const Text('热门榜单',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
        );
      },
    );
  }

  Widget _buildFlexibleSpace(double statusBarH) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final curH = constraints.biggest.height;
      final totalExpand = statusBarH + 140.0;
      final cp =
          (1 - ((curH - 44) / (totalExpand - 44)).clamp(0.0, 1.0)).clamp(0.0, 1.0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if ((_collapse.value - cp).abs() > 0.01) _collapse.value = cp;
      });

      final infoOpacity = (1 - cp * 1.5).clamp(0.0, 1.0);

      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF2442), Color(0xFFFF5A6E), Color(0xFFFF8A9E)],
              ),
            ),
          ),
          Positioned(
            top: statusBarH + 44,
            left: 16,
            right: 16,
            child: Opacity(
              opacity: infoOpacity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  const Icon(Icons.trending_up, size: 36, color: Colors.white),
                  const SizedBox(height: 6),
                  const Text('热门内容排行榜', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('共 ${_currentPosts.length} 条', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildPostList(List<Post> posts) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442)));
    }
    if (posts.isEmpty) {
      return const Center(child: Text('暂无热门内容', style: TextStyle(fontSize: 14, color: Color(0xFF999999))));
    }
    return RefreshIndicator(
      color: const Color(0xFFFF2442),
      onRefresh: _loadTrending,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childCount: posts.length,
              itemBuilder: (_, i) {
                return PostCard(
                  post: posts[i],
                  onTap: () => Navigator.pushNamed(context, '/detail', arguments: posts[i].id),
                  onLike: (_) {},
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingTabDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabCtrl;
  _TrendingTabDelegate({required this.tabCtrl});

  @override
  double get minExtent => 46;
  @override
  double get maxExtent => 46;

  @override
  bool shouldRebuild(covariant _TrendingTabDelegate oldDelegate) => tabCtrl != oldDelegate.tabCtrl;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: TabBar(
        controller: tabCtrl,
        labelColor: const Color(0xFF222222),
        unselectedLabelColor: const Color(0xFF999999),
        indicatorColor: const Color(0xFFFF2442),
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2.5,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        tabs: const [Tab(text: '最热'), Tab(text: '最新')],
      ),
    );
  }
}
