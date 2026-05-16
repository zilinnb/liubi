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
  double _navOpacity = 0.0;
  bool _showBackTop = false;
  bool _scrollScheduled = false;

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
    _scrollCtrl.addListener(_onScroll);
    _loadTrending();
  }

  @override
  void dispose() {
    _sortTabCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<Post> get _currentPosts => _sortIdx == 0 ? _hotPosts : _latestPosts;

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!_scrollCtrl.hasClients || !mounted) return;
      final offset = _scrollCtrl.offset;
      final statusBarH = MediaQuery.of(context).padding.top;
      final headerHeight = statusBarH + 160;
      final progress = (offset / headerHeight).clamp(0.0, 1.0);
      final show = offset > 300;
      if ((progress - _navOpacity).abs() > 0.01 || show != _showBackTop) {
        setState(() {
          _navOpacity = progress;
          _showBackTop = show;
        });
      }
    });
  }

  void _scrollToTop() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
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
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(statusBarH)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SortTabDelegate(tabController: _sortTabCtrl),
              ),
              if (_loading)
                const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator(radius: 14)))
              else if (_currentPosts.isEmpty)
                const SliverFillRemaining(child: Center(child: Text('暂无热门内容', style: TextStyle(fontSize: 14, color: Color(0xFF999999)))))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 6,
                    childCount: _currentPosts.length,
                    itemBuilder: (_, i) {
                      return PostCard(
                        post: _currentPosts[i],
                        onTap: () => Navigator.pushNamed(context, '/detail', arguments: _currentPosts[i].id),
                        onLike: (_) {},
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
          if (_navOpacity > 0.3)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.only(top: statusBarH),
                color: Colors.white.withValues(alpha: _navOpacity > 0.5 ? 1.0 : _navOpacity * 2),
                height: statusBarH + 44,
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      GestureDetector(onTap: () => Navigator.pop(context), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF222222)))),
                      Expanded(child: Center(child: Text('热门榜单', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))))),
                      const SizedBox(width: 46),
                    ],
                  ),
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

  Widget _buildHeader(double statusBarH) {
    return Container(
      height: statusBarH + 160,
      decoration: const BoxDecoration(
        color: Color(0xFFFF2442),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: statusBarH, left: 0, right: 0,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_back, size: 20, color: Colors.white))),
                  Expanded(child: Center(child: Text('热门榜单', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 30,
            child: Column(
              children: [
                const Icon(Icons.trending_up, size: 40, color: Colors.white),
                const SizedBox(height: 6),
                const Text('热门内容排行榜', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text('共 ${_currentPosts.length} 条', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortTabDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  _SortTabDelegate({required this.tabController});

  @override
  double get minExtent => 40;
  @override
  double get maxExtent => 40;

  @override
  bool shouldRebuild(covariant _SortTabDelegate oldDelegate) => false;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5))),
      child: TabBar(
        controller: tabController,
        labelColor: const Color(0xFFFF2442),
        unselectedLabelColor: const Color(0xFF666666),
        indicatorColor: const Color(0xFFFF2442),
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        tabs: const [Tab(text: '最热'), Tab(text: '最新')],
      ),
    );
  }
}
