import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';

class _ImageItem {
  int? id;
  final String prompt;
  String? imageUrl;
  bool isGenerating;
  bool isFailed;
  String? errorMsg;
  _ImageItem({this.id, required this.prompt, this.imageUrl, this.isGenerating = false, this.isFailed = false, this.errorMsg});
}

class AiImageScreen extends StatefulWidget {
  const AiImageScreen({super.key});

  @override
  State<AiImageScreen> createState() => _AiImageScreenState();
}

class _AiImageScreenState extends State<AiImageScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<_ImageItem> _items = [];
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _shimmerCtrl.repeat();
    _inputCtrl.addListener(() => setState(() {}));
    _loadHistory();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _scrollToBottom();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shimmerCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      return;
    }
    final max = _scrollCtrl.position.maxScrollExtent;
    _scrollCtrl.animateTo(max, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  Future<void> _loadHistory() async {
    try {
      final res = await ApiService().get('/ai/image/history?limit=50');
      if (res['code'] == 200 && mounted) {
        final list = res['data'] as List? ?? [];
        setState(() {
          _items = list.map((e) => _ImageItem(
            id: e['id'] as int?,
            prompt: e['prompt'] as String? ?? '',
            imageUrl: e['image_url'] as String? ?? '',
            isGenerating: false,
          )).toList().reversed.toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _generateImage() async {
    final prompt = _inputCtrl.text.trim();
    if (prompt.isEmpty) return;

    _inputCtrl.clear();
    _dismissKeyboard();

    final item = _ImageItem(prompt: prompt, isGenerating: true);
    setState(() => _items.add(item));
    _scrollToBottom();

    try {
      final res = await ApiService().post('/ai/image/generate', data: {'prompt': prompt}, timeout: 120);
      if (res['code'] == 200 && mounted) {
        final data = res['data'];
        setState(() {
          item.id = data['id'] as int?;
          item.imageUrl = data['image_url'] as String? ?? '';
          item.isGenerating = false;
        });
      } else if (mounted) {
        setState(() {
          item.isGenerating = false;
          item.isFailed = true;
          item.errorMsg = res['msg'] ?? '生成失败';
        });
        AppToast.error(context, message: res['msg'] ?? '生成失败');
      }
    } on DioException catch (e) {
      debugPrint('[AI绘画] 请求异常: type=${e.type}, msg=${e.message}');
      if (mounted) {
        setState(() {
          item.isGenerating = false;
          item.isFailed = true;
          item.errorMsg = e.type == DioExceptionType.receiveTimeout ? '生成超时，请重试' : '网络错误';
        });
        AppToast.error(context, message: item.errorMsg!);
      }
    } catch (e) {
      debugPrint('[AI绘画] 未知异常: $e');
      if (mounted) {
        setState(() {
          item.isGenerating = false;
          item.isFailed = true;
          item.errorMsg = '生成失败';
        });
        AppToast.error(context, message: '生成失败');
      }
    }
    if (mounted) _scrollToBottom();
  }

  Future<void> _retryGenerate(_ImageItem item) async {
    setState(() {
      item.isGenerating = true;
      item.isFailed = false;
      item.errorMsg = null;
      item.imageUrl = null;
    });
    _scrollToBottom();

    try {
      final res = await ApiService().post('/ai/image/generate', data: {'prompt': item.prompt}, timeout: 120);
      if (res['code'] == 200 && mounted) {
        final data = res['data'];
        setState(() {
          item.id = data['id'] as int?;
          item.imageUrl = data['image_url'] as String? ?? '';
          item.isGenerating = false;
        });
      } else if (mounted) {
        setState(() {
          item.isGenerating = false;
          item.isFailed = true;
          item.errorMsg = res['msg'] ?? '生成失败';
        });
      }
    } on DioException catch (e) {
      debugPrint('[AI绘画] 重试异常: type=${e.type}, msg=${e.message}');
      if (mounted) {
        setState(() {
          item.isGenerating = false;
          item.isFailed = true;
          item.errorMsg = e.type == DioExceptionType.receiveTimeout ? '生成超时，请重试' : '网络错误';
        });
      }
    }
    if (mounted) _scrollToBottom();
  }

  Future<void> _deleteItem(_ImageItem item) async {
    if (item.id != null) {
      try { await ApiService().delete('/ai/image/${item.id}'); } catch (_) {}
    }
    setState(() => _items.remove(item));
  }

  String _getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return 'http://36.140.128.103:3000$url';
  }

  void _previewImage(String url) {
    _dismissKeyboard();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ImagePreviewScreen(imageUrl: _getImageUrl(url)),
    ));
  }

  Future<void> _saveImage(String url) async {
    final fullUrl = _getImageUrl(url);
    if (fullUrl.isEmpty) return;
    await _doSaveImage(context, fullUrl);
  }

  static Future<void> _doSaveImage(BuildContext context, String imageUrl) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Container(
          color: Colors.black26,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xCC000000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(radius: 14, color: Colors.white),
                SizedBox(height: 12),
                Text('正在保存...', style: TextStyle(fontSize: 14, color: Colors.white, decoration: TextDecoration.none)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/ai_image_${DateTime.now().millisecondsSinceEpoch}.png';
      await Dio().download(imageUrl, filePath);
      await Gal.putImage(filePath, album: '留笔AI');
      if (context.mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, message: '保存成功');
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context).pop();
        AppToast.error(context, message: '保存失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildAppBar(statusBarH),
          Expanded(child: _buildBody()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar(double statusBarH) {
    return Container(
      padding: EdgeInsets.only(top: statusBarH),
      color: Colors.white,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.arrow_back, size: 22, color: Color(0xFF222222)),
              ),
            ),
            const Text('AI绘画', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty) return _buildEmptyView();
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: _items.length,
      itemBuilder: (_, i) => _buildImageItem(_items[i]),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Icon(Icons.brush, size: 24, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          const Text('描述你想生成的图片', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
          const SizedBox(height: 8),
          const Text('AI将为你创作独一无二的画作', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('一只在月光下弹琴的猫'),
              _buildSuggestionChip('赛博朋克风格的城市'),
              _buildSuggestionChip('水彩画风格的樱花'),
              _buildSuggestionChip('星空下的海边小屋'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () { _inputCtrl.text = text; _generateImage(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
      ),
    );
  }

  Widget _buildImageItem(_ImageItem item) {
    final screenW = MediaQuery.of(context).size.width;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(maxWidth: screenW * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFF2442),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(item.prompt, style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.5)),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: screenW * 0.85),
              child: item.isGenerating
                ? _buildShimmerPlaceholder()
                : item.isFailed
                  ? _buildFailedPlaceholder(item)
                  : (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    ? _buildImageResult(item)
                    : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) {
        final t = _shimmerCtrl.value;
        final shimmerPos = -0.3 + t * 1.6;
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: CustomPaint(
              painter: _ImageSkeletonPainter(shimmerPos: shimmerPos),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFailedPlaceholder(_ImageItem item) {
    return GestureDetector(
      onTap: () => _retryGenerate(item),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE0E0), width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 32, color: Color(0xFFFF2442)),
            const SizedBox(height: 8),
            Text(item.errorMsg ?? '生成失败', style: const TextStyle(fontSize: 13, color: Color(0xFFFF2442))),
            const SizedBox(height: 4),
            const Text('点击重试', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
          ],
        ),
      ),
    );
  }

  Widget _buildImageResult(_ImageItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _previewImage(item.imageUrl!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: CachedNetworkImage(
                imageUrl: _getImageUrl(item.imageUrl),
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: const Color(0xFFF5F5F5),
                  child: const Center(child: CupertinoActivityIndicator(radius: 12, color: Color(0xFFFF2442))),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFFF5F5F5),
                  child: const Center(child: Icon(Icons.broken_image, size: 40, color: Color(0xFFDDDDDD))),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildActionBtn(Icons.download_outlined, () => _saveImage(item.imageUrl!)),
            _buildActionBtn(Icons.share_outlined, () {}),
            const Spacer(),
            _buildActionBtn(Icons.refresh, () => _retryGenerate(item)),
            _buildActionBtn(Icons.delete_outline, () => _deleteItem(item), color: const Color(0xFFBBBBBB)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44, height: 44,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: color ?? const Color(0xFF666666)),
      ),
    );
  }

  Widget _buildInputBar() {
    final hasText = _inputCtrl.text.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _inputCtrl,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _generateImage(),
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '描述你想生成的图片...',
                  hintStyle: TextStyle(fontSize: 15, color: Color(0xFFBBBBBB)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (hasText)
            GestureDetector(
              onTap: _generateImage,
              child: Container(
                width: 32, height: 32,
                margin: const EdgeInsets.only(left: 4, bottom: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF2442),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageSkeletonPainter extends CustomPainter {
  final double shimmerPos;
  _ImageSkeletonPainter({required this.shimmerPos});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF0F0F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final skeletonPaint = Paint()..color = const Color(0xFFE0E0E0);

    final mountainPath = Path();
    mountainPath.moveTo(0, size.height * 0.65);
    mountainPath.lineTo(size.width * 0.2, size.height * 0.4);
    mountainPath.lineTo(size.width * 0.35, size.height * 0.55);
    mountainPath.lineTo(size.width * 0.55, size.height * 0.3);
    mountainPath.lineTo(size.width * 0.75, size.height * 0.5);
    mountainPath.lineTo(size.width * 0.9, size.height * 0.35);
    mountainPath.lineTo(size.width, size.height * 0.55);
    mountainPath.lineTo(size.width, size.height);
    mountainPath.lineTo(0, size.height);
    mountainPath.close();
    canvas.drawPath(mountainPath, skeletonPaint);

    final sunPaint = Paint()..color = const Color(0xFFDEDEDE);
    canvas.drawCircle(Offset(size.width * 0.78, size.height * 0.18), size.width * 0.08, sunPaint);

    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Color(0x00FFFFFF),
        Color(0x33FFFFFF),
        Color(0x00FFFFFF),
      ],
      stops: const [0.0, 0.5, 1.0],
      transform: GradientTranslation(shimmerPos),
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final shimmerPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.srcOver;
    canvas.drawRect(rect, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant _ImageSkeletonPainter old) => old.shimmerPos != shimmerPos;
}

class GradientTranslation extends GradientTransform {
  final double pos;
  const GradientTranslation(this.pos);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * pos - bounds.width * 0.3, 0, 0);
  }
}

class _ImagePreviewScreen extends StatefulWidget {
  final String imageUrl;
  const _ImagePreviewScreen({required this.imageUrl});

  @override
  State<_ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<_ImagePreviewScreen> {
  void _showActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.download_outlined, color: Color(0xFF222222)),
              title: const Text('保存图片', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _saveImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Color(0xFF222222)),
              title: const Text('分享', style: TextStyle(fontSize: 16)),
              onTap: () => Navigator.pop(sheetCtx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveImage() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Container(
          color: Colors.black26,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xCC000000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(radius: 14, color: Colors.white),
                SizedBox(height: 12),
                Text('正在保存...', style: TextStyle(fontSize: 14, color: Colors.white, decoration: TextDecoration.none)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/ai_image_${DateTime.now().millisecondsSinceEpoch}.png';
      await Dio().download(widget.imageUrl, filePath);
      await Gal.putImage(filePath, album: '留笔AI');
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, message: '保存成功');
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.error(context, message: '保存失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.white, size: 24),
        ),
        actions: [
          GestureDetector(
            onTap: _showActionSheet,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.more_horiz, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onLongPress: _showActionSheet,
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(child: CupertinoActivityIndicator(radius: 14, color: Colors.white)),
              errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 60, color: Colors.white54)),
            ),
          ),
        ),
      ),
    );
  }
}
