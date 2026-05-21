import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/post_provider.dart';
import 'providers/user_provider.dart';
import 'services/chat_service.dart';
import 'screens/main_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/category_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/notification_list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/publish_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/ai_image_screen.dart';
import 'screens/follow_list_screen.dart';
import 'screens/recommend_users_screen.dart';
import 'screens/trending_screen.dart';
import 'screens/about_screen.dart';
import 'screens/in_app_browser_screen.dart';
import 'screens/image_viewer_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/activity_feed_screen.dart';
import 'services/update_service.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';

class _AppScrollBehavior extends ScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  NotificationService.init();

  runApp(const LiubiApp());
}

class LiubiApp extends StatelessWidget {
  const LiubiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ChatService()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        scrollBehavior: const _AppScrollBehavior(),
        title: '留笔',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: AppColors.primary,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
          fontFamily: null,
          textTheme: Typography.blackCupertino.copyWith(
            bodyLarge: const TextStyle(letterSpacing: 0, decorationColor: Colors.transparent),
            bodyMedium: const TextStyle(letterSpacing: 0, decorationColor: Colors.transparent),
            bodySmall: const TextStyle(letterSpacing: 0, decorationColor: Colors.transparent),
            titleLarge: const TextStyle(letterSpacing: 0, decorationColor: Colors.transparent),
            titleMedium: const TextStyle(letterSpacing: 0, decorationColor: Colors.transparent),
            titleSmall: const TextStyle(letterSpacing: 0, decorationColor: Colors.transparent),
            labelLarge: const TextStyle(letterSpacing: 0, decorationColor: Colors.transparent),
            labelMedium: const TextStyle(letterSpacing: 0, decorationColor: Colors.transparent),
            labelSmall: const TextStyle(letterSpacing: 0, decorationColor: Colors.transparent),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Color(0xFF555555)),
            titleTextStyle: TextStyle(color: Color(0xFF222222), fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        home: const _AppRoot(),
        onGenerateRoute: (settings) {
          final name = settings.name;
          final args = settings.arguments;

          switch (name) {
            case '/detail':
              int? postId;
              int? highlightCommentId;
              if (args is int) {
                postId = args;
              } else if (args is Map) {
                final id = args['postId'] ?? args['id'];
                postId = id is int ? id : int.tryParse(id.toString());
                final cid = args['highlightCommentId'];
                highlightCommentId = cid is int ? cid : int.tryParse(cid?.toString() ?? '');
              } else {
                postId = int.tryParse(args.toString());
              }
              if (postId != null) {
                return MaterialPageRoute(builder: (_) => DetailScreen(postId: postId!, highlightCommentId: highlightCommentId), settings: settings);
              }
              return null;
            case '/chat':
              int? convId;
              String chatName = '';
              String chatAvatar = '';
              int otherUserId = 0;
              if (args is int) {
                convId = args;
              } else if (args is Map) {
                final id = args['id'];
                convId = id is int ? id : int.tryParse(id.toString());
                chatName = args['name'] is String ? args['name'] : '';
                chatAvatar = args['avatar'] is String ? args['avatar'] : '';
                otherUserId = args['otherUserId'] is int ? args['otherUserId'] : 0;
              }
              if (convId != null) {
                return MaterialPageRoute(builder: (_) => ChatScreen(conversationId: convId!, otherUserName: chatName, otherUserAvatar: chatAvatar, otherUserId: otherUserId), settings: settings);
              }
              return null;
            case '/category':
              final catId = args is int ? args : (args is Map ? args['id'] as int? : null);
              if (catId != null) {
                return MaterialPageRoute(builder: (_) => CategoryScreen(categoryId: catId), settings: settings);
              }
              return null;
            case '/user-profile':
              final userId = args is int ? args : int.tryParse(args.toString());
              if (userId != null) {
                return MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId), settings: settings);
              }
              return null;
            case '/notifications':
              final type = args is String ? args : 'system';
              return MaterialPageRoute(builder: (_) => NotificationListScreen(type: type), settings: settings);
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen(), settings: settings);
            case '/edit-profile':
              return MaterialPageRoute(builder: (_) => const EditProfileScreen(), settings: settings);
            case '/publish':
              final catId = args is int ? args : null;
              return MaterialPageRoute(builder: (_) => PublishScreen(initialCategoryId: catId), settings: settings);
            case '/search':
              return MaterialPageRoute(builder: (_) => const SearchScreen(), settings: settings);
            case '/settings':
              return MaterialPageRoute(builder: (_) => const SettingsScreen(), settings: settings);
            case '/ai-chat':
              return MaterialPageRoute(builder: (_) => const AiChatScreen(), settings: settings);
            case '/ai-image':
              return MaterialPageRoute(builder: (_) => const AiImageScreen(), settings: settings);
            case '/recommend-users':
              return MaterialPageRoute(builder: (_) => const RecommendUsersScreen(), settings: settings);
            case '/trending':
              return MaterialPageRoute(builder: (_) => const TrendingScreen(), settings: settings);
            case '/about':
              return MaterialPageRoute(builder: (_) => const AboutScreen(), settings: settings);
            case '/browser':
              if (args is Map) {
                final url = args['url'] as String? ?? '';
                final title = args['title'] as String?;
                return MaterialPageRoute(builder: (_) => InAppBrowserScreen(url: url, title: title), settings: settings);
              }
              return null;
            case '/image-viewer':
              if (args is Map) {
                final urls = args['urls'] as List<String>? ?? [];
                final index = args['index'] as int? ?? 0;
                return MaterialPageRoute(builder: (_) => ImageViewerScreen(urls: urls, initialIndex: index), settings: settings);
              }
              return null;
            case '/notification-settings':
              return MaterialPageRoute(builder: (_) => const NotificationSettingsScreen(), settings: settings);
            case '/privacy-settings':
              return MaterialPageRoute(builder: (_) => const PrivacySettingsScreen(), settings: settings);
            case '/activity-feed':
              return MaterialPageRoute(builder: (_) => const ActivityFeedScreen(), settings: settings);
            case '/follow-list':
              if (args is Map) {
                final type = args['type'] as String? ?? 'follows';
                final userId = args['userId'] as int? ?? 0;
                return MaterialPageRoute(builder: (_) => FollowListScreen(type: type, userId: userId), settings: settings);
              }
              return null;
            default:
              return null;
          }
        },
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NotificationService.requestPermission();
        ChatService().initLifecycle();
        UpdateService.checkUpdate(context, silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}
