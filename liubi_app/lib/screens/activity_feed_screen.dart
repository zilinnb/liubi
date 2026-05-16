import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});
  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;
  int _page = 1;
  bool _noMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _noMore = false;
    }
    try {
      final res = await ApiService().get('/users/activities/friends', queryParameters: {
        'page': _page,
        'pageSize': 20,
      });
      if (res['code'] == 200 && mounted) {
        final list = res['data'] as List? ?? [];
        final items = list.map((e) => e as Map<String, dynamic>).toList();
        setState(() {
          if (refresh) {
            _activities = items;
          } else {
            _activities.addAll(items);
          }
          if (items.length < 20) _noMore = true;
          _page++;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _actionText(Map<String, dynamic> a) {
    switch (a['type'] as int? ?? 0) {
      case 1: return '发布了笔记';
      case 2: return '赞了笔记';
      case 3: return '评论了';
      case 4: return '收藏了笔记';
      case 5: return '关注了';
      default: return '';
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
                  const Expanded(child: Center(child: Text('好友动态', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))))),
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : _activities.isEmpty
                    ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.explore_outlined, size: 48, color: Color(0xFFDDDDDD)),
                        SizedBox(height: 12),
                        Text('暂无好友动态', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
                      ]))
                    : RefreshIndicator(
                        onRefresh: () => _load(refresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 40),
                          itemCount: _activities.length + (_noMore ? 0 : 1),
                          itemBuilder: (_, i) {
                            if (i == _activities.length) {
                              _load();
                              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CupertinoActivityIndicator(radius: 10)));
                            }
                            return _buildItem(_activities[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> a) {
    final avatar = a['user_avatar'] as String? ?? '';
    final nickname = a['user_nickname'] as String? ?? '';
    final userId = a['user_id'] as int? ?? 0;
    final targetId = a['target_id'] as int?;
    final targetType = a['target_type'] as int? ?? 1;
    final createdAt = a['created_at'] as String? ?? '';
    final post = a['post'] as Map<String, dynamic>?;
    final action = _actionText(a);
    final postTitle = a['target_title'] as String? ?? '';
    final postCover = post?['cover'] as String? ?? '';
    final voiceUrl = post?['voice_url'] as String? ?? '';
    final voiceDuration = post?['voice_duration'] as int?;
    final postType = post?['post_type'] as int? ?? 0;
    final type = a['type'] as int? ?? 0;
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
              _buildFeedCover(postCover: postCover, voiceUrl: voiceUrl, voiceDuration: voiceDuration, postType: postType, postId: targetId, postTitle: postTitle)
            else if (type == 5)
              const Icon(Icons.person_add, size: 28, color: Color(0xFFFF2442))
            else
              _buildFeedCover(postCover: '', voiceUrl: '', voiceDuration: null, postType: 0, postId: targetId, postTitle: postTitle),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () { if (userId > 0) Navigator.pushNamed(context, '/user-profile', arguments: userId); },
                        child: avatar.isNotEmpty
                            ? CircleAvatar(radius: 12, backgroundImage: CachedNetworkImageProvider(fullUrl(avatar)))
                            : CircleAvatar(radius: 12, backgroundColor: getColorForId(userId), child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500))),
                      ),
                      const SizedBox(width: 6),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: nickname, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                            const TextSpan(text: ' ', style: TextStyle(fontSize: 14)),
                            TextSpan(text: action, style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
                          ],
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildFeedCover({required String postCover, required String voiceUrl, int? voiceDuration, required int postType, int? postId, String? postTitle}) {
    const double size = 56;
    if (postCover.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size, height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(imageUrl: fullUrl(postCover), fit: BoxFit.cover, errorWidget: (_, __, ___) => _buildFeedCoverPlaceholder(size, postId: postId, postTitle: postTitle)),
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
    return _buildFeedCoverPlaceholder(size, postId: postId, postTitle: postTitle);
  }

  Widget _buildFeedCoverPlaceholder(double size, {int? postId, String? postTitle}) {
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
}
