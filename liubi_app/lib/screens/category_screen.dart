import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../providers/user_provider.dart';
import '../utils/helpers.dart';
import '../widgets/post_card.dart';
import '../widgets/app_toast.dart';

class CategoryScreen extends StatefulWidget {
  final int categoryId;
  const CategoryScreen({super.key, required this.categoryId});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _catInfo;
  bool _loading = true;
  bool _isFollowed = false;
  List<Post> _latestPosts = [];
  List<Post> _hotPosts = [];
  List<Post> _likedPosts = [];
  List<Post> _pinnedLatest = [];
  List<Post> _pinnedHot = [];
  List<Post> _pinnedLiked = [];
  int _totalPosts = 0;
  int _pinnedCount = 0;
  final ValueNotifier<double> _collapse = ValueNotifier(0);
  bool _showBackTop = false;

  late TabController _tabCtrl;
  final List<int> _pages = [1, 1, 1];
  final List<bool> _noMores = [false, false, false];
  final List<bool> _loadingMores = [false, false, false];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadCategoryInfo();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _collapse.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 300 && !_showBackTop) {
      setState(() => _showBackTop = true);
    } else if (_scrollController.offset <= 300 && _showBackTop) {
      setState(() => _showBackTop = false);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  List<Post> _postsForIndex(int idx) {
    switch (idx) {
      case 0: return _latestPosts;
      case 1: return _hotPosts;
      case 2: return _likedPosts;
      default: return [];
    }
  }

  List<Post> _pinnedPostsForIndex(int idx) {
    switch (idx) {
      case 0: return _pinnedLatest;
      case 1: return _pinnedHot;
      case 2: return _pinnedLiked;
      default: return [];
    }
  }

  void _setPostsForIndex(int idx, List<Post> posts) {
    switch (idx) {
      case 0: _latestPosts = posts; break;
      case 1: _hotPosts = posts; break;
      case 2: _likedPosts = posts; break;
    }
  }

  void _setPinnedPostsForIndex(int idx, List<Post> posts) {
    switch (idx) {
      case 0: _pinnedLatest = posts; break;
      case 1: _pinnedHot = posts; break;
      case 2: _pinnedLiked = posts; break;
    }
  }

  Future<void> _loadCategoryInfo() async {
    try {
      final res = await ApiService().get('/categories/${widget.categoryId}');
      if (res['code'] == 200 && mounted) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _catInfo = data;
          _isFollowed = data['is_followed'] == true;
          _loading = false;
        });
        _loadPosts(0, refresh: true);
        _loadPosts(1, refresh: true);
        _loadPosts(2, refresh: true);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPosts(int sortIdx, {bool refresh = false}) async {
    if (refresh) {
      _pages[sortIdx] = 1;
      _noMores[sortIdx] = false;
    }
    if (_loadingMores[sortIdx]) return;
    _loadingMores[sortIdx] = true;

    try {
      final sortValues = ['latest', 'hot', 'most_liked'];
      final res = await ApiService().get('/categories/${widget.categoryId}/posts', queryParameters: {
        'page': _pages[sortIdx],
        'pageSize': 20,
        'sort': sortValues[sortIdx],
      });
      if (res['code'] == 200 && mounted) {
        final data = res['data'] as Map<String, dynamic>;
        final list = data['list'] as List;
        final allPosts = list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
        final pinned = allPosts.where((p) => p.isPinned == 1).toList();
        final regular = allPosts.where((p) => p.isPinned != 1).toList();
        _totalPosts = data['total'] as int? ?? 0;
        _pinnedCount = data['pinned_count'] as int? ?? 0;

        setState(() {
          if (refresh) {
            _setPinnedPostsForIndex(sortIdx, pinned);
          }
          final current = _postsForIndex(sortIdx);
          _setPostsForIndex(sortIdx, refresh ? regular : [...current, ...regular]);
          _noMores[sortIdx] = _postsForIndex(sortIdx).length >= (_totalPosts - _pinnedCount);
          if (!_noMores[sortIdx]) _pages[sortIdx]++;
        });
      }
    } catch (_) {}
    _loadingMores[sortIdx] = false;
  }

  void _toggleFollow() async {
    try {
      final res = await ApiService().post('/categories/${widget.categoryId}/follow');
      if (res['code'] == 200 && mounted) {
        final followed = res['data']?['followed'] as bool? ?? !_isFollowed;
        setState(() => _isFollowed = followed);
        AppToast.success(context, message: followed ? '已关注' : '已取消关注');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442)))
          : Stack(
              children: [
                NestedScrollView(
                  controller: _scrollController,
                  headerSliverBuilder: (ctx, _) => [
                    SliverAppBar(
                      expandedHeight: statusBarH + 150,
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
                      delegate: _TabCardDelegate(tabCtrl: _tabCtrl),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildPostList(0),
                      _buildPostList(1),
                      _buildPostList(2),
                    ],
                  ),
                ),
                if (_showBackTop)
                  Positioned(
                    right: 16,
                    bottom: 140,
                    child: GestureDetector(
                      onTap: _scrollToTop,
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
                            BoxShadow(
                              color: const Color(0xFFFF2442).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: _loading ? null : _buildFAB(),
    );
  }

  Widget _buildNavLeading() {
    return ValueListenableBuilder<double>(
      valueListenable: _collapse,
      builder: (_, cp, __) {
        final iconColor = Color.lerp(Colors.white, const Color(0xFF222222), cp);
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(Icons.arrow_back, size: 20, color: iconColor),
          ),
        );
      },
    );
  }

  Widget _buildNavTitle() {
    final name = _catInfo?['name'] ?? '分类';
    final color = _catInfo?['color'] as String? ?? '';
    final icon = _catInfo?['icon'] as String? ?? '';

    return ValueListenableBuilder<double>(
      valueListenable: _collapse,
      builder: (_, cp, __) {
        final showTitle = cp > 0.7;
        if (!showTitle) return const SizedBox.shrink();
        final textColor = Color.lerp(Colors.white, const Color(0xFF222222), cp);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.isNotEmpty ? _parseColor(color) : getColorForId(widget.categoryId),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
              ),
              alignment: Alignment.center,
              child: Text(
                icon.isNotEmpty ? icon : (name.isNotEmpty ? name[0] : '?'),
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFlexibleSpace(double statusBarH) {
    final name = _catInfo?['name'] ?? '分类';
    final desc = _catInfo?['description'] ?? '';
    final cover = _catInfo?['cover'] as String? ?? '';
    final icon = _catInfo?['icon'] as String? ?? '';
    final color = _catInfo?['color'] as String? ?? '';
    final followCount = _catInfo?['follow_count'] as int? ?? 0;
    final postCount = _catInfo?['post_count'] as int? ?? 0;
    final heat = _catInfo?['heat'] as int? ?? 0;
    final authorCount = _catInfo?['author_count'] as int? ?? 0;

    return LayoutBuilder(builder: (ctx, constraints) {
      final curH = constraints.biggest.height;
      final totalExpand = statusBarH + 150.0;
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover.isNotEmpty)
                  CachedNetworkImage(imageUrl: fullUrl(cover), fit: BoxFit.cover)
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF2442), Color(0xFFFF5A6E), Color(0xFFFF8A9E)],
                      ),
                    ),
                  ),
                Container(color: Colors.black.withValues(alpha: 0.06)),
              ],
            ),
          ),

          Positioned(
            top: statusBarH + 44,
            left: 16,
            right: 16,
            child: Opacity(
              opacity: infoOpacity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color.isNotEmpty ? _parseColor(color) : getColorForId(widget.categoryId),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          icon.isNotEmpty ? icon : (name.isNotEmpty ? name[0] : '?'),
                          style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (desc.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  desc,
                                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleFollow,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: _isFollowed ? null : const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
                            color: _isFollowed ? Colors.white.withValues(alpha: 0.25) : null,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isFollowed ? Colors.white.withValues(alpha: 0.4) : Colors.transparent,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            _isFollowed ? '已关注' : '关注',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _bgStatItem(fmtNum(followCount), '关注'),
                      const SizedBox(width: 16),
                      _bgStatItem(fmtNum(postCount), '帖子'),
                      const SizedBox(width: 16),
                      _bgStatItem(fmtNum(heat), '热度'),
                      const SizedBox(width: 16),
                      _bgStatItem(fmtNum(authorCount), '作者'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: statusBarH + 44,
            child: Container(
              color: Colors.white.withValues(alpha: cp > 0.5 ? 1.0 : (cp * 2).clamp(0.0, 1.0)),
            ),
          ),
        ],
      );
    });
  }

  Widget _bgStatItem(String count, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 1),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildPinnedItem(Post post) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pushNamed(context, '/detail', arguments: post.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2442),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('置顶', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                post.title,
                style: const TextStyle(fontSize: 15, color: Color(0xFF222222), fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(fmtNum(post.commentsCount), style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
            const SizedBox(width: 4),
            const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList(int sortIdx) {
    final pinned = _pinnedPostsForIndex(sortIdx);
    final posts = _postsForIndex(sortIdx);
    final hasPinned = pinned.isNotEmpty;

    if (posts.isEmpty && !hasPinned && !_loadingMores[sortIdx]) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.note_outlined, size: 48, color: Color(0xFFDDDDDD)),
                  SizedBox(height: 12),
                  Text('暂无内容', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        if (hasPinned)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            sliver: SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Column(children: pinned.map((p) => _buildPinnedItem(p)).toList()),
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childCount: posts.length + (_noMores[sortIdx] ? 0 : 1),
            itemBuilder: (ctx, idx) {
              if (idx == posts.length) {
                _loadPosts(sortIdx);
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CupertinoActivityIndicator(radius: 10)),
                );
              }
              return RepaintBoundary(
                child: PostCard(
                  post: posts[idx],
                  onTap: () => Navigator.pushNamed(context, '/detail', arguments: posts[idx].id),
                  onLike: (_) {},
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFAB() {
    final isRestricted = _catInfo?['publish_restriction'] == 1;
    final isAdmin = Provider.of<UserProvider>(context, listen: false).userInfo?.role == 1;
    if (isRestricted && !isAdmin) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/publish', arguments: widget.categoryId),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF2442).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.edit, size: 22, color: Colors.white),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return getColorForId(widget.categoryId);
  }
}

class _TabCardDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabCtrl;
  _TabCardDelegate({required this.tabCtrl});

  @override
  double get minExtent => 46;
  @override
  double get maxExtent => 46;

  @override
  Widget build(BuildContext context, _, __) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
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
        tabs: const [
          Tab(text: '最新'),
          Tab(text: '最热'),
          Tab(text: '最赞'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabCardDelegate o) => tabCtrl != o.tabCtrl;
}
