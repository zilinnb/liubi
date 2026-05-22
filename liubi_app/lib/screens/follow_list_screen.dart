import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';

class FollowListScreen extends StatefulWidget {
  final String type;
  final int userId;
  const FollowListScreen({super.key, required this.type, required this.userId});
  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _title {
    switch (widget.type) {
      case 'follows': return '关注';
      case 'fans': return '粉丝';
      case 'likers': return '赞与收藏';
      default: return '';
    }
  }

  Future<void> _loadData() async {
    try {
      final res = await ApiService().get('/users/${widget.userId}/${widget.type}');
      if (res['code'] == 200 && mounted) {
        setState(() {
          _users = (res['data'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
                  Expanded(child: Center(child: Text(_title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ),
          Container(height: 0.5, color: const Color(0xFFEEEEEE)),
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442)))
                : _users.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_outline, size: 48, color: const Color(0xFFDDDDDD)), const SizedBox(height: 12), const Text('暂无数据', style: TextStyle(fontSize: 14, color: Color(0xFF999999)))]))
                    : CustomScrollView(
                        slivers: [
                          CupertinoSliverRefreshControl(onRefresh: _loadData),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _buildUserItem(_users[i]),
                              childCount: _users.length,
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
    final userId = user['id'] as int? ?? 0;
    final nickname = user['nickname'] as String? ?? '';
    final avatar = user['avatar'] as String? ?? '';
    final bio = user['bio'] as String? ?? '';
    final fansCount = user['fans_count'] as int? ?? 0;
    final isFollowed = user['is_followed'] as bool? ?? false;
    final isFan = user['is_fan'] as bool? ?? false;
    final avatarUrl = fullUrl(avatar);
    final levelInfo = user['level_info'] as Map<String, dynamic>?;
    final level = levelInfo?['level'] as int? ?? 1;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/user-profile', arguments: userId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5))),
        child: Row(
          children: [
            avatarUrl.isNotEmpty
                ? CircleAvatar(radius: 22, backgroundImage: CachedNetworkImageProvider(avatarUrl))
                : CircleAvatar(radius: 22, backgroundColor: getColorForId(userId), child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
  children: [
    Flexible(child: Text(nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222)), overflow: TextOverflow.ellipsis)),
    if (level > 1) ...[
      const SizedBox(width: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: _getLevelColor(level).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text('Lv.$level', style: TextStyle(fontSize: 9, color: _getLevelColor(level), fontWeight: FontWeight.w600)),
      ),
    ],
  ],
),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(bio, style: const TextStyle(fontSize: 12, color: Color(0xFF999999)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ] else if (fansCount > 0) ...[
                    const SizedBox(height: 2),
                    Text('${fmtNum(fansCount)} 粉丝', style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                  ],
                  if (isFan && !isFollowed) ...[
                    const SizedBox(height: 2),
                    const Text('关注了你', style: TextStyle(fontSize: 11, color: Color(0xFFFF2442))),
                  ],
                  if (isFollowed && isFan) ...[
                    const SizedBox(height: 2),
                    const Text('互相关注', style: TextStyle(fontSize: 11, color: Color(0xFF1890FF))),
                  ],
                ],
              ),
            ),
            if (userId != (Provider.of<UserProvider>(context, listen: false).userInfo?.id ?? 0))
              _buildFollowBtn(userId, isFollowed, isFan),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowBtn(int userId, bool isFollowed, bool isFan) {
    final isMutual = isFollowed && isFan;
    return GestureDetector(
      onTap: () async {
        final up = Provider.of<UserProvider>(context, listen: false);
        final res = await up.followUser(userId);
        if (res['code'] == 200 && mounted) {
          final followed = res['data']?['followed'] as bool? ?? false;
          final fan = res['data']?['is_fan'] as bool? ?? false;
          setState(() {
            for (final u in _users) {
              if (u['id'] == userId) {
                u['is_followed'] = followed;
                u['is_fan'] = fan;
              }
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isFollowed ? const Color(0xFFF5F5F5) : null,
          gradient: isFollowed ? null : const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
          borderRadius: BorderRadius.circular(14),
          border: isFollowed ? Border.all(color: const Color(0xFFE0E0E0), width: 0.5) : null,
        ),
        child: Text(
          isMutual ? '互关' : (isFollowed ? '已关注' : '关注'),
          style: TextStyle(fontSize: 12, color: isFollowed ? const Color(0xFF999999) : Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Color _getLevelColor(int level) {
    if (level <= 3) return const Color(0xFF999999);
    if (level <= 6) return const Color(0xFF1890FF);
    if (level <= 9) return const Color(0xFF722ED1);
    return const Color(0xFFFAAD14);
  }
}
