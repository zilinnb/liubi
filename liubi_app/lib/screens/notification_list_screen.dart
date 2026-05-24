import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../utils/helpers.dart';

class NotificationListScreen extends StatefulWidget {
  final String type;
  const NotificationListScreen({super.key, required this.type});
  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final ScrollController _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  int _page = 1;
  bool _noMore = false;
  bool _loadingMore = false;
  String _currentTypeNum = '';
  bool _showBackTop = false;
  bool _scrollScheduled = false;
  static const int _pageSize = 20;

  List<_SubTab> _subTabs = [];

  @override
  void initState() {
    super.initState();
    _initSubTabs();
    _tabCtrl = TabController(length: _subTabs.length, vsync: this);
    _currentTypeNum = _subTabs.isNotEmpty ? _subTabs[0].typeNum : '';
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      final newType = _subTabs[_tabCtrl.index].typeNum;
      if (newType != _currentTypeNum) {
        setState(() {
          _currentTypeNum = newType;
          _notifications.clear();
          _page = 1;
          _noMore = false;
          _loading = true;
          _showBackTop = false;
        });
        _loadNotifications();
      }
    });
    _scrollCtrl.addListener(_onScroll);
    _loadNotifications();
    Provider.of<UserProvider>(context, listen: false).markNotificationsRead(widget.type);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!_scrollCtrl.hasClients || !mounted) return;
      final show = _scrollCtrl.offset > 300;
      if (show != _showBackTop) {
        setState(() => _showBackTop = show);
      }
      // 上拉加载更多
      if (!_loadingMore && !_noMore) {
        final maxScroll = _scrollCtrl.position.maxScrollExtent;
        final currentScroll = _scrollCtrl.position.pixels;
        if (maxScroll - currentScroll <= 300) {
          _loadMore();
        }
      }
    });
  }

  void _scrollToTop() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  void _initSubTabs() {
    switch (widget.type) {
      case 'like':
        _subTabs = [
          _SubTab(label: '赞', typeNum: '1'),
          _SubTab(label: '收藏', typeNum: '6'),
        ];
        break;
      case 'follow':
        _subTabs = [
          _SubTab(label: '关注', typeNum: '3'),
        ];
        break;
      case 'comment':
        _subTabs = [
          _SubTab(label: '评论', typeNum: '2'),
          _SubTab(label: '@我', typeNum: '5'),
        ];
        break;
      default:
        _subTabs = [_SubTab(label: '全部', typeNum: '1,2,3,5,6')];
    }
  }

  String get _title {
    switch (widget.type) {
      case 'like': return '赞和收藏';
      case 'follow': return '新增关注';
      case 'comment': return '评论和@';
      default: return '消息通知';
    }
  }

  String _getActionText(Map<String, dynamic> notif) {
    final type = notif['type'] as int? ?? 0;
    switch (type) {
      case 1: return '赞了你的笔记';
      case 6: return '收藏了你的笔记';
      case 2: return notif['content'] as String? ?? '评论了你的笔记';
      case 3: return '关注了你';
      case 5: return '在笔记中提到了你';
      default: return '';
    }
  }

  String? _getPostCover(Map<String, dynamic> notif) {
    final cover = notif['post_cover'] as String?;
    if (cover != null && cover.isNotEmpty) return fullUrl(cover);
    return null;
  }

  Future<void> _markAsRead(int notifId) async {
    try {
      await ApiService().post('/notifications/$notifId/read');
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService().post('/notifications/read-all', data: {'type': _currentTypeNum});
      setState(() {
        for (final n in _notifications) {
          n['is_read'] = 1;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadNotifications() async {
    // 第一页先尝试加载本地缓存
    if (_page == 1) {
      final cached = await StorageService.getNotifications(widget.type, _currentTypeNum);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _notifications = cached;
          _loading = false;
        });
      }
    }
    try {
      final res = await ApiService().get('/notifications', queryParameters: {'type': _currentTypeNum, 'page': _page, 'pageSize': _pageSize});
      if (res['code'] == 200 && mounted) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        final list = (data['list'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
        final total = data['total'] as int? ?? 0;
        if (widget.type == 'follow') {
          final seen = <int>{};
          final deduped = <Map<String, dynamic>>[];
          for (final item in list.reversed) {
            final userId = item['from_user_id'] as int? ?? 0;
            if (userId > 0 && !seen.contains(userId)) {
              seen.add(userId);
              deduped.insert(0, item);
            }
          }
          for (final item in deduped) {
            final userId = item['from_user_id'] as int? ?? 0;
            if (userId > 0 && item['is_followed'] == null) {
              try {
                final checkRes = await ApiService().get('/users/$userId/follow-status');
                if (checkRes['code'] == 200) {
                  item['is_followed'] = checkRes['data']?['is_followed'] ?? false;
                  item['is_fan'] = checkRes['data']?['is_fan'] ?? false;
                }
              } catch (_) {}
            }
          }
          setState(() {
            if (_page == 1) { _notifications = deduped; } else { _notifications.addAll(deduped); }
            _noMore = _notifications.length >= total;
            _loading = false;
          });
          if (_page == 1) await StorageService.saveNotifications(widget.type, _currentTypeNum, _notifications);
        } else {
          setState(() {
            if (_page == 1) { _notifications = list; } else { _notifications.addAll(list); }
            _noMore = _notifications.length >= total;
            _loading = false;
          });
          if (_page == 1) await StorageService.saveNotifications(widget.type, _currentTypeNum, _notifications);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _noMore) return;
    setState(() => _loadingMore = true);
    _page++;
    try {
      final res = await ApiService().get('/notifications', queryParameters: {'type': _currentTypeNum, 'page': _page, 'pageSize': _pageSize});
      if (res['code'] == 200 && mounted) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        final list = (data['list'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
        final total = data['total'] as int? ?? 0;
        if (widget.type == 'follow') {
          final seen = <int>{};
          final deduped = <Map<String, dynamic>>[];
          for (final item in list.reversed) {
            final userId = item['from_user_id'] as int? ?? 0;
            if (userId > 0 && !seen.contains(userId)) {
              seen.add(userId);
              deduped.insert(0, item);
            }
          }
          for (final item in deduped) {
            final userId = item['from_user_id'] as int? ?? 0;
            if (userId > 0 && item['is_followed'] == null) {
              try {
                final checkRes = await ApiService().get('/users/$userId/follow-status');
                if (checkRes['code'] == 200) {
                  item['is_followed'] = checkRes['data']?['is_followed'] ?? false;
                  item['is_fan'] = checkRes['data']?['is_fan'] ?? false;
                }
              } catch (_) {}
            }
          }
          setState(() {
            _notifications.addAll(deduped);
            _noMore = _notifications.length >= total;
            _loadingMore = false;
          });
        } else {
          setState(() {
            _notifications.addAll(list);
            _noMore = _notifications.length >= total;
            _loadingMore = false;
          });
        }
      } else {
        _page--;
        setState(() => _loadingMore = false);
      }
    } catch (_) {
      _page--;
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final hasUnread = _notifications.any((n) => (n['is_read'] as int?) != 1);
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF222222)),
                    ),
                  ),
                  Expanded(
                    child: Text(_title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
                  ),
                  if (hasUnread)
                    GestureDetector(
                      onTap: _markAllRead,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text('一键已读', style: TextStyle(fontSize: 13, color: Color(0xFFFF2442), fontWeight: FontWeight.w500)),
                      ),
                    )
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ),
          ),
          if (_subTabs.length > 1)
            Container(
              decoration: const BoxDecoration(color: Colors.white),
              child: TabBar(
                controller: _tabCtrl,
                labelColor: const Color(0xFF222222),
                unselectedLabelColor: const Color(0xFF999999),
                indicatorColor: const Color(0xFFFF2442),
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2.5,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                tabs: _subTabs.map((t) => Tab(text: t.label)).toList(),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : Stack(
                    children: [
                      TabBarView(
                        controller: _tabCtrl,
                        children: _subTabs.map((tab) => _buildTabContent(tab.typeNum)).toList(),
                      ),
                      if (_showBackTop) _buildBackTop(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackTop() {
    return Positioned(
      right: 16,
      bottom: 80,
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

  Widget _buildTabContent(String typeNum) {
    final filtered = typeNum == _currentTypeNum ? _notifications : [];
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 48, color: const Color(0xFFDDDDDD)),
            const SizedBox(height: 12),
            const Text('暂无通知', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
          ],
        ),
      );
    }
    return CustomScrollView(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            setState(() { _notifications.clear(); _page = 1; _noMore = false; _loading = true; _showBackTop = false; });
            await _loadNotifications();
          },
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _buildNotificationItem(filtered[i]),
            childCount: filtered.length,
          ),
        ),
        if (_loadingMore)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CupertinoActivityIndicator(radius: 10)))),
        if (_noMore && filtered.isNotEmpty)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('没有更多了', style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)))))),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif) {
    final avatar = notif['from_avatar'] as String? ?? '';
    final nickname = notif['from_nickname'] as String? ?? '';
    final createdAt = notif['created_at'] as String? ?? '';
    final userId = notif['from_user_id'] as int? ?? 0;
    final targetId = notif['target_id'] as int?;
    final notifId = notif['id'] as int? ?? 0;
    final isRead = (notif['is_read'] as int?) == 1;
    final avatarUrl = fullUrl(avatar);
    final actionText = _getActionText(notif);
    final postCover = _getPostCover(notif);
    final postTitle = notif['post_title'] as String? ?? '';
    final notifType = notif['type'] as int? ?? 0;
    final isFollow = notifType == 3;
    final isFollowed = notif['is_followed'] == true;
    final isFan = notif['is_fan'] == true;
    final isMutual = isFollowed && isFan;
    final commentId = notif['comment_id'] as int?;

    return GestureDetector(
      onTap: () {
        if (!isRead) {
          _markAsRead(notifId);
          setState(() { notif['is_read'] = 1; });
        }
        if (targetId != null && !isFollow) {
          Navigator.pushNamed(context, '/detail', arguments: {
            'postId': targetId,
            if (commentId != null) 'highlightCommentId': commentId,
          });
        } else if (isFollow && userId > 0) {
          Navigator.pushNamed(context, '/user-profile', arguments: userId);
        }
      },
      child: Container(
        color: isRead ? Colors.white : const Color(0xFFFFF8F8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () { if (userId > 0) Navigator.pushNamed(context, '/user-profile', arguments: userId); },
              child: avatarUrl.isNotEmpty
                  ? CircleAvatar(radius: 22, backgroundImage: CachedNetworkImageProvider(avatarUrl))
                  : CircleAvatar(radius: 22, backgroundColor: getColorForId(userId), child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(text: nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                              const TextSpan(text: ' ', style: TextStyle(fontSize: 15)),
                              TextSpan(text: actionText, style: const TextStyle(fontSize: 15, color: Color(0xFF666666))),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 6),
                          decoration: const BoxDecoration(color: Color(0xFFFF2442), shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  if (postTitle.isNotEmpty && !isFollow) ...[
                    const SizedBox(height: 6),
                    Text(
                      postTitle,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(fmtTime(createdAt), style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
                ],
              ),
            ),
            if (postCover != null && !isFollow) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: postCover,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(width: 52, height: 52, color: const Color(0xFFF0F0F0)),
                ),
              ),
            ],
            if (isFollow) ...[
              const SizedBox(width: 12),
              _buildFollowButton(userId, isFollowed, isFan, isMutual),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFollowButton(int userId, bool isFollowed, bool isFan, bool isMutual) {
    return GestureDetector(
      onTap: () async {
        try {
          final up = Provider.of<UserProvider>(context, listen: false);
          final res = await up.followUser(userId);
          if (res['code'] == 200 && mounted) {
            final followed = res['data']?['followed'] as bool? ?? !isFollowed;
            try {
              final checkRes = await ApiService().get('/users/$userId/follow-status');
              if (checkRes['code'] == 200) {
                final fan = checkRes['data']?['is_fan'] ?? false;
                setState(() {
                  for (final n in _notifications) {
                    if (n['from_user_id'] == userId) {
                      n['is_followed'] = followed;
                      n['is_fan'] = fan;
                    }
                  }
                });
                return;
              }
            } catch (_) {}
            setState(() {
              for (final n in _notifications) {
                if (n['from_user_id'] == userId) {
                  n['is_followed'] = followed;
                }
              }
            });
          }
        } catch (_) {}
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isMutual ? const Color(0xFFE6F7FF) : (isFollowed ? const Color(0xFFF5F5F5) : null),
          gradient: isMutual || isFollowed ? null : const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
          borderRadius: BorderRadius.circular(14),
          border: isMutual ? Border.all(color: const Color(0xFF1890FF), width: 0.5) : (isFollowed ? Border.all(color: const Color(0xFFE8E8E8), width: 0.5) : null),
        ),
        child: Text(isMutual ? '互关' : (isFollowed ? '已关注' : '回关'), style: TextStyle(fontSize: 12, color: isMutual ? const Color(0xFF1890FF) : (isFollowed ? const Color(0xFF999999) : Colors.white), fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SubTab {
  final String label;
  final String typeNum;
  _SubTab({required this.label, required this.typeNum});
}
