import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../utils/helpers.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<Map<String, dynamic>> _trendingPosts = [];
  List<Map<String, dynamic>> _recommendUsers = [];
  int _onlineCount = 0;
  int _totalUsers = 0;
  int _totalPosts = 0;
  bool _loading = true;
  StreamSubscription? _wsSub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenOnline();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadStats();
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _listenOnline() {
    final cs = Provider.of<ChatService>(context, listen: false);
    _wsSub = cs.onMessage.listen((msg) {
      if (msg['type'] == 'online' && mounted) {
        final count = msg['data']?['count'] as int? ?? _onlineCount;
        setState(() => _onlineCount = count);
      }
    });
  }

  Future<void> _loadData() async {
    await Future.wait([_loadTrending(), _loadRecommendUsers(), _loadStats()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadTrending() async {
    try {
      final res = await ApiService().get('/posts/trending', queryParameters: {'type': 'hot', 'limit': 10});
      if (res['code'] == 200 && mounted) {
        final data = res['data'];
        if (data is List) {
          setState(() => _trendingPosts = List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map))));
        }
      }
    } catch (_) {}
  }

  Future<void> _loadRecommendUsers() async {
    try {
      final res = await ApiService().get('/users/recommend', queryParameters: {'limit': 20});
      if (res['code'] == 200 && mounted) {
        final data = res['data'];
        if (data is List) {
          setState(() => _recommendUsers = List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map))));
        }
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final onlineRes = await ApiService().get('/stats/online');
      if (onlineRes['code'] == 200) {
        setState(() => _onlineCount = onlineRes['data']?['online_count'] as int? ?? 0);
      }
    } catch (_) {}
    try {
      final catRes = await ApiService().get('/categories');
      if (catRes['code'] == 200) {
        final cats = catRes['data'] as List? ?? [];
        int posts = 0;
        for (final c in cats) {
          posts += (c['post_count'] as int? ?? 0);
        }
        if (mounted) setState(() => _totalPosts = posts);
      }
    } catch (_) {}
    try {
      final res = await ApiService().get('/users/recommend', queryParameters: {'limit': 1});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: statusBarH),
            color: Colors.white,
            child: SizedBox(
              height: 44,
              child: const Center(
                child: Text('发现', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      CupertinoSliverRefreshControl(onRefresh: _loadData),
                      SliverList(
                        delegate: SliverChildListDelegate([
                          _buildStatsSection(),
                          _buildCategorySection(),
                          if (_recommendUsers.isNotEmpty) _buildRecommendUsers(),
                          _buildTrendingSection(),
                          const SizedBox(height: 80),
                        ]),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(_onlineCount, '在线', Icons.wifi_tethering),
          Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.3)),
          _buildStatItem(_totalPosts, '帖子', Icons.article_outlined),
          Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.3)),
          _buildStatItem(_recommendUsers.length, '活跃用户', Icons.people_outline),
        ],
      ),
    );
  }

  Widget _buildStatItem(int count, String label, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 4),
            Text(fmtNum(count), style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Consumer<PostProvider>(
      builder: (_, pp, __) {
        final cats = pp.categories;
        if (cats.isEmpty) return const SizedBox.shrink();
        final colors = [
          const Color(0xFFFF6B6B), const Color(0xFF4ECDC4), const Color(0xFFFF69B4),
          const Color(0xFFDDA0DD), const Color(0xFF87CEEB), const Color(0xFF98FB98),
          const Color(0xFFFFB347), const Color(0xFFB0C4DE),
        ];
        final emojis = ['🍜', '✈️', '👗', '💄', '📷', '⚽', '🎵', '🎬'];
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('热门分类', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
                  Text('共${cats.length}个', style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 0,
                runSpacing: 14,
                children: List.generate(cats.length, (i) {
                  final cat = cats[i];
                  final w = (MediaQuery.of(context).size.width - 52) / 4;
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/category', arguments: cat.id),
                    child: SizedBox(
                      width: w,
                      child: Column(
                        children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              color: i < colors.length ? colors[i] : getColorForId(cat.id),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: (i < colors.length ? colors[i] : getColorForId(cat.id)).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            alignment: Alignment.center,
                            child: cat.icon.isNotEmpty
                                ? Text(cat.icon, style: const TextStyle(fontSize: 22))
                                : Text(cat.name.isNotEmpty ? cat.name[0] : '?', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 6),
                          Text(cat.name, style: const TextStyle(fontSize: 12, color: Color(0xFF333333)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendUsers() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('推荐关注', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/recommend-users'),
                child: Row(children: [
                  const Text('更多', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF999999)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendUsers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildUserCard(_recommendUsers[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final avatarUrl = user['avatar'] as String? ?? '';
    final nickname = user['nickname'] as String? ?? '';
    final fansCount = user['fans_count'] as int? ?? 0;
    final userId = user['id'] as int? ?? 0;
    final isFollowed = user['is_followed'] == true;
    final isFan = user['is_fan'] == true;
    final isMutual = isFollowed && isFan;
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/user-profile', arguments: userId),
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: getColorForId(userId), shape: BoxShape.circle),
              child: avatarUrl.isNotEmpty
                  ? ClipOval(child: CachedNetworkImage(imageUrl: fullUrl(avatarUrl), width: 50, height: 50, fit: BoxFit.cover, errorWidget: (_, __, ___) => Center(child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600)))))
                  : Center(child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600))),
            ),
          ),
          const SizedBox(height: 4),
          Text(nickname, style: const TextStyle(fontSize: 11, color: Color(0xFF333333)), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (isMutual)
            const Text('互关', style: TextStyle(fontSize: 9, color: Color(0xFF1890FF), fontWeight: FontWeight.w600))
          else
            Text('${fmtNum(fansCount)}粉丝', style: const TextStyle(fontSize: 10, color: Color(0xFFBBBBBB))),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () async {
              await Provider.of<UserProvider>(context, listen: false).followUser(userId);
              setState(() {
                user['is_followed'] = !(user['is_followed'] == true);
                if (!user['is_followed']) user['is_fan'] = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isMutual ? const Color(0xFFE6F7FF) : (isFollowed ? const Color(0xFFF5F5F5) : const Color(0xFFFF2442)),
                borderRadius: BorderRadius.circular(12),
                border: isMutual ? Border.all(color: const Color(0xFF1890FF), width: 0.5) : (isFollowed ? Border.all(color: const Color(0xFFE8E8E8), width: 0.5) : null),
              ),
              child: Text(isMutual ? '互关' : (isFollowed ? '已关注' : '关注'), style: TextStyle(fontSize: 11, color: isMutual ? const Color(0xFF1890FF) : (isFollowed ? const Color(0xFF999999) : Colors.white), fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingSection() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(1.5))),
                const SizedBox(width: 8),
                const Text('热门榜单', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
              ]),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/trending'),
                child: Row(children: [
                  const Text('更多', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF999999)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_trendingPosts.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('暂无热门内容', style: TextStyle(fontSize: 14, color: Color(0xFF999999)))))
          else
            ..._trendingPosts.asMap().entries.map((e) => _buildTrendItem(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildTrendItem(int index, Map<String, dynamic> post) {
    final rankColors = [
      const Color(0xFFFF2442),
      const Color(0xFFFF6B2E),
      const Color(0xFFFAAD14),
    ];
    final isTop3 = index < 3;

    final rawImages = post['images'];
    List<Map<String, dynamic>> images = [];
    if (rawImages is List) {
      images = rawImages.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final cover = images.isNotEmpty ? (images[0]['url'] as String? ?? '') : '';
    final hasImage = cover.isNotEmpty;

    final postType = post['post_type'] as int? ?? 3;
    final voiceUrl = post['voice_url'] as String? ?? '';
    final voiceDuration = post['voice_duration'] as int?;
    final hasAudio = postType == 2 && voiceUrl.isNotEmpty && !hasImage;

    final title = post['title'] ?? '';
    final firstLetter = title.isNotEmpty ? title[0] : '?';
    final avatar = post['avatar'] as String? ?? '';
    final nickname = post['nickname'] as String? ?? '';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/detail', arguments: post['id']),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 0.5))),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: isTop3 ? rankColors[index] : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isTop3 ? Colors.white : const Color(0xFF999999))),
            ),
            const SizedBox(width: 10),
            if (hasImage)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: fullUrl(cover),
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _buildFallbackCover(firstLetter, post),
                  ),
                ),
              )
            else if (hasAudio)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: getColorForId(post['id'] ?? 0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.audiotrack, size: 20, color: Colors.white),
                      Positioned(
                        bottom: 2, right: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3)),
                          child: Text(_fmtAudioDuration(voiceDuration ?? 0), style: const TextStyle(fontSize: 8, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildFallbackCover(firstLetter, post),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF222222)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (avatar.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: fullUrl(avatar),
                              width: 14, height: 14, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 14, height: 14,
                                decoration: BoxDecoration(color: getColorForId(post['user_id'] ?? post['id'] ?? 0), shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(color: getColorForId(post['user_id'] ?? post['id'] ?? 0), shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      Text(nickname, style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                      const SizedBox(width: 6),
                      Text('${fmtNum(post['likes_count'] as int? ?? 0)}赞', style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCover(String firstLetter, Map<String, dynamic> post) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: getColorForId(post['id'] ?? 0),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(firstLetter, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }

  String _fmtAudioDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
