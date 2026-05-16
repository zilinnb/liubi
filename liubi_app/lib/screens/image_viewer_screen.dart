import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/helpers.dart';
import '../widgets/app_toast.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const ImageViewerScreen({super.key, required this.urls, this.initialIndex = 0});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _ctrl;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          onLongPress: () => _showImageMenu(context),
          child: PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (_, i) => PhotoViewGalleryPageOptions(
              imageProvider: CachedNetworkImageProvider(fullUrl(widget.urls[i])),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
            ),
            itemCount: widget.urls.length,
            pageController: _ctrl,
            onPageChanged: (i) => setState(() => _current = i),
            loadingBuilder: (_, __) => const Center(child: CupertinoActivityIndicator(radius: 8, color: Colors.white)),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: Text('${_current + 1}/${widget.urls.length}', style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  void _showImageMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.pop(ctx);
                _saveImage(context);
              },
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14), child: Row(children: [
                Icon(Icons.save_alt, size: 22, color: Color(0xFF333333)),
                SizedBox(width: 14),
                Text('保存图片', style: TextStyle(fontSize: 16, color: Color(0xFF333333), fontWeight: FontWeight.w500)),
              ])),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(ctx),
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14), child: Row(children: [
                Icon(Icons.close, size: 22, color: Color(0xFF999999)),
                SizedBox(width: 14),
                Text('取消', style: TextStyle(fontSize: 16, color: Color(0xFF999999))),
              ])),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Future<void> _saveImage(BuildContext context) async {
    final url = fullUrl(widget.urls[_current]);
    try {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442))),
      );
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        if (context.mounted) {
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
      if (context.mounted) {
        Navigator.pop(context);
        AppToast.success(context, message: '已保存到相册');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        AppToast.error(context, message: '保存失败');
      }
    }
  }
}
