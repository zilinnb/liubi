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
  List<Post> _pinnedPostsLatest = [];
  List<Post> _pinnedPostsHot = [];
  List<Post> _pinnedPostsLiked = [];
  int _totalPosts = 0;
  int _pinnedCount = 0;
  double _navOpacity = 0.0;
  bool _showBackTop = false;

  late TabController _sortTabCtrl;
  final List<String> _sortValues = ['latest', 'hot', 'most_liked'];
  final List<int> _pages = [1, 1, 1];
  final List<bool> _noMores = [false, false, false];
  final List<bool> _loadingMores = [false, false, false];

  @override
  void initState() {
    super.initState();
    _sortTabCtrl = TabController(length: 3, vsync: this);
    _sortTabCtrl.addListener(() {
      if (_sortTabCtrl.indexIsChanging) return;
      final posts = _postsForIndex(_sortTabCtrl.index);
      if (posts.isEmpty) _loadPosts(_sortTabCtrl.index, refresh: true);
      setState(() {});
    });
    _loadCategoryInfo();
  }

  @override
  void dispose() {
    _sortTabCtrl.dispose();
    super.dispose();
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
      case 0: return _pinnedPostsLatest;
      case 1: return _pinnedPostsHot;
      case 2: return _pinnedPostsLiked;
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
      case 0: _pinnedPostsLatest = posts; break;
      case 1: _pinnedPostsHot = posts; break;
      case 2: _pinnedPostsLiked = posts; break;
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
      final res = await ApiService().get('/categories/${widget.categoryId}/posts', queryParameters: {
        'page': _pages[sortIdx],
        'pageSize': 20,
        'sort': _sortValues[sortIdx],
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
    final name = _catInfo?['name'] ?? '分类';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notif) {
                    if (notif is ScrollUpdateNotification) {
                      final offset = notif.metrics.pixels;
                      final headerHeight = statusBarH + 220.0;
                      final opacity = (offset / headerHeight).clamp(0.0, 1.0);
                      final show = offset > 300;
                      if ((opacity - _navOpacity).abs() > 0.01 || show != _showBackTop) {
                        setState(() {
                          _navOpacity = opacity;
                          _showBackTop = show;
                        });
                      }
                      // Load more when near bottom
                      if (offset > notif.metrics.maxScrollExtent - 300) {
                        final idx = _sortTabCtrl.index;
                        if (!(_noMores[idx]) && !(_loadingMores[idx])) {
                          _loadPosts(idx);
                        }
                      }
                    }
                    return false;
                  },
                  child: NestedScrollView(
                    headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
                      SliverToBoxAdapter(child: _buildHeader(statusBarH)),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SortTabDelegate(tabController: _sortTabCtrl),
                      ),
                    ],
                    body: TabBarView(
                      controller: _sortTabCtrl,
                      children: [
                        _buildPostList(0),
                        _buildPostList(1),
                        _buildPostList(2),
                      ],
                    ),
                  ),
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
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF222222))),
                            ),
                            Expanded(child: Center(child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))))),
                            const SizedBox(width: 46),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_showBackTop)
                  Positioned(
                    right: 16, bottom: 140,
                    child: GestureDetector(
                      onTap: () {
                        PrimaryScrollController.of(context).animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
                      },
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
      floatingActionButton: _loading ? null : _buildFAB(),
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
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(3)),
            child: const Text('置顶', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(post.title, style: const TextStyle(fontSize: 15, color: Color(0xFF222222), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(fmtNum(post.commentsCount), style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
          const SizedBox(width: 4),
          const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFFCCCCCC)),
        ]),
      ),
    );
  }

  Widget _buildPostList(int sortIdx) {
    final pinned = _pinnedPostsForIndex(sortIdx);
    final posts = _postsForIndex(sortIdx);
    final hasPinned = sortIdx == 0 && pinned.isNotEmpty;
    if (posts.isEmpty && !hasPinned && !_loadingMores[sortIdx]) {
      return Center(child: Text('暂无帖子', style: const TextStyle(fontSize: 14, color: Color(0xFF999999))));
    }
    return Column(children: [
      if (hasPinned)
        Container(
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(children: pinned.map((p) => _buildPinnedItem(p)).toList()),
          ),
        ),
      Expanded(child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 5,
        crossAxisSpacing: 4,
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 80),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: posts.length + (_noMores[sortIdx] ? 0 : 1),
        itemBuilder: (ctx, i) {
          if (i == posts.length) {
            _loadPosts(sortIdx);
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CupertinoActivityIndicator(radius: 10)));
          }
          return PostCard(
            post: posts[i],
            onTap: () => Navigator.pushNamed(context, '/detail', arguments: posts[i].id),
            onLike: (_) {},
          );
        },
      )),
    ]);
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
          width: 50, height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: const Color(0xFFFF2442).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.edit, size: 22, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeader(double statusBarH) {
    final name = _catInfo?['name'] ?? '分类';
    final desc = _catInfo?['description'] ?? '';
    final cover = _catInfo?['cover'] as String? ?? '';
    final icon = _catInfo?['icon'] as String? ?? '';
    final color = _catInfo?['color'] as String? ?? '';
    final followCount = _catInfo?['follow_count'] as int? ?? 0;
    final postCount = _catInfo?['post_count'] as int? ?? 0;
    final heat = _catInfo?['heat'] as int? ?? 0;
    final authorCount = _catInfo?['author_count'] as int? ?? 0;

    return SizedBox(
      height: statusBarH + 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover.isNotEmpty)
            CachedNetworkImage(imageUrl: fullUrl(cover), fit: BoxFit.cover)
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
              ),
            ),
          Container(color: Colors.black.withValues(alpha: 0.35)),
          Positioned(
            top: statusBarH, left: 0, right: 0,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_back, size: 20, color: Colors.white))),
                  Expanded(child: Center(child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16, bottom: 60, right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: color.isNotEmpty ? _parseColor(color) : getColorForId(widget.categoryId),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: icon.isNotEmpty
                          ? Text(icon, style: const TextStyle(fontSize: 24))
                          : Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                          if (desc.isNotEmpty) Text(desc, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleFollow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isFollowed ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFFF2442),
                          borderRadius: BorderRadius.circular(16),
                          border: _isFollowed ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 0.5) : null,
                        ),
                        child: Text(_isFollowed ? '已关注' : '关注', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildInfoItem(fmtNum(followCount), '关注'),
                    const SizedBox(width: 20),
                    _buildInfoItem(fmtNum(postCount), '帖子'),
                    const SizedBox(width: 20),
                    _buildInfoItem(fmtNum(heat), '热度'),
                    const SizedBox(width: 20),
                    _buildInfoItem(fmtNum(authorCount), '作者'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return getColorForId(widget.categoryId);
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
        tabs: const [Tab(text: '最新'), Tab(text: '最热'), Tab(text: '最赞')],
      ),
    );
  }
}
