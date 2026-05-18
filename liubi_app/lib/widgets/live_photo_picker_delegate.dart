import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:video_player/video_player.dart';
import '../utils/live_photo_util.dart';

class LivePhotoPickerDelegate extends DefaultAssetPickerBuilderDelegate {
  LivePhotoPickerDelegate({
    required super.provider,
    required super.initialPermission,
    super.gridCount,
    super.pickerTheme,
    super.textDelegate,
    super.locale,
  }) : super(enableLivePhoto: true);

  @override
  Widget imageAndVideoItemBuilder(
    BuildContext context,
    int index,
    AssetEntity asset,
  ) {
    final baseItem = super.imageAndVideoItemBuilder(context, index, asset);

    if (asset.type != AssetType.image) return baseItem;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        baseItem,
        _LivePhotoBadgeOverlay(asset: asset),
      ],
    );
  }

  @override
  Future<void> viewAsset(
    BuildContext context,
    int? index,
    AssetEntity currentAsset,
  ) async {
    final isMotion = LivePhotoUtil.isCachedMotionPhoto(currentAsset.id) ||
        (currentAsset.title ?? '').toUpperCase().startsWith('MVIMG');

    if (currentAsset.type == AssetType.image && isMotion) {
      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _LivePhotoPreviewPage(
            asset: currentAsset,
            isSelected: provider.selectedAssets.contains(currentAsset),
          ),
        ),
      );
      if (confirmed == true && !provider.selectedAssets.contains(currentAsset)) {
        selectAsset(context, currentAsset, index ?? 0, false);
      }
      return;
    }

    return super.viewAsset(context, index, currentAsset);
  }
}

class _LivePhotoBadgeOverlay extends StatefulWidget {
  final AssetEntity asset;
  const _LivePhotoBadgeOverlay({required this.asset});

  @override
  State<_LivePhotoBadgeOverlay> createState() => _LivePhotoBadgeOverlayState();
}

class _LivePhotoBadgeOverlayState extends State<_LivePhotoBadgeOverlay> {
  bool _isMotion = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  void _check() {
    final cached = LivePhotoUtil.isCachedMotionPhoto(widget.asset.id);
    if (cached) {
      _isMotion = true;
      return;
    }

    final title = widget.asset.title ?? '';
    if (title.toUpperCase().startsWith('MVIMG')) {
      _isMotion = true;
      LivePhotoUtil.isMotionPhotoByAsset(widget.asset);
      return;
    }

    _checkAsync();
  }

  Future<void> _checkAsync() async {
    final result = await LivePhotoUtil.isMotionPhotoByAsset(widget.asset);
    if (!mounted) return;
    if (result != _isMotion) {
      setState(() {
        _isMotion = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMotion) return const SizedBox.shrink();
    return Positioned(
      left: 4,
      top: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/icon_live_photo.png',
              width: 12,
              height: 12,
            ),
            const SizedBox(width: 2),
            const Text(
              'LIVE',
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePhotoPreviewPage extends StatefulWidget {
  final AssetEntity asset;
  final bool isSelected;
  const _LivePhotoPreviewPage({
    required this.asset,
    required this.isSelected,
  });

  @override
  State<_LivePhotoPreviewPage> createState() => _LivePhotoPreviewPageState();
}

class _LivePhotoPreviewPageState extends State<_LivePhotoPreviewPage> {
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _isPlaying = false;
  bool _isLongPressing = false;
  String? _errorMsg;
  String? _imagePath;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _loadVideo();
  }

  Future<void> _loadImage() async {
    final file = await widget.asset.originFile;
    if (file != null && mounted) {
      setState(() => _imagePath = file.path);
    }
  }

  Future<void> _loadVideo() async {
    try {
      String? filePath;
      final title = widget.asset.title ?? '';
      final relativePath = widget.asset.relativePath ?? '';
      if (relativePath.isNotEmpty && title.isNotEmpty) {
        for (final prefix
            in ['/storage/emulated/0/', '/sdcard/', '/mnt/sdcard/']) {
          final p = '$prefix$relativePath$title';
          if (await File(p).exists()) {
            filePath = p;
            break;
          }
        }
      }
      if (filePath == null) {
        final file = await widget.asset.originFile;
        filePath = file?.path;
      }
      if (filePath == null) {
        setState(() => _errorMsg = '无法获取文件');
        return;
      }

      final vp = await LivePhotoUtil.extractVideo(filePath);
      if (vp == null) {
        setState(() => _errorMsg = '无法提取视频');
        return;
      }
      _videoPath = vp;
      _videoCtrl = VideoPlayerController.file(File(vp));
      await _videoCtrl!.initialize();
      _videoCtrl!.setLooping(true);
      if (mounted) setState(() => _videoReady = true);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = '视频加载失败');
    }
  }

  void _onLongPressStart(_) {
    if (!_videoReady) return;
    _videoCtrl!.seekTo(Duration.zero);
    _videoCtrl!.play();
    setState(() {
      _isPlaying = true;
      _isLongPressing = true;
    });
  }

  void _onLongPressEnd(_) {
    if (!_videoReady) return;
    _videoCtrl!.pause();
    setState(() {
      _isPlaying = false;
      _isLongPressing = false;
    });
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                  if (_isLongPressing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/icons/icon_live_photo.png', width: 14, height: 14),
                          const SizedBox(width: 3),
                          const Text('LIVE', style: TextStyle(fontSize: 11, color: Color(0xFF333333), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
            Expanded(
              child: _errorMsg != null
                  ? Center(child: Text(_errorMsg!, style: const TextStyle(color: Colors.white54, fontSize: 14)))
                  : GestureDetector(
                      onLongPressStart: _onLongPressStart,
                      onLongPressEnd: _onLongPressEnd,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_imagePath != null)
                            Image.file(
                              File(_imagePath!),
                              fit: BoxFit.contain,
                            ),
                          if (_videoReady && _isPlaying)
                            Center(
                              child: AspectRatio(
                                aspectRatio: _videoCtrl!.value.aspectRatio,
                                child: VideoPlayer(_videoCtrl!),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            if (!_isLongPressing && _videoReady)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '长按播放实况照片',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2442),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '确定',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
