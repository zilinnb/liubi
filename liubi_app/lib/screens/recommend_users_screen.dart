import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';

class RecommendUsersScreen extends StatefulWidget {
  const RecommendUsersScreen({super.key});

  @override
  State<RecommendUsersScreen> createState() => _RecommendUsersScreenState();
}

class _RecommendUsersScreenState extends State<RecommendUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final res = await ApiService().get('/users/recommend', queryParameters: {'limit': 100});
      if (res['code'] == 200 && mounted) {
        final data = res['data'];
        if (data is List) {
          setState(() {
            _users = List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map)));
            _loading = false;
          });
        }
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
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: statusBarH),
            color: Colors.white,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF222222)))),
                  const Expanded(child: Center(child: Text('推荐关注', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      CupertinoSliverRefreshControl(onRefresh: _loadUsers),
                      SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildUserItem(_users[i]),
                            ),
                            childCount: _users.length,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    final avatarUrl = user['avatar'] as String? ?? '';
    final nickname = user['nickname'] as String? ?? '';
    final bio = user['bio'] as String? ?? '';
    final fansCount = user['fans_count'] as int? ?? 0;
    final userId = user['id'] as int? ?? 0;
    final isFollowed = user['is_followed'] == true;
    final isFan = user['is_fan'] == true;
    final isMutual = isFollowed && isFan;
    final postCount = user['post_count'] as int? ?? 0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/user-profile', arguments: userId),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: getColorForId(userId), shape: BoxShape.circle),
              child: avatarUrl.isNotEmpty
                  ? ClipOval(child: CachedNetworkImage(imageUrl: fullUrl(avatarUrl), width: 48, height: 48, fit: BoxFit.cover, errorWidget: (_, __, ___) => Center(child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600)))))
                  : Center(child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                      if (isMutual) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: const Color(0xFFE6F7FF), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF1890FF), width: 0.5)),
                          child: const Text('互关', style: TextStyle(fontSize: 10, color: Color(0xFF1890FF), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(bio.isNotEmpty ? bio : '${fmtNum(fansCount)}粉丝 · ${fmtNum(postCount)}帖子', style: const TextStyle(fontSize: 12, color: Color(0xFF999999)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                await Provider.of<UserProvider>(context, listen: false).followUser(userId);
                setState(() {
                  user['is_followed'] = !(user['is_followed'] == true);
                  if (!user['is_followed']) user['is_fan'] = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isMutual ? const Color(0xFFE6F7FF) : (isFollowed ? const Color(0xFFF5F5F5) : const Color(0xFFFF2442)),
                  borderRadius: BorderRadius.circular(14),
                  border: isMutual ? Border.all(color: const Color(0xFF1890FF), width: 0.5) : (isFollowed ? Border.all(color: const Color(0xFFE8E8E8), width: 0.5) : null),
                ),
                child: Text(isMutual ? '互关' : (isFollowed ? '已关注' : '关注'), style: TextStyle(fontSize: 12, color: isMutual ? const Color(0xFF1890FF) : (isFollowed ? const Color(0xFF999999) : Colors.white), fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
