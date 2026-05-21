import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/helpers.dart';
import '../widgets/app_toast.dart';

/// 统一图片预览组件
/// 支持多图滑动、页码显示、保存、分享
class ImageViewerScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const ImageViewerScreen({super.key, required this.urls, this.initialIndex = 0});

  /// 快速打开图片预览
  static void open(BuildContext context, {required List<String> urls, int initialIndex = 0}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => ImageViewerScreen(urls: urls, initialIndex: initialIndex),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
      ),
    );
  }

  /// 打开单张图片
  static void openSingle(BuildContext context, {required String url}) {
    open(context, urls: [url]);
  }

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _ctrl;
  int _current = 0;
  SystemUiOverlayStyle? _previousStyle;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: _current);
    // 保存当前状态栏样式，然后切换为亮色（白字黑底）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previousStyle = SystemChrome.latestStyle;
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    });
  }

  @override
  void dispose() {
    // 恢复之前的状态栏样式
    if (_previousStyle != null) {
      SystemChrome.setSystemUIOverlayStyle(_previousStyle!);
    } else {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ));
    }
    _ctrl.dispose();
    super.dispose();
  }

  String _fullUrl(int index) {
    final url = widget.urls[index];
    if (url.startsWith('http')) return url;
    return fullUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // 图片浏览区（长按弹出菜单）
        GestureDetector(
          onLongPress: () => _showMenu(),
          child: PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (_, i) => PhotoViewGalleryPageOptions(
              imageProvider: CachedNetworkImageProvider(_fullUrl(i)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
            ),
            itemCount: widget.urls.length,
            pageController: _ctrl,
            onPageChanged: (i) => setState(() => _current = i),
            loadingBuilder: (_, __) => const Center(
              child: CupertinoActivityIndicator(radius: 8, color: Colors.white),
            ),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),

        // 顶部栏
        Positioned(
          top: statusBarH,
          left: 0,
          right: 0,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 关闭按钮
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
                // 页码
                if (widget.urls.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_current + 1}/${widget.urls.length}',
                      style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  )
                else
                  const SizedBox(width: 36),
                // 更多按钮
                GestureDetector(
                  onTap: () => _showMenu(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_horiz, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 拖拽条
            Container(
              width: 36, height: 4, margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            // 保存
            _menuItem(Icons.save_alt, '保存图片', const Color(0xFF333333), () {
              Navigator.pop(ctx);
              _saveImage();
            }),
            // 分享
            _menuItem(Icons.share, '分享', const Color(0xFF333333), () {
              Navigator.pop(ctx);
              _shareImage();
            }),
            const Divider(height: 1, indent: 54, endIndent: 20),
            // 取消
            _menuItem(Icons.close, '取消', const Color(0xFF999999), () {
              Navigator.pop(ctx);
            }),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 14),
          Text(text, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Future<void> _saveImage() async {
    final url = _fullUrl(_current);
    try {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442))),
      );
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        if (mounted) {
          Navigator.pop(context);
          AppToast.error(context, message: '需要存储权限才能保存图片');
        }
        return;
      }
      final response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/liubi_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.data);
      await Gal.putImage(file.path, album: '留笔');
      await file.delete();
      if (mounted) {
        Navigator.pop(context);
        AppToast.success(context, message: '已保存到相册');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppToast.error(context, message: '保存失败');
      }
    }
  }

  Future<void> _shareImage() async {
    final url = _fullUrl(_current);
    try {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442))),
      );
      final response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/liubi_share_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.data);
      if (mounted) {
        Navigator.pop(context);
        // 使用系统分享，支持微信/QQ等
        await Share.shareXFiles([XFile(file.path)], text: '来自留笔');
        // 分享完成后删除临时文件
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppToast.error(context, message: '分享失败');
      }
    }
  }
}
