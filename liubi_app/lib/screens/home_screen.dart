import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../providers/post_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_skeleton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  TabController? _tabCtrl;
  final ValueNotifier<double> _tabAnimationValue = ValueNotifier(1.0);
  bool _showBackTop = false;
  int _prevCatCount = -1;

  final Map<int, ScrollController> _scrollCtrls = {};
  final ScrollController _cateScrollCtrl = ScrollController();
  final Map<int, GlobalKey> _cateTabKeys = {};

  double _cateBarHeight = 44.0;
  double _lastScrollOffset = 0;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLoad());
  }

  void _initLoad() {
    if (!mounted || _dataLoaded) return;
    _dataLoaded = true;
    final pp = Provider.of<PostProvider>(context, listen: false);
    pp.fetchPosts(refresh: true, sort: 'recommend');
    pp.fetchCategories();
  }

  @override
  void dispose() {
    _tabCtrl?.animation?.removeListener(_onTabAnimation);
    _tabCtrl?.removeListener(_onTabChanged);
    _tabCtrl?.dispose();
    _cateScrollCtrl.dispose();
    for (final c in _scrollCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureTabController(int catCount) {
    final newLength = 2 + catCount;
    if (_tabCtrl != null && _tabCtrl!.length == newLength) return;

    final prevIndex = _tabAnimationValue.value.round().clamp(0, newLength - 1);
    _tabCtrl?.removeListener(_onTabChanged);
    _tabCtrl?.animation?.removeListener(_onTabAnimation);
    _tabCtrl?.dispose();

    _tabCtrl = TabController(length: newLength, vsync: this, initialIndex: prevIndex);
    _tabCtrl!.addListener(_onTabChanged);
    _tabCtrl!.animation?.addListener(_onTabAnimation);

    _cateTabKeys.clear();
    for (int i = 1; i < newLength; i++) {
      _cateTabKeys[i] = GlobalKey();
    }

    while (_scrollCtrls.length < newLength) {
      final idx = _scrollCtrls.length;
      final ctrl = ScrollController();
      ctrl.addListener(() => _onTabScroll(idx));
      _scrollCtrls[idx] = ctrl;
    }
  }

  void _onTabAnimation() {
    if (_tabCtrl == null) return;
    final anim = _tabCtrl!.animation;
    if (anim == null) return;
    _tabAnimationValue.value = anim.value;
    _centerCateTab(anim.value);
  }

  void _onTabChanged() {
    if (_tabCtrl == null) return;
    if (_tabCtrl!.indexIsChanging) return;

    final newTab = _tabCtrl!.index;
    _tabAnimationValue.value = newTab.toDouble();
    _loadTabData(newTab);
    _cateBarHeight = 44.0;
    _lastScrollOffset = 0;
    setState(() {});
  }

  void _centerCateTab(double animValue) {
    if (!_cateScrollCtrl.hasClients) return;

    final fromIdx = animValue.floor().clamp(1, _tabCtrl!.length - 1);
    final toIdx = animValue.ceil().clamp(1, _tabCtrl!.length - 1);
    final t = animValue - animValue.floor();

    final fromBox = _getTabBox(fromIdx);
    final toBox = _getTabBox(toIdx);
    if (fromBox == null && toBox == null) return;

    final scrollViewWidth = _cateScrollCtrl.position.viewportDimension;
    final scrollOffset = _cateScrollCtrl.offset;

    double fromCenter = 0, toCenter = 0;
    if (fromBox != null) {
      final fromPos = fromBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
      fromCenter = scrollOffset + fromPos.dx + fromBox.size.width / 2;
    }
    if (toBox != null) {
      final toPos = toBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
      toCenter = scrollOffset + toPos.dx + toBox.size.width / 2;
    }

    double targetCenter;
    if (fromBox != null && toBox != null) {
      targetCenter = fromCenter + (toCenter - fromCenter) * t;
    } else {
      targetCenter = fromBox != null ? fromCenter : toCenter;
    }

    final targetScroll = (targetCenter - scrollViewWidth / 2).clamp(0.0, _cateScrollCtrl.position.maxScrollExtent);
    _cateScrollCtrl.jumpTo(targetScroll);
  }

  RenderBox? _getTabBox(int tabIdx) {
    if (tabIdx < 1) return null;
    final key = _cateTabKeys[tabIdx];
    if (key?.currentContext == null) return null;
    return key!.currentContext!.findRenderObject() as RenderBox?;
  }

  void _loadTabData(int tabIdx) {
    final pp = Provider.of<PostProvider>(context, listen: false);
    if (tabIdx == 0) {
      if (pp.followingPosts.isEmpty && !pp.followingLoading) pp.fetchPosts(refresh: true, following: true);
    } else if (tabIdx == 1) {
      if (pp.posts.isEmpty && !pp.loading) pp.fetchPosts(refresh: true, sort: 'recommend');
    } else {
      final catIdx = tabIdx - 2;
      if (catIdx < pp.categories.length) {
        final catId = pp.categories[catIdx].id;
        if ((pp.categoryPosts[catId] ?? []).isEmpty && !(pp.categoryLoading[catId] ?? false)) {
          pp.fetchCategoryPosts(catId, refresh: true, sort: 'recommend');
        }
      }
    }
  }

  void _onTabScroll(int tabIdx) {
    if (tabIdx != _tabAnimationValue.value.round()) return;
    final ctrl = _scrollCtrls[tabIdx];
    if (ctrl == null || !ctrl.hasClients) return;

    final offset = ctrl.offset;
    final delta = offset - _lastScrollOffset;

    double newHeight = _cateBarHeight;
    if (offset <= 0) {
      newHeight = 44.0;
    } else if (delta.abs() > 0.5) {
      if (delta > 0) {
        newHeight = (_cateBarHeight - delta * 0.6).clamp(0.0, 44.0);
      } else {
        newHeight = (_cateBarHeight - delta * 0.8).clamp(0.0, 44.0);
      }
    }

    _lastScrollOffset = offset;

    final show = offset > 300;
    if ((newHeight - _cateBarHeight).abs() > 0.5 || show != _showBackTop) {
      _cateBarHeight = newHeight;
      _showBackTop = show;
      setState(() {});
    }

    if (offset > ctrl.position.maxScrollExtent - 300) {
      _loadMore(tabIdx);
    }
  }

  void _loadMore(int tabIdx) {
    final pp = Provider.of<PostProvider>(context, listen: false);
    if (tabIdx == 0) {
      if (!pp.followingNoMore && !pp.followingLoading) pp.fetchPosts(following: true);
    } else if (tabIdx == 1) {
      if (!pp.noMore && !pp.loading) pp.fetchPosts(sort: 'recommend');
    } else {
      final catIdx = tabIdx - 2;
      if (catIdx < pp.categories.length) {
        final catId = pp.categories[catIdx].id;
        if (!(pp.categoryNoMore[catId] ?? false) && !(pp.categoryLoading[catId] ?? false)) {
          pp.fetchCategoryPosts(catId, sort: 'recommend');
        }
      }
    }
  }

  void _scrollToTop() {
    final ctrl = _scrollCtrls[_tabAnimationValue.value.round()];
    if (ctrl != null && ctrl.hasClients) {
      ctrl.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  void refresh() {
    final pp = Provider.of<PostProvider>(context, listen: false);
    final currentTab = _tabAnimationValue.value.round();
    if (currentTab == 0) {
      pp.fetchPosts(refresh: true, following: true);
    } else if (currentTab == 1) {
      pp.fetchPosts(refresh: true, sort: 'recommend');
    } else {
      final catIdx = currentTab - 2;
      if (catIdx < pp.categories.length) {
        pp.fetchCategoryPosts(pp.categories[catIdx].id, refresh: true, sort: 'recommend');
      }
    }
    _scrollToTop();
  }

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.of(context).padding.top;

    return Consumer<PostProvider>(
      builder: (_, pp, __) {
        final catCount = pp.categories.length;
        if (catCount != _prevCatCount) {
          _prevCatCount = catCount;
          _ensureTabController(catCount);
        }

        if (_tabCtrl == null) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F5F5),
            body: MasonrySkeletonGrid(),
          );
        }

        final currentTab = _tabAnimationValue.value.round();
        final showCateBar = currentTab >= 1;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Stack(
            children: [
              Column(
                children: [
                  _buildNav(statusBar),
                  if (showCateBar)
                    ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: _cateBarHeight / 44.0,
                        child: _buildCateBar(pp),
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: List.generate(_tabCtrl!.length, (idx) => _buildFeed(idx, pp)),
                    ),
                  ),
                ],
              ),
              if (_showBackTop) _buildBackTop(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNav(double statusBar) {
    return Container(
      padding: EdgeInsets.only(top: statusBar),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A000000),
            blurRadius: (6 * (1 - (1 - _cateBarHeight / 44.0) * 0.5)).clamp(0.0, 6.0),
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SizedBox(
        height: 44 * (1 - 0.08 * (1 - _cateBarHeight / 44.0)),
        child: Stack(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _tabAnimationValue,
              builder: (_, animValue, __) {
                final tab = animValue.round();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildNavTab(0, '关注', tab),
                    const SizedBox(width: 26),
                    _buildNavTab(1, '发现', tab),
                  ],
                );
              },
            ),
            Positioned(
              right: 14, top: 0, bottom: 0,
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/search'),
                child: const Center(child: Icon(Icons.search, size: 18, color: Color(0xFF666666))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTab(int idx, String label, int currentTab) {
    final isOn = currentTab == idx || (idx == 1 && currentTab >= 1);
    return GestureDetector(
      onTap: () => _tabCtrl?.animateTo(idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 50),
              style: TextStyle(
                fontSize: isOn ? 17 : 15,
                color: isOn ? const Color(0xFF222222) : const Color(0xFFAAAAAA),
                fontWeight: isOn ? FontWeight.w700 : FontWeight.w400,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              curve: Curves.easeOut,
              width: isOn ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(1.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCateBar(PostProvider pp) {
    final cats = pp.categories;
    return Container(
      height: 44,
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5))),
      child: Row(children: [
        Expanded(child: _buildCateScroll(cats)),
        GestureDetector(
          onTap: () => _showMorePanel(cats),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: const Icon(Icons.arrow_drop_down, size: 22, color: Color(0xFF999999)),
          ),
        ),
      ]),
    );
  }

  Widget _buildCateScroll(List cats) {
    return SingleChildScrollView(
      controller: _cateScrollCtrl,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(6, 0, 4, 0),
      child: ValueListenableBuilder<double>(
        valueListenable: _tabAnimationValue,
        builder: (_, animValue, __) {
          final currentTab = animValue.round();
          return Row(children: [
            _buildCateTab(1, '推荐', currentTab),
            for (int i = 0; i < cats.length; i++) _buildCateTab(i + 2, cats[i].name, currentTab),
          ]);
        },
      ),
    );
  }

  Widget _buildCateTab(int tabIdx, String name, int currentTab) {
    final isOn = currentTab == tabIdx;
    return GestureDetector(
      onTap: () => _tabCtrl?.animateTo(tabIdx),
      child: Container(
        key: _cateTabKeys[tabIdx],
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: 13,
              color: isOn ? const Color(0xFF222222) : const Color(0xFF999999),
              fontWeight: isOn ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Text(name),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: isOn ? 16 : 0,
            height: 2.5,
            decoration: BoxDecoration(
              color: const Color(0xFFFF2442),
              borderRadius: BorderRadius.circular(1.25),
            ),
          ),
        ]),
      ),
    );
  }

  void _showMorePanel(List cats) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 32, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 16), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)))),
          const Padding(padding: EdgeInsets.only(left: 16, bottom: 14), child: Text('全部分类', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF222222)))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              _buildMoreChip(1, '推荐'),
              for (int i = 0; i < cats.length; i++) _buildMoreChip(i + 2, cats[i].name),
            ]),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ]),
      ),
    );
  }

  Widget _buildMoreChip(int tabIdx, String name) {
    final isOn = _tabAnimationValue.value.round() == tabIdx;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _tabCtrl?.animateTo(tabIdx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: isOn ? const Color(0xFFFF2442) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)),
        child: Text(name, style: TextStyle(fontSize: 13, color: isOn ? Colors.white : const Color(0xFF888888), fontWeight: isOn ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Widget _buildFeed(int tabIdx, PostProvider pp) {
    if (tabIdx == 0) return _buildFollowFeed(pp);
    if (tabIdx == 1) return _buildDiscoverFeed(pp);
    final catIdx = tabIdx - 2;
    if (catIdx < pp.categories.length) {
      return _buildCategoryFeed(pp.categories[catIdx].id, pp);
    }
    return const EmptyState(message: '暂无内容');
  }

  Widget _buildFollowFeed(PostProvider pp) {
    if (pp.followingLoading && pp.followingPosts.isEmpty) {
      return const MasonrySkeletonGrid();
    }
    if (pp.followingPosts.isEmpty) return const EmptyState(message: '暂无关注内容');
    return CustomScrollView(
      controller: _scrollCtrls[0],
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () async => pp.fetchPosts(refresh: true, following: true)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 6,
            childCount: pp.followingPosts.length,
            itemBuilder: (ctx, idx) => RepaintBoundary(
              child: PostCard(
                post: pp.followingPosts[idx],
                onTap: () => Navigator.pushNamed(context, '/detail', arguments: pp.followingPosts[idx].id),
                onLike: (_) => pp.toggleLike(pp.followingPosts[idx].id),
              ),
            ),
          ),
        ),
        if (pp.followingLoading) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CupertinoActivityIndicator(radius: 10)))),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }

  Widget _buildDiscoverFeed(PostProvider pp) {
    final posts = pp.posts;
    if (pp.loading && posts.isEmpty) {
      return const MasonrySkeletonGrid();
    }
    if (posts.isEmpty) return const EmptyState(message: '暂无内容');
    return CustomScrollView(
      controller: _scrollCtrls[1],
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () async => pp.fetchPosts(refresh: true, sort: 'recommend')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 6,
            childCount: posts.length,
            itemBuilder: (ctx, idx) => RepaintBoundary(
              child: PostCard(
                post: posts[idx],
                onTap: () => Navigator.pushNamed(context, '/detail', arguments: posts[idx].id),
                onLike: (_) => pp.toggleLike(posts[idx].id),
              ),
            ),
          ),
        ),
        if (pp.loading) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CupertinoActivityIndicator(radius: 10)))),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }

  Widget _buildCategoryFeed(int catId, PostProvider pp) {
    final hasLoaded = pp.categoryPosts.containsKey(catId);
    final posts = pp.categoryPosts[catId] ?? [];
    final isLoading = pp.categoryLoading[catId] ?? false;

    if (!hasLoaded || (isLoading && posts.isEmpty)) {
      return const MasonrySkeletonGrid();
    }
    if (posts.isEmpty) return const EmptyState(message: '暂无内容');

    final tabIdx = _getTabIdxForCatId(catId, pp);
    return CustomScrollView(
      controller: tabIdx != null ? _scrollCtrls[tabIdx] : null,
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () async => pp.fetchCategoryPosts(catId, refresh: true, sort: 'recommend')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 6,
            childCount: posts.length,
            itemBuilder: (ctx, idx) => RepaintBoundary(
              child: PostCard(
                post: posts[idx],
                onTap: () => Navigator.pushNamed(context, '/detail', arguments: posts[idx].id),
                onLike: (_) => pp.toggleLike(posts[idx].id),
              ),
            ),
          ),
        ),
        if (isLoading) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CupertinoActivityIndicator(radius: 10)))),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }

  int? _getTabIdxForCatId(int catId, PostProvider pp) {
    for (int i = 0; i < pp.categories.length; i++) {
      if (pp.categories[i].id == catId) return i + 2;
    }
    return null;
  }

  Widget _buildBackTop() {
    return Positioned(
      right: 16, bottom: 90,
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
    );
  }
}
