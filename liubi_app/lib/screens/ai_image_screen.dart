import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';
import 'image_viewer_screen.dart';

class _ImageItem {
  int? id;
  final String prompt;
  String? imageUrl;
  bool isFailed;
  String? errorMsg;
  _ImageItem({this.id, required this.prompt, this.imageUrl, this.isFailed = false, this.errorMsg});
  /// 是否正在生成中：由全局 _generatingPrompts 决定
  bool get isGenerating => _generatingPrompts.contains(prompt);
}

// 静态持久化：跨页面实例保留生成中的项目
final List<_ImageItem> _persistentItems = [];
// 全局追踪正在生成中的 prompt（独立于 item 对象，不受 Future 修改影响）
final Set<String> _generatingPrompts = {};

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
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _shimmerCtrl.repeat();
    _inputCtrl.addListener(() => setState(() {}));

    // 立即显示持久化中的生成中项目，不等历史加载
    _items = List.from(_persistentItems);

    _loadHistory();

    // 如果有生成中的项目，启动轮询刷新UI
    if (_generatingPrompts.isNotEmpty) {
      _startPolling();
    }
  }

  /// 轮询：定期请求后端检查生成状态
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) { _pollTimer?.cancel(); return; }

      if (_generatingPrompts.isNotEmpty) {
        // 请求后端检查生成状态
        try {
          final res = await ApiService().get('/ai/image/history?limit=50');
          if (res['code'] == 200 && mounted) {
            final list = res['data'] as List? ?? [];
            for (final e in list) {
              final status = e['status'] as String? ?? 'completed';
              final prompt = e['prompt'] as String? ?? '';
              if (status == 'completed' && _generatingPrompts.contains(prompt)) {
                // 这个项目完成了！更新对应的 item
                _generatingPrompts.remove(prompt);
                final item = _items.where((i) => i.prompt == prompt && i.isGenerating).firstOrNull;
                if (item != null) {
                  item.id = e['id'] as int?;
                  item.imageUrl = e['image_url'] as String? ?? '';
                  item.isFailed = false;
                }
                // 也从持久化列表中更新
                final pItem = _persistentItems.where((i) => i.prompt == prompt).firstOrNull;
                if (pItem != null) {
                  pItem.id = e['id'] as int?;
                  pItem.imageUrl = e['image_url'] as String? ?? '';
                  pItem.isFailed = false;
                }
              } else if (status == 'failed' && _generatingPrompts.contains(prompt)) {
                _generatingPrompts.remove(prompt);
                final item = _items.where((i) => i.prompt == prompt && i.isGenerating).firstOrNull;
                if (item != null) {
                  item.isFailed = true;
                  item.errorMsg = '生成失败';
                }
              }
            }
            setState(() {});
          }
        } catch (_) {}

        // 清理已完成的持久化项目
        _persistentItems.removeWhere((e) =>
          !e.isGenerating && !e.isFailed && e.imageUrl != null && e.imageUrl!.isNotEmpty && e.id != null);
      } else {
        _pollTimer?.cancel();
        if (mounted) setState(() {});
      }
    });
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
    _pollTimer?.cancel();
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
        final historyItems = list.map((e) {
          final status = e['status'] as String? ?? 'completed';
          final prompt = e['prompt'] as String? ?? '';
          // 后端返回 generating 状态的，加入全局追踪
          if (status == 'generating') {
            _generatingPrompts.add(prompt);
          }
          return _ImageItem(
            id: e['id'] as int?,
            prompt: prompt,
            imageUrl: (status == 'completed') ? (e['image_url'] as String? ?? '') : null,
            isFailed: status == 'failed',
          );
        }).toList().reversed.toList();

        // 持久化项目的prompt和id集合（生成中/失败的，优先显示）
        final persistentPrompts = _persistentItems.map((e) => e.prompt).toSet();
        final persistentIds = _persistentItems.where((e) => e.id != null).map((e) => e.id).toSet();

        // 过滤掉与持久化项目重叠的历史记录
        final filteredHistory = historyItems.where((h) {
          if (h.id != null && persistentIds.contains(h.id)) return false;
          if (persistentPrompts.contains(h.prompt)) return false;
          return true;
        }).toList();

        // 始终以 _persistentItems 为基础重建 _items
        setState(() {
          _items = [..._persistentItems, ...filteredHistory];
        });

        // 如果有生成中的项目，启动轮询
        if (_generatingPrompts.isNotEmpty) {
          _startPolling();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {}
  }

  Future<void> _generateImage() async {
    final prompt = _inputCtrl.text.trim();
    if (prompt.isEmpty) return;

    _inputCtrl.clear();
    _dismissKeyboard();

    final item = _ImageItem(prompt: prompt);
    _persistentItems.add(item);
    _generatingPrompts.add(prompt); // 标记为生成中
    setState(() => _items.add(item));
    _scrollToBottom();

    // 确保轮询已启动
    _startPolling();

    try {
      final res = await ApiService().post('/ai/image/generate', data: {'prompt': prompt}, noTimeout: true);
      if (res['code'] == 200) {
        final data = res['data'];
        item.id = data['id'] as int?;
        item.imageUrl = data['image_url'] as String? ?? '';
        _generatingPrompts.remove(prompt); // 生成完成，移除标记
        if (mounted) setState(() {});
      } else {
        _generatingPrompts.remove(prompt);
        item.isFailed = true;
        item.errorMsg = res['msg'] ?? '生成失败';
        if (mounted) {
          setState(() {});
          AppToast.error(context, message: res['msg'] ?? '生成失败');
        }
      }
    } on DioException catch (e) {
      debugPrint('[AI绘画] 请求异常: type=${e.type}, msg=${e.message}');
      _generatingPrompts.remove(prompt);
      item.isFailed = true;
      item.errorMsg = e.type == DioExceptionType.connectionError ? '网络连接失败' : '请求异常';
      if (mounted) {
        setState(() {});
        AppToast.error(context, message: item.errorMsg!);
      }
    } catch (e) {
      debugPrint('[AI绘画] 未知异常: $e');
      _generatingPrompts.remove(prompt);
      item.isFailed = true;
      item.errorMsg = '生成失败';
      if (mounted) {
        setState(() {});
        AppToast.error(context, message: '生成失败');
      }
    }
    if (mounted) _scrollToBottom();
  }

  Future<void> _retryGenerate(_ImageItem item) async {
    _generatingPrompts.add(item.prompt); // 标记为生成中
    setState(() {
      item.isFailed = false;
      item.errorMsg = null;
      item.imageUrl = null;
    });
    _scrollToBottom();
    _startPolling();

    try {
      final res = await ApiService().post('/ai/image/generate', data: {'prompt': item.prompt}, noTimeout: true);
      if (res['code'] == 200) {
        final data = res['data'];
        item.id = data['id'] as int?;
        item.imageUrl = data['image_url'] as String? ?? '';
        _generatingPrompts.remove(item.prompt);
        if (mounted) setState(() {});
      } else {
        _generatingPrompts.remove(item.prompt);
        item.isFailed = true;
        item.errorMsg = res['msg'] ?? '生成失败';
        if (mounted) setState(() {});
      }
    } on DioException catch (e) {
      debugPrint('[AI绘画] 重试异常: type=${e.type}, msg=${e.message}');
      _generatingPrompts.remove(item.prompt);
      item.isFailed = true;
      item.errorMsg = e.type == DioExceptionType.connectionError ? '网络连接失败' : '请求异常';
      if (mounted) setState(() {});
    }
    if (mounted) _scrollToBottom();
  }

  Future<void> _deleteItem(_ImageItem item) async {
    if (item.id != null) {
      try { await ApiService().delete('/ai/image/${item.id}'); } catch (_) {}
    }
    _persistentItems.remove(item);
    setState(() => _items.remove(item));
  }

  String _getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return 'https://liu.bi$url';
  }

  void _previewImage(String url) {
    _dismissKeyboard();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImageViewerScreen(urls: [_getImageUrl(url)]),
    ));
  }

  Future<void> _saveImage(String url) async {
    final fullUrl = _getImageUrl(url);
    if (fullUrl.isEmpty) return;
    await _doSaveImage(context, fullUrl);
  }

  Future<void> _shareImage(String url) async {
    final fullUrl = _getImageUrl(url);
    if (fullUrl.isEmpty) return;

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442))),
    );

    try {
      final response = await Dio().get(fullUrl, options: Options(responseType: ResponseType.bytes));
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/liubi_share_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.data);
      if (mounted) {
        Navigator.of(context).pop(); // 关闭loading
        await Share.shareXFiles([XFile(file.path)], text: '来自liubi AI绘画');
        // 分享完成后删除临时文件
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭loading
        AppToast.error(context, message: '分享失败');
      }
    }
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
      await Gal.putImage(filePath, album: 'liubiai');
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, __) {
            return CustomPaint(
              painter: _DoubaoGenPainter(t: _shimmerCtrl.value),
            );
          },
        ),
      ),
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
            _buildActionBtn(Icons.share_outlined, () => _shareImage(item.imageUrl!)),
            const Spacer(),
            _buildActionBtn(Icons.refresh, () => _showConfirmDialog('重新生成', '确定要重新生成这张图片吗？', () => _retryGenerate(item))),
            _buildActionBtn(Icons.delete_outline, () => _showConfirmDialog('删除图片', '确定要删除这张图片吗？删除后不可恢复。', () => _deleteItem(item)), color: const Color(0xFFBBBBBB)),
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

  /// 小红书风格确认弹窗（与退出登录弹窗一致）
  void _showConfirmDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(22)),
                        alignment: Alignment.center,
                        child: const Text('取消', style: TextStyle(fontSize: 15, color: Color(0xFF666666), fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Text(title == '删除图片' ? '删除' : '确定',
                          style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

/// 豆包风格AI绘画生成动画（超细节版）
/// 1. 浅米色渐变底+微弱呼吸缩放
/// 2. 顶部文字「正在为你生成画面」+ 三点滚动省略号
/// 3. 横向渐变流光条
/// 4. 细碎飘散白色光点粒子
/// 5. 中心双层同心圆波纹扩散
/// 6. 圆角虚化柔光边
class _DoubaoGenPainter extends CustomPainter {
  final double t; // 0.0~1.0 循环
  _DoubaoGenPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width; // 以宽度为基准

    // ═══ 1. 浅米色渐变底 + 微弱呼吸缩放 ═══
    final breathScale = 1.0 + 0.02 * sin(t * 2 * pi); // 0.98→1.02
    final bgRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: size.width * breathScale,
      height: size.height * breathScale,
    );
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFFF8F6F3), Color(0xFFF2F0ED), Color(0xFFEDEAE6)],
      ).createShader(bgRect);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // ═══ 2. 圆角虚化柔光边（内阴影效果） ═══
    final edgePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.6,
        colors: const [
          Color(0x00000000),
          Color(0x00000000),
          Color(0x08C8C4BE),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), edgePaint);

    // ═══ 3. 中心双层同心圆波纹 ═══
    _drawRipple(canvas, cx, cy, s, t);

    // ═══ 4. 细碎飘散白色光点粒子 ═══
    _drawParticles(canvas, size, t);

    // ═══ 5. 横向渐变流光条 ═══
    _drawShimmerSweep(canvas, size, t);

    // ═══ 6. 顶部文字「正在为你生成画面」+ 三点滚动 ═══
    _drawText(canvas, cx, cy, s, t);
  }

  /// 双层同心圆波纹：由内向外缓慢扩散、透明消散
  void _drawRipple(Canvas canvas, double cx, double cy, double s, double t) {
    for (int i = 0; i < 2; i++) {
      final phase = (t + i * 0.5) % 1.0; // 两层错开
      final rippleRadius = s * 0.08 + phase * s * 0.22;
      final rippleAlpha = (1.0 - phase) * 0.12; // 扩散时透明度递减
      final ripplePaint = Paint()
        ..color = Color(0xFFB8B0A4).withValues(alpha: rippleAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(Offset(cx, cy - s * 0.04), rippleRadius, ripplePaint);
    }
  }

  /// 细碎飘散白色光点粒子
  void _drawParticles(Canvas canvas, Size size, double t) {
    final rng = _SeededRandom(42);
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 15; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final drift = sin(t * 2 * pi * speed + i * 1.7) * 8;
      final floatY = cos(t * 2 * pi * speed * 0.7 + i * 2.3) * 6;
      final px = baseX + drift;
      final py = baseY + floatY;
      // 透明度呼吸
      final alpha = 0.08 + 0.12 * sin(t * 2 * pi * speed + i * 0.9);
      particlePaint.color = const Color(0xFFFFFFFF).withValues(alpha: alpha.clamp(0.0, 1.0));
      final radius = 1.0 + rng.nextDouble() * 1.5;
      canvas.drawCircle(Offset(px, py), radius, particlePaint);
    }
  }

  /// 横向渐变流光条：半透奶白色柔光条，从左匀速滑到右
  void _drawShimmerSweep(Canvas canvas, Size size, double t) {
    final sweepX = -0.4 + (t * 1.5 % 1.0) * 1.8; // -0.4 → 1.4
    final sweepPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0x00FFFFFF),
          Color(0x1AFFFFFF), // 30%透明白
          Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: _GradientTranslation(sweepX),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..blendMode = BlendMode.srcOver;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sweepPaint);
  }

  /// 顶部文字 + 三点滚动省略号
  void _drawText(Canvas canvas, double cx, double cy, double s, double t) {
    // 文字微动浮动
    final textFloat = sin(t * 2 * pi * 0.8) * 1.5;
    final textY = cy + s * 0.02 + textFloat;

    // 主文字「正在为你生成画面」
    final mainText = TextSpan(
      text: '正在为你生成画面',
      style: TextStyle(
        fontSize: s * 0.042,
        color: const Color(0xFF8A8580),
        fontWeight: FontWeight.w400,
        letterSpacing: 1.2,
      ),
    );
    final mainPainter = TextPainter(text: mainText, textDirection: TextDirection.ltr)..layout();
    mainPainter.paint(canvas, Offset(cx - mainPainter.width / 2, textY - mainPainter.height / 2));

    // 三点滚动省略号：三个圆点依次亮起、淡出
    final dotY = textY + mainPainter.height / 2 + s * 0.025;
    final dotSpacing = s * 0.025;
    final dotRadius = s * 0.008;
    for (int i = 0; i < 3; i++) {
      final dotPhase = (t * 3 + i * 0.33) % 1.0; // 1秒一轮，依次亮起
      final dotAlpha = dotPhase < 0.5 ? dotPhase * 2 : (1.0 - dotPhase) * 2; // 0→1→0
      final dotPaint = Paint()
        ..color = Color(0xFF8A8580).withValues(alpha: dotAlpha.clamp(0.15, 1.0))
        ..style = PaintingStyle.fill;
      final dotX = cx - dotSpacing + i * dotSpacing;
      canvas.drawCircle(Offset(dotX, dotY), dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DoubaoGenPainter old) => old.t != t;
}

/// 确定性随机数生成器（用于粒子位置，避免每帧闪烁）
class _SeededRandom {
  int _state;
  _SeededRandom(int seed) : _state = seed;

  double nextDouble() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state / 0x7FFFFFFF;
  }
}

class _GradientTranslation extends GradientTransform {
  final double pos;
  const _GradientTranslation(this.pos);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * pos - bounds.width * 0.3, 0, 0);
  }
}


