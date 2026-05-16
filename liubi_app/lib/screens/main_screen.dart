import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/post_provider.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../widgets/custom_tabbar.dart';
import 'home_screen.dart';
import 'discover_screen.dart';
import 'message_screen.dart';
import 'mine_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static final GlobalKey<State<MainScreen>> globalKey = GlobalKey<State<MainScreen>>();
  static VoidCallback? onUnreadNeedsRefresh;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tabIndex = 0;
  int _unreadCount = 0;
  late PageController _pageCtrl;
  StreamSubscription? _wsSub;

  final List<GlobalKey<State<HomeScreen>>> _homeKeys = [GlobalKey()];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final up = Provider.of<UserProvider>(context, listen: false);
      if (up.isLoggedIn) up.fetchProfile();
      final pp = Provider.of<PostProvider>(context, listen: false);
      pp.fetchCategories();
      pp.fetchPosts();
      _loadUnread();
      _listenWs();
      MainScreen.onUnreadNeedsRefresh = _loadUnread;
    });
  }

  void _listenWs() {
    final cs = Provider.of<ChatService>(context, listen: false);
    if (!cs.isConnected) cs.connect();
    _wsSub = cs.onMessage.listen((msg) {
      if (msg['type'] == 'notification' || msg['type'] == 'chat') {
        _loadUnread();
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == -1) {
      Navigator.pushNamed(context, '/publish');
      return;
    }
    final isSameTab = _tabIndex == index;
    setState(() => _tabIndex = index);
    _pageCtrl.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    if (index == 2) _loadUnread();
    if (isSameTab && mounted) _refreshCurrentTab(index);
  }

  void _refreshCurrentTab(int index) {
    switch (index) {
      case 0:
        final state = _homeKeys[0].currentState;
        if (state != null) (state as dynamic).refresh();
        break;
      case 2:
        _loadUnread();
        break;
      case 3:
        Provider.of<UserProvider>(context, listen: false).fetchProfile();
        break;
    }
  }

  Future<void> _loadUnread() async {
    try {
      final up = Provider.of<UserProvider>(context, listen: false);
      if (!up.isLoggedIn) return;
      final res = await ApiService().get('/chat/conversations');
      if (res['code'] == 200 && mounted) {
        final list = res['data'] as List? ?? [];
        int total = 0;
        for (final c in list) {
          total += (c['unread_count'] as int? ?? 0);
        }
        final notifRes = await ApiService().get('/notifications/unread');
        if (notifRes['code'] == 200) {
          final data = notifRes['data'] as Map? ?? {};
          total += (data['like_count'] as int? ?? 0);
          total += (data['follow_count'] as int? ?? 0);
          total += (data['comment_count'] as int? ?? 0);
        }
        setState(() => _unreadCount = total);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: MainScreen.globalKey,
      body: PageView.builder(
        physics: const ClampingScrollPhysics(),
        controller: _pageCtrl,
        itemCount: 4,
        onPageChanged: (idx) {
          setState(() => _tabIndex = idx);
        },
        itemBuilder: (ctx, idx) {
          switch (idx) {
            case 0:
              return HomeScreen(key: _homeKeys[0]);
            case 1:
              return const DiscoverScreen();
            case 2:
              return const MessageScreen();
            default:
              return const MineScreen();
          }
        },
      ),
      bottomNavigationBar: Consumer<UserProvider>(
        builder: (_, up, __) {
          return CustomTabbar(
            current: _tabIndex,
            onTap: _onTabTap,
            unreadCount: _unreadCount,
          );
        },
      ),
    );
  }
}
