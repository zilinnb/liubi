import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../providers/post_provider.dart';
import '../models/post.dart';
import '../utils/helpers.dart';
import '../widgets/post_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();

  List<Post> _posts = [];
  List<Map<String, dynamic>> _users = [];
  List<String> _hotKeywords = [];
  List<String> _history = [];
  bool _searching = false;
  bool _searched = false;
  int _tabIndex = 0;
  int _sortIndex = 0;
  final List<String> _sortLabels = ['热度', '最新', '最多赞'];
  final List<String> _sortValues = ['hot', 'latest', 'most_liked'];
  int _page = 1;
  int _total = 0;
  bool _noMore = false;
  bool _loadingMore = false;
  double _navOpacity = 0.0;
  bool _showBackTop = false;
  bool _scrollScheduled = false;

  late TabController _tabCtrl;
  late TabController _sortTabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _tabIndex = _tabCtrl.index);
      }
    });
    _sortTabCtrl = TabController(length: 3, vsync: this);
    _sortTabCtrl.addListener(() {
      if (!_sortTabCtrl.indexIsChanging && _searched) {
        final newSort = _sortValues[_sortTabCtrl.index];
        if (newSort != _sortValues[_sortIndex]) {
          setState(() => _sortIndex = _sortTabCtrl.index);
          _doSearch(_searchCtrl.text);
        }
      }
    });
    _focusNode.requestFocus();
    _loadHistory();
    _loadHotKeywords();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _sortTabCtrl.dispose();
    _searchCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!_scrollCtrl.hasClients || !mounted) return;
      final offset = _scrollCtrl.offset;
      final progress = (offset / 80).clamp(0.0, 1.0);
      final show = offset > 300;
      if ((progress - _navOpacity).abs() > 0.01 || show != _showBackTop) {
        setState(() {
          _navOpacity = progress;
          _showBackTop = show;
        });
      }
      if (offset > _scrollCtrl.position.maxScrollExtent - 300 && _tabIndex == 0 && !_noMore && !_loadingMore) {
        _loadMorePosts();
      }
    });
  }

  Future<void> _loadHistory() async {
    final h = await StorageService.getSearchHistory();
    if (mounted) setState(() => _history = h);
  }

  Future<void> _loadHotKeywords() async {
    try {
      final res = await ApiService().get('/posts/trending', queryParameters: {'type': 'keyword'});
      if (res['code'] == 200) {
        final data = res['data'] as List? ?? [];
        if (mounted) setState(() {
          _hotKeywords = data.map((e) => (e['keyword'] ?? e['count']?.toString() ?? '') as String).where((k) => k.isNotEmpty).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _doSearch(String keyword) async {
    if (keyword.trim().isEmpty) return;
    _focusNode.unfocus();
    setState(() { _searching = true; _searched = true; _posts = []; _users = []; _page = 1; _noMore = false; _navOpacity = 0; _showBackTop = false; });
    _saveHistory(keyword.trim());
    await Future.wait([_searchPosts(keyword.trim()), _searchUsers(keyword.trim())]);
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _searchPosts(String keyword) async {
    try {
      final res = await ApiService().get('/posts/search', queryParameters: {
        'keyword': keyword,
        'page': 1,
        'pageSize': 20,
        'sort': _sortValues[_sortIndex],
      });
      if (res['code'] == 200 && mounted) {
        final data = res['data'] as Map<String, dynamic>;
        final list = data['list'] as List;
        _total = data['total'] as int? ?? 0;
        setState(() {
          _posts = list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
          _noMore = _posts.length >= _total;
        });
      }
    } catch (_) {}
  }

  Future<void> _searchUsers(String keyword) async {
    try {
      final res = await ApiService().get('/users/search', queryParameters: {'keyword': keyword});
      if (res['code'] == 200 && mounted) {
        final data = res['data'] as List? ?? [];
        setState(() => _users = List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore || _noMore) return;
    _loadingMore = true;
    _page++;
    try {
      final res = await ApiService().get('/posts/search', queryParameters: {
        'keyword': _searchCtrl.text.trim(),
        'page': _page,
        'pageSize': 20,
        'sort': _sortValues[_sortIndex],
      });
      if (res['code'] == 200 && mounted) {
        final data = res['data'] as Map<String, dynamic>;
        final list = data['list'] as List;
        final newPosts = list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
        setState(() {
          _posts = [..._posts, ...newPosts];
          _noMore = _posts.length >= _total;
        });
      }
    } catch (_) {}
    _loadingMore = false;
  }

  void _saveHistory(String keyword) async {
    if (!_history.contains(keyword)) {
      _history.insert(0, keyword);
      if (_history.length > 10) _history.removeLast();
    } else {
      _history.remove(keyword);
      _history.insert(0, keyword);
    }
    setState(() {});
    await StorageService.saveSearchHistory(_history);
  }

  void _removeHistory(int index) async {
    _history.removeAt(index);
    setState(() {});
    await StorageService.saveSearchHistory(_history);
  }

  void _clearHistory() async {
    setState(() => _history.clear());
    await StorageService.saveSearchHistory([]);
  }

  void _scrollToTop() {
    _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final hasText = _searchCtrl.text.isNotEmpty;

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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF333333))),
                  ),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      margin: EdgeInsets.only(right: hasText ? 8 : 14),
                      height: 32,
                      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 16, color: Color(0xFFBBBBBB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              focusNode: _focusNode,
                              style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.2),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                hintText: '搜索笔记或用户',
                                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                                suffixIcon: hasText
                                    ? GestureDetector(
                                        onTap: () { _searchCtrl.clear(); setState(() {}); },
                                        child: const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.cancel, size: 16, color: Color(0xFFBBBBBB))),
                                      )
                                    : null,
                              ),
                              onSubmitted: _doSearch,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hasText)
                    GestureDetector(
                      onTap: () => _doSearch(_searchCtrl.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(14)),
                        child: const Text('搜索', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_searched)
            Column(
              children: [
                Container(
                  height: 40,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TabBar(
                    controller: _tabCtrl,
                    labelColor: const Color(0xFFFF2442),
                    unselectedLabelColor: const Color(0xFF666666),
                    indicatorColor: const Color(0xFFFF2442),
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 2,
                    labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                    tabs: [
                      Tab(text: '笔记 ($_total)'),
                      Tab(text: '用户 (${_users.length})'),
                    ],
                  ),
                ),
                if (_tabIndex == 0 && _posts.isNotEmpty)
                  Container(
                    height: 36,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: List.generate(_sortLabels.length, (i) {
                        final isOn = _sortIndex == i;
                        return GestureDetector(
                          onTap: () {
                            if (_sortIndex != i) {
                              _sortTabCtrl.animateTo(i);
                              setState(() => _sortIndex = i);
                              _doSearch(_searchCtrl.text);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: isOn ? const Color(0xFFFF2442) : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(_sortLabels[i], style: TextStyle(fontSize: 12, color: isOn ? Colors.white : const Color(0xFF888888), fontWeight: isOn ? FontWeight.w600 : FontWeight.w400)),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          Expanded(
            child: _searching
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : _searched
                    ? TabBarView(
                        controller: _tabCtrl,
                        children: [_buildPostResults(), _buildUserResults()],
                      )
                    : _buildSearchHints(),
          ),
        ],
      ),
      floatingActionButton: _showBackTop ? _buildBackTop() : null,
    );
  }

  Widget _buildPostResults() {
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Color(0xFFDDDDDD)),
            const SizedBox(height: 12),
            const Text('没有找到相关笔记', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
          ],
        ),
      );
    }
    return CustomScrollView(
      controller: _scrollCtrl,
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () => _doSearch(_searchCtrl.text)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 5,
            crossAxisSpacing: 4,
            childCount: _posts.length + (_noMore ? 0 : 1),
            itemBuilder: (ctx, i) {
              if (i == _posts.length) {
                _loadMorePosts();
                return const Padding(padding: EdgeInsets.all(16), child: Center(child: CupertinoActivityIndicator(radius: 10)));
              }
              return PostCard(
                post: _posts[i],
                onTap: () => Navigator.pushNamed(context, '/detail', arguments: _posts[i].id),
                onLike: (_) => Provider.of<PostProvider>(context, listen: false).toggleLike(_posts[i].id),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildUserResults() {
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search_outlined, size: 48, color: Color(0xFFDDDDDD)),
            const SizedBox(height: 12),
            const Text('没有找到相关用户', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (_, i) => _buildUserItem(_users[i]),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    final avatarUrl = user['avatar'] as String? ?? '';
    final nickname = user['nickname'] as String? ?? '';
    final bio = user['bio'] as String? ?? '';
    final userId = user['id'] as int? ?? 0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/user-profile', arguments: userId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 1),
        color: Colors.white,
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: getColorForId(userId), shape: BoxShape.circle),
              child: avatarUrl.isNotEmpty
                  ? ClipOval(child: CachedNetworkImage(imageUrl: fullUrl(avatarUrl), width: 44, height: 44, fit: BoxFit.cover, errorWidget: (_, __, ___) => Center(child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)))))
                  : Center(child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                  if (bio.isNotEmpty) Text(bio, style: const TextStyle(fontSize: 12, color: Color(0xFF999999)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHints() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_history.isNotEmpty) ...[
            Row(
              children: [
                const Text('搜索历史', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
                const Spacer(),
                GestureDetector(onTap: _clearHistory, child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFCCCCCC))),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _history.asMap().entries.map((e) {
                final index = e.key;
                final k = e.value;
                return Container(
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () { _searchCtrl.text = k; _doSearch(k); },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          child: Text(k, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeHistory(index),
                        child: const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.close, size: 14, color: Color(0xFFCCCCCC)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(1.5))),
              const SizedBox(width: 8),
              const Text('热门搜索', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
            ],
          ),
          const SizedBox(height: 12),
          if (_hotKeywords.isEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['美食', '旅行', '穿搭', '美妆', '摄影', '运动', '音乐', '电影'].map((k) => GestureDetector(
                onTap: () { _searchCtrl.text = k; _doSearch(k); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: const Color(0xFFFFF0F3), borderRadius: BorderRadius.circular(16)),
                  child: Text(k, style: const TextStyle(fontSize: 13, color: Color(0xFFFF2442))),
                ),
              )).toList(),
            )
          else
            ..._hotKeywords.asMap().entries.map((e) => _buildHotItem(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildHotItem(int index, String keyword) {
    final gradients = [
      const [Color(0xFFFF2442), Color(0xFFFF6B81)],
      const [Color(0xFFFF6B2E), Color(0xFFFFAD42)],
      const [Color(0xFFFAAD14), Color(0xFFFFD666)],
    ];
    final isTop3 = index < 3;
    return GestureDetector(
      onTap: () { _searchCtrl.text = keyword; _doSearch(keyword); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 0.5))),
        child: Row(
          children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                gradient: isTop3 ? LinearGradient(colors: gradients[index]) : null,
                color: isTop3 ? null : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.center,
              child: Text('${index + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isTop3 ? Colors.white : const Color(0xFF999999))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(keyword, style: const TextStyle(fontSize: 14, color: Color(0xFF333333)))),
          ],
        ),
      ),
    );
  }

  Widget _buildBackTop() {
    return GestureDetector(
      onTap: _scrollToTop,
      child: Container(
        width: 44, height: 44,
        margin: const EdgeInsets.only(bottom: 80),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: const Icon(Icons.keyboard_arrow_up, size: 26, color: Color(0xFF666666)),
      ),
    );
  }
}
