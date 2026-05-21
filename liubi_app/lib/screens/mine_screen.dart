import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../providers/user_provider.dart';
import '../providers/post_provider.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../utils/helpers.dart';
import '../widgets/post_card.dart';
import '../widgets/app_toast.dart';
import 'image_viewer_screen.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_skeleton.dart';
import 'coin_center_screen.dart';

class MineScreen extends StatefulWidget {
  const MineScreen({super.key});
  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Post> _userPosts = [];
  List<Post> _userCollects = [];
  List<Post> _userLikes = [];
  bool _postsLoading = true;
  bool _collectsLoading = true;
  bool _likesLoading = true;
  List<Map<String, dynamic>> _activities = [];
  bool _activitiesLoading = true;
  final ValueNotifier<double> _collapse = ValueNotifier(0);
  bool _bioExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadData();
    _loadActivities();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _collapse.dispose();
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
        _userPosts = (results[0] as List)
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();
        _userCollects = (results[1] as List)
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();
        _userLikes = (results[2] as List)
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();
        _postsLoading = false;
        _collectsLoading = false;
        _likesLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async => _loadData();

  Future<void> _loadActivities() async {
    final up = Provider.of<UserProvider>(context, listen: false);
    final userId = up.userInfo?.id;
    if (userId == null) return;
    try {
      final res = await ApiService().get(
        '/users/$userId/activities',
        queryParameters: {'pageSize': 30},
      );
      if (res['code'] == 200 && mounted) {
        setState(() {
          _activities = (res['data'] as List? ?? [])
              .map((e) => e as Map<String, dynamic>)
              .toList();
          _activitiesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _activitiesLoading = false);
    }
  }

  void _showLikeCollectDetail() {
    final up = Provider.of<UserProvider>(context, listen: false);
    final likeCount = up.userInfo?.likeCount ?? 0;
    final collectCount = up.userInfo?.collectCount ?? 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPopupStat(fmtNum(likeCount), '赞'),
                  _buildPopupStat(fmtNum(collectCount), '收藏'),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupStat(String count, String label) {
    return Column(
      children: [
        Text(count,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF222222))),
        const SizedBox(height: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: Color(0xFF999999))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Consumer<UserProvider>(
      builder: (_, up, __) {
        if (!up.isLoggedIn) return _buildNotLoggedIn();
        return ValueListenableBuilder<double>(
          valueListenable: _collapse,
          builder: (_, cp, __) {
            final style = cp < 0.5 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: style,
              child: Scaffold(
                backgroundColor: Colors.white,
                body: NestedScrollView(
                  headerSliverBuilder: (ctx, _) => [
                    SliverAppBar(
                      expandedHeight: statusBarH + 215,
                      pinned: true,
                      floating: false,
                      snap: false,
                      toolbarHeight: 44,
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      scrolledUnderElevation: 0,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      titleSpacing: 0,
                      leading: _buildNavLeading(),
                      title: _buildNavTitle(up.userInfo?.nickname ?? ''),
                      flexibleSpace: _buildFlexibleSpace(statusBarH, up),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _MineTabCardDelegate(tabCtrl: _tabCtrl),
                    ),
                  ],
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
            );
          },
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
              child: Image.asset('assets/icons/app_icon.png',
                  width: 72, height: 72, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            const Text('留笔',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222))),
            const SizedBox(height: 8),
            const Text('登录后查看个人主页',
                style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/login'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text('登录',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavLeading() {
    return ValueListenableBuilder<double>(
      valueListenable: _collapse,
      builder: (_, cp, __) {
        final iconColor = Color.lerp(Colors.white, const Color(0xFF333333), cp);
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/settings'),
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25 * (1 - cp)),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.settings, size: 14, color: iconColor),
            ),
          ),
        );
      },
    );
  }

  Widget _navAvatarFallback(String n) {
    return Container(
      color: const Color(0xFFFF2442),
      child: Center(
        child: Text(n.isNotEmpty ? n[0] : '?',
            style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildNavTitle(String nickname) {
    return ValueListenableBuilder<double>(
      valueListenable: _collapse,
      builder: (_, cp, __) {
        final showTitle = cp > 0.7;
        if (!showTitle) return const SizedBox.shrink();
        final textColor = Color.lerp(Colors.white, const Color(0xFF222222), cp);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer<UserProvider>(builder: (_, up, __) {
              final avatarUrl = fullUrl(up.userInfo?.avatar ?? '');
              return Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
                ),
                child: ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _navAvatarFallback(up.userInfo?.nickname ?? '?'),
                        )
                      : _navAvatarFallback(up.userInfo?.nickname ?? '?'),
                ),
              );
            }),
            const SizedBox(width: 4),
            Text(
              nickname,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFlexibleSpace(double statusBarH, UserProvider up) {
    final user = up.userInfo;
    final bgImage = user?.bgImage ?? '';
    final hasBg = bgImage.isNotEmpty;
    final avatar = user?.avatar ?? '';
    final avatarUrl = fullUrl(avatar);
    final nickname = user?.nickname ?? '';
    final bio = user?.bio ?? '';
    final username = user?.username ?? '';
    final gender = user?.gender ?? 0;
    final followCount = user?.followCount ?? 0;
    final fansCount = user?.fansCount ?? 0;
    final likeCount = user?.likeCount ?? 0;
    final location = user?.location ?? '';
    final userId = user?.id ?? 0;
    final coins = user?.coins ?? 0;
    final levelInfo = user?.levelInfo;

    return LayoutBuilder(builder: (ctx, constraints) {
      final curH = constraints.biggest.height;
      final totalExpand = statusBarH + 215.0;
      final cp =
          (1 - ((curH - 44) / (totalExpand - 44)).clamp(0.0, 1.0))
              .clamp(0.0, 1.0);
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
            child: GestureDetector(
              onTap: () {
                if (hasBg) {
                  ImageViewerScreen.openSingle(context, url: fullUrl(bgImage));
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasBg)
                    Hero(
                      tag: 'bg_mine',
                      child: CachedNetworkImage(
                          imageUrl: fullUrl(bgImage), fit: BoxFit.cover),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF2442),
                            Color(0xFFFF5A6E),
                            Color(0xFFFF8A9E),
                          ],
                        ),
                      ),
                    ),
                  Container(color: Colors.black.withValues(alpha: 0.06)),
                ],
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (avatarUrl.isNotEmpty) {
                            ImageViewerScreen.openSingle(context, url: avatarUrl);
                          }
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: avatarUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _avatarFallback(nickname, userId),
                                  )
                                : _avatarFallback(nickname, userId),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    nickname,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                            color: Colors.black26,
                                            blurRadius: 4),
                                      ],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (gender == 1) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6F7FF),
                                      borderRadius:
                                          BorderRadius.circular(3),
                                    ),
                                    child: const Text('♂',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF1890FF))),
                                  ),
                                ],
                                if (gender == 2) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF0F6),
                                      borderRadius:
                                          BorderRadius.circular(3),
                                    ),
                                    child: const Text('♀',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFFFF2442))),
                                  ),
                                ],
                                if (levelInfo != null) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _getLevelColor(levelInfo.level).withValues(alpha: 0.2),
                                      borderRadius:
                                          BorderRadius.circular(3),
                                      border: Border.all(
                                          color: _getLevelColor(levelInfo.level).withValues(alpha: 0.4),
                                          width: 0.5),
                                    ),
                                    child: Text(
                                      'Lv.${levelInfo.level}',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: _getLevelColor(levelInfo.level),
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: username));
                                AppToast.success(context,
                                    message: '留笔号已复制');
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('留笔号: $username',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy_rounded,
                                      size: 11, color: Colors.white70),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildExpandableBio(bio),
                  ] else ...[
                    const SizedBox(height: 12),
                    const Text('这个用户很懒，没有设置签名...', style: TextStyle(fontSize: 13, color: Colors.white60)),
                  ],
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('IP属地: $location', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, '/follow-list',
                                  arguments: {
                                    'type': 'follows',
                                    'userId': userId,
                                  }),
                              child: _bgStatItem(fmtNum(followCount), '关注'),
                            ),
                            const SizedBox(width: 24),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, '/follow-list',
                                  arguments: {
                                    'type': 'fans',
                                    'userId': userId,
                                  }),
                              child: _bgStatItem(fmtNum(fansCount), '粉丝'),
                            ),
                            const SizedBox(width: 24),
                            GestureDetector(
                              onTap: _showLikeCollectDetail,
                              child: _bgStatItem(
                                  fmtNum(likeCount), '获赞与收藏'),
                            ),
                            const SizedBox(width: 24),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CoinCenterScreen())).then((_) {
                                  Provider.of<UserProvider>(context, listen: false).fetchProfile();
                                });
                              },
                              child: _bgStatItem(fmtNum(coins), '留币'),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/edit-profile'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 0.5),
                          ),
                          child: const Text('编辑资料', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/settings'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 0.5),
                          ),
                          child: const Text('设置', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                  _buildExpProgressBar(levelInfo),
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

  Widget _avatarFallback(String n, int id) {
    return Container(
      color: getColorForId(id),
      child: Center(
        child: Text(n.isNotEmpty ? n[0] : '?',
            style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildFollowAvatar(String avatar, String nickname, int? userId) {
    final avatarUrl = fullUrl(avatar);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF0F0F0), width: 0.5),
      ),
      child: ClipOval(
        child: avatarUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: getColorForId(userId ?? 0),
                  child: Center(
                    child: Text(nickname.isNotEmpty ? nickname[0] : '?',
                        style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              )
            : Container(
                color: getColorForId(userId ?? 0),
                child: Center(
                  child: Text(nickname.isNotEmpty ? nickname[0] : '?',
                      style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
      ),
    );
  }

  Widget _bgStatItem(String count, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(count,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
            )),
        const SizedBox(height: 1),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Color _getLevelColor(int level) {
    if (level <= 3) return const Color(0xFF999999);
    if (level <= 6) return const Color(0xFF1890FF);
    if (level <= 9) return const Color(0xFF722ED1);
    return const Color(0xFFFAAD14);
  }

  Widget _buildExpProgressBar(LevelInfo? levelInfo) {
    if (levelInfo == null) return const SizedBox.shrink();
    final levelColor = _getLevelColor(levelInfo.level);
    final isMaxLevel = levelInfo.nextLevelExp <= 0 || levelInfo.progress >= 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              isMaxLevel ? '已满级' : 'Lv.${levelInfo.level} → Lv.${levelInfo.level + 1}  ${levelInfo.currentExp}/${levelInfo.nextLevelExp - levelInfo.exp + levelInfo.currentExp}',
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
            const Spacer(),
            Text(
              isMaxLevel ? '' : '还需${(levelInfo.nextLevelExp - levelInfo.exp)}经验',
              style: const TextStyle(fontSize: 9, color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: isMaxLevel ? 1.0 : levelInfo.progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(levelColor),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableBio(String bio) {
    return LayoutBuilder(builder: (_, constraints) {
      final tp = TextPainter(
        text: TextSpan(
          text: bio,
          style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4),
        ),
        maxLines: _bioExpanded ? null : 2,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: constraints.maxWidth);
      final overflow = tp.didExceedMaxLines;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bio,
            style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.4),
            maxLines: _bioExpanded ? null : 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (overflow)
            GestureDetector(
              onTap: () => setState(() => _bioExpanded = !_bioExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_bioExpanded ? '收起' : '更多',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFFFD4DB))),
                    Icon(
                      _bioExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 14,
                      color: const Color(0xFFFFD4DB),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildPostGrid(List<Post> posts, bool loading) {
    if (loading) {
      return CustomScrollView(
        slivers: [SliverFillRemaining(child: const MasonrySkeletonGrid())],
      );
    }
    if (posts.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.note_outlined,
                      size: 48, color: Color(0xFFDDDDDD)),
                  SizedBox(height: 12),
                  Text('暂无内容',
                      style:
                          TextStyle(fontSize: 14, color: Color(0xFF999999))),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: const Color(0xFFFF2442),
      onRefresh: _onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childCount: posts.length,
              itemBuilder: (ctx, idx) => RepaintBoundary(
                child: PostCard(
                  post: posts[idx],
                  onTap: () => Navigator.pushNamed(
                      context, '/detail',
                      arguments: posts[idx].id),
                  onLike: (_) => Provider.of<PostProvider>(context,
                          listen: false)
                      .toggleLike(posts[idx].id),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    if (_activitiesLoading) {
      return const Center(
          child: CupertinoActivityIndicator(
              radius: 14, color: Color(0xFFFF2442)));
    }
    if (_activities.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.explore_outlined,
                      size: 48, color: Color(0xFFDDDDDD)),
                  SizedBox(height: 12),
                  Text('暂无动态',
                      style:
                          TextStyle(fontSize: 14, color: Color(0xFF999999))),
                ],
              ),
            ),
          ),
        ],
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
    final postContent = post?['content'] as String? ?? '';
    final voiceUrl = post?['voice_url'] as String? ?? '';
    final voiceDuration = post?['voice_duration'] as int?;
    final createdAt = a['created_at'] as String? ?? '';
    final targetId = a['target_id'] as int?;
    final targetType = a['target_type'] as int? ?? 1;
    final type = a['type'] as int? ?? 0;
    String actionText;
    switch (type) {
      case 1:
        actionText = '发布了笔记';
        break;
      case 2:
        actionText = '赞了笔记';
        break;
      case 3:
        actionText = '评论了';
        break;
      case 4:
        actionText = '收藏了笔记';
        break;
      case 5:
        actionText = '关注了';
        break;
      default:
        actionText = '';
    }
    final isPostActivity = type != 5 && targetType == 1;
    final targetUser = a['target_user'] as Map<String, dynamic>?;
    final targetAvatar = targetUser?['avatar'] as String? ?? '';
    final targetNickname = targetUser?['nickname'] as String? ?? postTitle;
    return GestureDetector(
      onTap: () {
        if (targetType == 1 && targetId != null) {
          Navigator.pushNamed(context, '/detail', arguments: targetId);
        } else if (targetType == 2 && targetId != null) {
          Navigator.pushNamed(context, '/user-profile',
              arguments: targetId);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFFF5F5F5), width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPostActivity)
              _buildActivityCover(
                postCover: postCover,
                voiceUrl: voiceUrl,
                voiceDuration: voiceDuration,
                postId: targetId,
                postTitle: postTitle,
                postContent: postContent,
              )
            else if (type != 5)
              _buildActivityCover(
                postCover: '',
                voiceUrl: '',
                voiceDuration: null,
                postId: targetId,
                postTitle: postTitle,
                postContent: postContent,
              ),
            if (type != 5) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (type == 5)
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
                        children: [
                          const TextSpan(text: '关注了 '),
                          TextSpan(
                            text: targetNickname,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Text(actionText,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF333333))),
                    if (postTitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(postTitle,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF999999)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                  const SizedBox(height: 4),
                  Text(fmtTime(createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFBBBBBB))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCover({
    required String postCover,
    required String voiceUrl,
    int? voiceDuration,
    int? postId,
    String? postTitle,
    String? postContent,
  }) {
    const double size = 56;
    if (postCover.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: fullUrl(postCover),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    _buildCoverPlaceholder(size,
                        postId: postId, postTitle: postTitle, postContent: postContent),
              ),
              if (voiceUrl.isNotEmpty)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.volume_up,
                        size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (voiceUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: getColorForId(postId ?? 0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.audiotrack, size: 22, color: Colors.white),
            if (voiceDuration != null)
              Positioned(
                bottom: 3,
                right: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(fmtVoiceTime(voiceDuration),
                      style: const TextStyle(
                          fontSize: 8, color: Colors.white)),
                ),
              ),
          ],
        ),
      );
    }
    return _buildCoverPlaceholder(size,
        postId: postId, postTitle: postTitle, postContent: postContent);
  }

  Widget _buildCoverPlaceholder(double size,
      {int? postId, String? postTitle, String? postContent}) {
    final title = postTitle ?? '';
    final content = postContent ?? '';
    final displayText = content.isNotEmpty ? content : title;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        displayText.length > 20 ? '${displayText.substring(0, 20)}...' : displayText,
        style: const TextStyle(fontSize: 10, color: Color(0xFF666666), height: 1.3),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _MineTabCardDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabCtrl;
  _MineTabCardDelegate({required this.tabCtrl});

  @override
  double get minExtent => 46;
  @override
  double get maxExtent => 46;

  @override
  Widget build(BuildContext context, _, __) {
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
        labelStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w400),
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
  bool shouldRebuild(covariant _MineTabCardDelegate o) =>
      tabCtrl != o.tabCtrl;
}
