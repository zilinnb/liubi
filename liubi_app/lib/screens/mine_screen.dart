import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../providers/user_provider.dart';
import '../providers/post_provider.dart';
import '../models/post.dart';
import '../utils/helpers.dart';
import '../widgets/post_card.dart';
import '../widgets/app_toast.dart';
import '../widgets/image_preview.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_skeleton.dart';

class MineScreen extends StatefulWidget {
  const MineScreen({super.key});
  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen> with TickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Post> _userPosts = [];
  List<Post> _userCollects = [];
  List<Post> _userLikes = [];
  bool _postsLoading = true;
  bool _collectsLoading = true;
  bool _likesLoading = true;
  List<Map<String, dynamic>> _activities = [];
  bool _activitiesLoading = true;
  double _navOpacity = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }


  Future<void> _loadData() async {
    final up = Provider.of<UserProvider>(context, listen: false);
    final userId = up.userInfo?.id;
    if (userId == null) return;
    final pp = Provider.of<PostProvider>(context, listen: false);
    final results = await Future.wait([
      pp.fetchUserPosts(userId),
      pp.fetchUserCollects(userId),
      pp.fetchUserLikes(userId),
    ]);
    if (mounted) {
      setState(() {
        _userPosts = (results[0] as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
        _userCollects = (results[1] as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
        _userLikes = (results[2] as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
        _postsLoading = false;
        _collectsLoading = false;
        _likesLoading = false;
      });
    }
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final up = Provider.of<UserProvider>(context, listen: false);
    final userId = up.userInfo?.id;
    if (userId == null) return;
    try {
      final res = await ApiService().get('/users/$userId/activities', queryParameters: {'pageSize': 30});
      if (res['code'] == 200 && mounted) {
        setState(() {
          _activities = (res['data'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
          _activitiesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _activitiesLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Consumer<UserProvider>(
      builder: (_, up, __) {
        if (!up.isLoggedIn) return _buildNotLoggedIn();
        final user = up.userInfo;
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notif) {
                  if (notif is ScrollUpdateNotification) {
                    final offset = notif.metrics.pixels;
                    final opacity = (offset / 180).clamp(0.0, 1.0);
                    if ((opacity - _navOpacity).abs() > 0.01 && mounted) {
                      setState(() => _navOpacity = opacity);
                    }
                  }
                  return false;
                },
                child: NestedScrollView(
                  headerSliverBuilder: (ctx, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(child: _buildHeader(statusBarH, user)),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _TabBarDelegate(tabCtrl: _tabCtrl),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildPostGrid(_userPosts, _postsLoading),
                      _buildPostGrid(_userCollects, _collectsLoading),
                      _buildPostGrid(_userLikes, _likesLoading),
                      _buildActivityTab(),
                    ],
                  ),
                ),
              ),
              _buildNavBar(statusBarH, user),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotLoggedIn() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/icons/app_icon.png', width: 72, height: 72, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            const Text('留笔', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
            const SizedBox(height: 8),
            const Text('登录后查看个人主页', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/login'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]), borderRadius: BorderRadius.circular(22)),
                child: const Text('登录', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(double statusBarH, dynamic user) {
    final nickname = user?.nickname ?? '';
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(top: statusBarH),
        decoration: BoxDecoration(
          color: _navOpacity > 0.5 ? Colors.white : Colors.white.withValues(alpha: _navOpacity * 2),
          border: _navOpacity > 0.5 ? const Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)) : null,
        ),
        child: SizedBox(
          height: 44,
          child: Stack(
            children: [
              if (_navOpacity < 0.5) ...[
                Positioned(
                  left: 12, top: 0, bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/settings'),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.settings, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12, top: 0, bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _showBgOptions,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
              if (_navOpacity >= 0.5) ...[
                Positioned(
                  left: 12, top: 0, bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/settings'),
                      child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.settings, size: 22, color: Color(0xFF555555))),
                    ),
                  ),
                ),
                Positioned(
                  right: 12, top: 0, bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _showBgOptions,
                      child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.camera_alt_outlined, size: 20, color: Color(0xFF555555))),
                    ),
                  ),
                ),
              ],
              Center(
                child: Opacity(
                  opacity: (_navOpacity - 0.3).clamp(0.0, 1.0) / 0.7,
                  child: Text(nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double statusBarH, dynamic user) {
    final bgImage = user?.bgImage;
    final hasBg = bgImage != null && bgImage.isNotEmpty;
    final avatar = user?.avatar ?? '';
    final avatarUrl = fullUrl(avatar);
    final nickname = user?.nickname ?? '';
    final bio = user?.bio ?? '';
    final username = user?.username ?? '';
    final location = user?.location ?? '';
    final gender = user?.gender ?? 0;
    final followCount = user?.followCount ?? 0;
    final fansCount = user?.fansCount ?? 0;
    final likeCount = user?.likeCount ?? 0;
    final userId = user?.id ?? 0;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            _previewImage(hasBg ? fullUrl(bgImage) : '');
          },
          child: SizedBox(
            height: statusBarH + 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasBg)
                  Hero(tag: 'bg_mine', child: CachedNetworkImage(imageUrl: fullUrl(bgImage), fit: BoxFit.cover))
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
                Container(color: Colors.black.withValues(alpha: 0.08)),
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -40),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _previewImage(avatarUrl.isNotEmpty ? avatarUrl : ''),
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3.5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 3))],
                  ),
                  child: ClipOval(
                    child: avatarUrl.isNotEmpty
                        ? CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => _buildAvatarFallback(nickname, userId))
                        : _buildAvatarFallback(nickname, userId),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(nickname, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF222222)), overflow: TextOverflow.ellipsis),
                        ),
                        if (gender == 1) ...[
                          const SizedBox(width: 6),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFE6F7FF), borderRadius: BorderRadius.circular(3)), child: const Text('♂', style: TextStyle(fontSize: 11, color: Color(0xFF1890FF)))),
                        ] else if (gender == 2) ...[
                          const SizedBox(width: 6),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFFFF0F6), borderRadius: BorderRadius.circular(3)), child: const Text('♀', style: TextStyle(fontSize: 11, color: Color(0xFFFF2442)))),
                        ],
                      ],
                    ),
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: username));
                          AppToast.success(context, message: '留笔号已复制');
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('留笔号: $username', style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 12, color: Color(0xFFBBBBBB)),
                          ],
                        ),
                      ),
                    ],
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('IP属地: $location', style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      bio.isNotEmpty ? bio : '这个人很懒，什么都没写~',
                      style: TextStyle(fontSize: 13, color: bio.isNotEmpty ? const Color(0xFF666666) : const Color(0xFFBBBBBB)),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    _buildStatsRow(followCount, fansCount, likeCount),
                    const SizedBox(height: 10),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarFallback(String nickname, int userId) {
    return Container(
      color: getColorForId(userId),
      child: Center(child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w600))),
    );
  }

  void _previewImage(String url) {
    if (url.isEmpty) return;
    ImagePreview.open(context, url: url);
  }

  Widget _buildStatsRow(int followCount, int fansCount, int likeCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem(fmtNum(followCount), '关注', onTap: () => _showFollowList()),
        SizedBox(width: MediaQuery.of(context).size.width * 0.12),
        _buildStatItem(fmtNum(fansCount), '粉丝', onTap: () => _showFansList()),
        SizedBox(width: MediaQuery.of(context).size.width * 0.12),
        _buildStatItem(fmtNum(likeCount), '获赞与收藏', onTap: () => _showLikersList()),
      ],
    );
  }

  Widget _buildStatItem(String count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(count, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/edit-profile'),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: const Text('编辑资料', style: TextStyle(fontSize: 14, color: Color(0xFF333333), fontWeight: FontWeight.w500)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/settings'),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: const Text('设置', style: TextStyle(fontSize: 14, color: Color(0xFF333333), fontWeight: FontWeight.w500)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostGrid(List<Post> posts, bool loading) {
    if (loading) return const MasonrySkeletonGrid();
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_outlined, size: 48, color: const Color(0xFFDDDDDD)),
            const SizedBox(height: 12),
            const Text('暂无内容', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
          ],
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 6,
            childCount: posts.length,
            itemBuilder: (ctx, idx) {
              return RepaintBoundary(
                child: PostCard(
                  post: posts[idx],
                  onTap: () => Navigator.pushNamed(context, '/detail', arguments: posts[idx].id),
                  onLike: (_) => Provider.of<PostProvider>(context, listen: false).toggleLike(posts[idx].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab() {
    if (_activitiesLoading) return const Center(child: CupertinoActivityIndicator(radius: 14));
    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.explore_outlined, size: 48, color: Color(0xFFDDDDDD)),
            const SizedBox(height: 12),
            const Text('暂无动态', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
          ],
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _buildActivityItem(_activities[i]),
            childCount: _activities.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> a) {
    final post = a['post'] as Map<String, dynamic>?;
    final postTitle = a['target_title'] as String? ?? '';
    final postCover = post?['cover'] as String? ?? '';
    final voiceUrl = post?['voice_url'] as String? ?? '';
    final voiceDuration = post?['voice_duration'] as int?;
    final postType = post?['post_type'] as int? ?? 0;
    final createdAt = a['created_at'] as String? ?? '';
    final targetId = a['target_id'] as int?;
    final targetType = a['target_type'] as int? ?? 1;
    final type = a['type'] as int? ?? 0;
    String actionText;
    switch (type) {
      case 1: actionText = '发布了笔记'; break;
      case 2: actionText = '赞了笔记'; break;
      case 3: actionText = '评论了'; break;
      case 4: actionText = '收藏了笔记'; break;
      case 5: actionText = '关注了'; break;
      default: actionText = '';
    }

    final isPostActivity = type != 5 && targetType == 1;

    return GestureDetector(
      onTap: () {
        if (targetType == 1 && targetId != null) {
          Navigator.pushNamed(context, '/detail', arguments: targetId);
        } else if (targetType == 2 && targetId != null) {
          Navigator.pushNamed(context, '/user-profile', arguments: targetId);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 0.5))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPostActivity)
              _buildActivityCover(postCover: postCover, voiceUrl: voiceUrl, voiceDuration: voiceDuration, postType: postType, postId: targetId, postTitle: postTitle)
            else if (type == 5)
              const Icon(Icons.person_add, size: 28, color: Color(0xFFFF2442))
            else
              _buildActivityCover(postCover: '', voiceUrl: '', voiceDuration: null, postType: 0, postId: targetId, postTitle: postTitle),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(actionText, style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
                  if (postTitle.isNotEmpty && type != 5) ...[
                    const SizedBox(height: 4),
                    Text(postTitle, style: const TextStyle(fontSize: 13, color: Color(0xFF999999)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text(fmtTime(createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCover({required String postCover, required String voiceUrl, int? voiceDuration, required int postType, int? postId, String? postTitle}) {
    const double size = 56;
    if (postCover.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size, height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(imageUrl: fullUrl(postCover), fit: BoxFit.cover, errorWidget: (_, __, ___) => _buildCoverPlaceholder(size, postId: postId, postTitle: postTitle)),
              if (voiceUrl.isNotEmpty)
                Positioned(
                  right: 4, bottom: 4,
                  child: Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle), child: const Icon(Icons.volume_up, size: 12, color: Colors.white)),
                ),
            ],
          ),
        ),
      );
    }
    if (voiceUrl.isNotEmpty) {
      final bgColor = getColorForId(postId ?? 0);
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.audiotrack, size: 22, color: Colors.white),
            if (voiceDuration != null)
              Positioned(
                bottom: 3, right: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3)),
                  child: Text(fmtVoiceTime(voiceDuration), style: const TextStyle(fontSize: 8, color: Colors.white)),
                ),
              ),
          ],
        ),
      );
    }
    return _buildCoverPlaceholder(size, postId: postId, postTitle: postTitle);
  }

  Widget _buildCoverPlaceholder(double size, {int? postId, String? postTitle}) {
    final bgColor = getColorForId(postId ?? 0);
    final title = postTitle ?? '';
    final firstChar = title.isNotEmpty ? title[0] : '';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: firstChar.isNotEmpty
          ? Text(firstChar, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700))
          : const Icon(Icons.article_outlined, size: 22, color: Colors.white70),
    );
  }

  void _showBgOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            ListTile(leading: const Icon(Icons.photo_camera, color: Color(0xFF666666)), title: const Text('更换背景', style: TextStyle(fontSize: 15, color: Color(0xFF222222))), onTap: () { Navigator.pop(context); Provider.of<UserProvider>(context, listen: false).updateBgImage(); }),
            ListTile(leading: const Icon(Icons.delete_outline, color: Color(0xFF666666)), title: const Text('恢复默认', style: TextStyle(fontSize: 15, color: Color(0xFF222222))), onTap: () { Navigator.pop(context); Provider.of<UserProvider>(context, listen: false).removeBgImage(); }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showFollowList() {
    Navigator.pushNamed(context, '/follow-list', arguments: {'type': 'follows', 'userId': Provider.of<UserProvider>(context, listen: false).userInfo?.id});
  }

  void _showFansList() {
    Navigator.pushNamed(context, '/follow-list', arguments: {'type': 'fans', 'userId': Provider.of<UserProvider>(context, listen: false).userInfo?.id});
  }

  void _showLikersList() {
    Navigator.pushNamed(context, '/follow-list', arguments: {'type': 'likers', 'userId': Provider.of<UserProvider>(context, listen: false).userInfo?.id});
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabCtrl;

  _TabBarDelegate({required this.tabCtrl});

  @override
  double get minExtent => 46;

  @override
  double get maxExtent => 46;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
      ),
      child: TabBar(
        controller: tabCtrl,
        labelColor: const Color(0xFF222222),
        unselectedLabelColor: const Color(0xFF999999),
        indicatorColor: const Color(0xFFFF2442),
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        tabs: const [
          Tab(text: '笔记'),
          Tab(text: '收藏'),
          Tab(text: '赞过'),
          Tab(text: '动态'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => tabCtrl != oldDelegate.tabCtrl;
}
