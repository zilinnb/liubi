import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/app_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';
import '../utils/helpers.dart';

enum _BlockType { text, image, voice, link }

class _ContentBlock {
  _BlockType type;
  String text;
  List<String> imagePaths;
  List<String> existingUrls;
  String imageLayout;
  String? voicePath;
  int voiceDuration;
  String linkUrl;
  TextEditingController? _textCtrl;
  TextEditingController? _linkCtrl;

  _ContentBlock({required this.type, this.text = '', this.imagePaths = const [], this.existingUrls = const [], this.imageLayout = 'grid', this.voicePath, this.voiceDuration = 0, this.linkUrl = ''}) {
    if (type == _BlockType.text) _textCtrl = TextEditingController(text: text);
    if (type == _BlockType.link) _linkCtrl = TextEditingController(text: linkUrl);
  }

  TextEditingController get textCtrl {
    _textCtrl ??= TextEditingController(text: text);
    return _textCtrl!;
  }

  TextEditingController get linkCtrl {
    _linkCtrl ??= TextEditingController(text: linkUrl);
    return _linkCtrl!;
  }

  void dispose() {
    _textCtrl?.dispose();
    _linkCtrl?.dispose();
  }
}

class PublishScreen extends StatefulWidget {
  final int? initialCategoryId;
  const PublishScreen({super.key, this.initialCategoryId});
  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> with TickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  final List<_ContentBlock> _blocks = [_ContentBlock(type: _BlockType.text)];
  bool _publishing = false;
  int? _editingPostId;

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  int? _recordingBlockIdx;
  AudioPlayer? _previewPlayer;
  int _playingVoiceIdx = -1;
  bool _voiceLoading = false;

  late AnimationController _overlayCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  _OverlayType _currentOverlay = _OverlayType.none;

  final FocusNode _titleFocus = FocusNode();
  final FocusNode _textFocus = FocusNode();
  final _linkCtrl = TextEditingController();

  bool get _canPublish => _titleCtrl.text.trim().isNotEmpty && _selectedCategoryId != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() => setState(() {}));
    _overlayCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: _overlayCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _overlayCtrl, curve: Curves.easeOut));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pp = Provider.of<PostProvider>(context, listen: false);
      if (pp.categories.isEmpty) pp.fetchCategories();

      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      if (routeArgs is Post) {
        _editingPostId = routeArgs.id;
        _titleCtrl.text = routeArgs.title;
        final cat = pp.categories.where((c) => c.id == routeArgs.categoryId).firstOrNull;
        if (cat != null) {
          _selectedCategoryId = cat.id.toString();
          _selectedCategoryName = cat.name;
        } else {
          _selectedCategoryId = routeArgs.categoryId.toString();
          _selectedCategoryName = routeArgs.categoryName;
        }
        if (routeArgs.contentBlocks.isNotEmpty) {
          _blocks.clear();
          for (final cb in routeArgs.contentBlocks) {
            if (cb.type == 'text') {
              _blocks.add(_ContentBlock(type: _BlockType.text, text: cb.content));
            } else if (cb.type == 'image' || cb.type == 'images') {
              final urls = cb.images.map((e) => e['url'] as String? ?? '').where((u) => u.isNotEmpty).toList();
              _blocks.add(_ContentBlock(type: _BlockType.image, existingUrls: urls, imageLayout: cb.layout.isNotEmpty ? cb.layout : 'grid'));
            } else if (cb.type == 'voice') {
              _blocks.add(_ContentBlock(type: _BlockType.voice, voicePath: cb.url, voiceDuration: cb.duration, existingUrls: cb.url.isNotEmpty ? [cb.url] : []));
            } else if (cb.type == 'link') {
              _blocks.add(_ContentBlock(type: _BlockType.link, linkUrl: cb.url));
            }
          }
        } else {
          if (routeArgs.content.isNotEmpty) {
            _blocks[0].text = routeArgs.content;
            _blocks[0].textCtrl.text = routeArgs.content;
          }
          if (routeArgs.images.isNotEmpty) {
            final urls = routeArgs.images.map((e) => e.url).where((u) => u.isNotEmpty).toList();
            if (urls.isNotEmpty) {
              if (_blocks.length == 1 && _blocks[0].text.isEmpty) {
                _blocks[0] = _ContentBlock(type: _BlockType.image, existingUrls: urls, imageLayout: 'grid');
              } else {
                _blocks.add(_ContentBlock(type: _BlockType.image, existingUrls: urls, imageLayout: 'grid'));
              }
            }
          }
          if (routeArgs.voiceUrl.isNotEmpty) {
            _blocks.add(_ContentBlock(type: _BlockType.voice, voicePath: routeArgs.voiceUrl, voiceDuration: routeArgs.voiceDuration));
          }
          if (routeArgs.link.isNotEmpty) {
            _blocks.add(_ContentBlock(type: _BlockType.link, linkUrl: routeArgs.link));
          }
        }
        if (_blocks.isEmpty) _blocks.add(_ContentBlock(type: _BlockType.text));
        setState(() {});
        return;
      }

      if (widget.initialCategoryId != null) {
        final cat = pp.categories.where((c) => c.id == widget.initialCategoryId).firstOrNull;
        if (cat != null) {
          setState(() {
            _selectedCategoryId = cat.id.toString();
            _selectedCategoryName = cat.name;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _linkCtrl.dispose();
    _titleFocus.dispose();
    _textFocus.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    _previewPlayer?.dispose();
    _overlayCtrl.dispose();
    for (final b in _blocks) b.dispose();
    super.dispose();
  }

  void _openOverlay(_OverlayType type) {
    FocusScope.of(context).unfocus();
    setState(() => _currentOverlay = type);
    _overlayCtrl.forward();
  }

  void _closeOverlay() {
    _overlayCtrl.reverse().then((_) {
      if (mounted) setState(() => _currentOverlay = _OverlayType.none);
    });
  }

  void _addTextBlock() {
    setState(() => _blocks.add(_ContentBlock(type: _BlockType.text)));
    Future.delayed(const Duration(milliseconds: 100), () => _textFocus.requestFocus());
  }

  void _addImageBlock() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    setState(() {
      _blocks.add(_ContentBlock(type: _BlockType.image, imagePaths: images.map((e) => e.path).toList(), imageLayout: images.length == 1 ? 'full' : 'grid'));
      _blocks.add(_ContentBlock(type: _BlockType.text));
    });
  }

  void _addVoiceBlock() {
    _openOverlay(_OverlayType.voice);
  }

  void _addLinkBlock() {
    _openOverlay(_OverlayType.link);
  }

  Future<void> _previewVoice(int idx, String path) async {
    if (_playingVoiceIdx == idx) {
      await _previewPlayer?.stop();
      setState(() { _playingVoiceIdx = -1; _voiceLoading = false; });
      return;
    }
    await _previewPlayer?.stop();
    _previewPlayer?.dispose();
    _previewPlayer = AudioPlayer();
    setState(() { _playingVoiceIdx = idx; _voiceLoading = true; });
    try {
      if (path.startsWith('http')) {
        await _previewPlayer!.play(UrlSource(path));
      } else {
        await _previewPlayer!.play(DeviceFileSource(path));
      }
      if (mounted) setState(() { _voiceLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _playingVoiceIdx = -1; _voiceLoading = false; });
      return;
    }
    _previewPlayer!.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playingVoiceIdx = -1; _voiceLoading = false; });
    });
  }

  void _removeBlock(int idx) {
    if (_blocks.length <= 1 && _blocks[0].type == _BlockType.text) return;
    setState(() => _blocks.removeAt(idx));
  }

  void _moveBlock(int from, int to) {
    if (to < 0 || to >= _blocks.length) return;
    setState(() {
      final b = _blocks.removeAt(from);
      _blocks.insert(to, b);
    });
  }

  Future<void> _startRecording(int blockIdx) async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      AppToast.error(context, message: '需要麦克风权限才能录制');
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_record_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() { _isRecording = true; _recordSeconds = 0; _recordingBlockIdx = blockIdx; });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      AppToast.error(context, message: '录制失败: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    try {
      final path = await _recorder.stop();
      if (path != null && _recordingBlockIdx != null) {
        setState(() {
          _blocks[_recordingBlockIdx!].voicePath = path;
          _blocks[_recordingBlockIdx!].voiceDuration = _recordSeconds;
        });
      }
    } catch (_) {}
    setState(() { _isRecording = false; _recordSeconds = 0; _recordingBlockIdx = null; });
  }

  Future<void> _pickAudioFile(int blockIdx) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _blocks[blockIdx].voicePath = result.files.single.path;
        _blocks[blockIdx].voiceDuration = 0;
      });
    }
  }

  Future<void> _doPublish() async {
    if (_publishing) return;
    setState(() => _publishing = true);

    final pp = Provider.of<PostProvider>(context, listen: false);
    final contentBlocks = <Map<String, dynamic>>[];
    final allImgUrls = <String>[];
    String? voiceUrl;
    int? voiceDur;
    String? linkUrl;

    for (final b in _blocks) {
      if (b.type == _BlockType.text && b.text.trim().isNotEmpty) {
        contentBlocks.add({'type': 'text', 'content': b.text.trim()});
      } else if (b.type == _BlockType.image) {
        final urls = <String>[];
        urls.addAll(b.existingUrls);
        for (final p in b.imagePaths) {
          final url = await pp.uploadFile(p);
          if (url != null) urls.add(url);
        }
        allImgUrls.addAll(urls);
        contentBlocks.add({'type': 'images', 'images': urls.map((u) => {'url': u, 'type': 'image'}).toList(), 'layout': b.imageLayout});
      } else if (b.type == _BlockType.voice && b.voicePath != null) {
        if (b.voicePath!.startsWith('http') || b.voicePath!.startsWith('/')) {
          voiceUrl = b.voicePath;
        } else {
          final url = await pp.uploadFile(b.voicePath!);
          if (url != null) voiceUrl = url;
        }
        voiceDur = b.voiceDuration;
        contentBlocks.add({'type': 'voice', 'url': voiceUrl ?? '', 'duration': b.voiceDuration});
      } else if (b.type == _BlockType.link && b.linkUrl.isNotEmpty) {
        linkUrl = b.linkUrl;
        contentBlocks.add({'type': 'link', 'url': b.linkUrl});
      }
    }

    int postType = 0;
    if (allImgUrls.isEmpty && voiceUrl == null) {
      postType = 1;
    } else if (voiceUrl != null) {
      postType = 2;
    }

    final imagesData = allImgUrls.map((u) => {'url': u, 'type': 'image'}).toList();

    final data = {
      'title': _titleCtrl.text.trim(),
      'content': _blocks.where((b) => b.type == _BlockType.text).map((b) => b.text.trim()).join('\n'),
      'category_id': _selectedCategoryId,
      'post_type': postType,
      if (postType == 1) 'text_template': 0,
      'content_blocks': contentBlocks,
      if (imagesData.isNotEmpty) 'images': imagesData,
      if (voiceUrl != null) 'voice_url': voiceUrl,
      if (voiceDur != null) 'voice_duration': voiceDur,
      if (linkUrl != null) 'link': linkUrl,
    };

    Map<String, dynamic> res;
    if (_editingPostId != null) {
      res = await pp.updatePost(_editingPostId!, data);
    } else {
      res = await pp.createPost(data);
    }
    setState(() => _publishing = false);

    if (res['code'] == 200) {
      if (mounted) {
        AppToast.success(context, message: _editingPostId != null ? '编辑成功' : '发布成功');
        pp.fetchPosts(refresh: true);
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        AppToast.error(context, message: res['msg'] ?? '操作失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Column(children: [
              _buildNav(),
              Expanded(child: _buildBody()),
              _buildKeyboardToolbar(),
            ]),
            if (_currentOverlay != _OverlayType.none) _buildOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildNav() {
    return Container(
      height: 44,
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5))),
      child: Row(children: [
        GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: 56, height: 44, alignment: Alignment.center, child: const Icon(Icons.close, size: 22, color: Color(0xFF333333)))),
        const Expanded(child: Center(child: Text('发布笔记', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222))))),
        GestureDetector(
          onTap: _canPublish && !_publishing ? _doPublish : null,
          child: Container(width: 56, height: 44, alignment: Alignment.center, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: _canPublish ? const Color(0xFFFF2442) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)),
            child: Text(_editingPostId != null ? '保存' : '发布', style: TextStyle(fontSize: 13, color: _canPublish ? Colors.white : const Color(0xFF999999), fontWeight: _canPublish ? FontWeight.w600 : FontWeight.w400)),
          )),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildTitleField(),
        _buildTopicRow(),
        const Divider(height: 1, indent: 14, endIndent: 14, color: Color(0xFFF5F5F5)),
        for (int i = 0; i < _blocks.length; i++) _buildBlock(i),
      ]),
    );
  }

  Widget _buildTitleField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: TextField(
        controller: _titleCtrl, focusNode: _titleFocus, maxLength: 50,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
        decoration: const InputDecoration(hintText: '填写标题会有更多赞哦～', hintStyle: TextStyle(fontSize: 17, color: Color(0xFFCCCCCC)), border: InputBorder.none, counterText: '', contentPadding: EdgeInsets.zero),
      ),
    );
  }

  Widget _buildTopicRow() {
    return GestureDetector(
      onTap: () => _openOverlay(_OverlayType.topic),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          const Text('#', style: TextStyle(fontSize: 16, color: Color(0xFFFF2442), fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text(_selectedCategoryName ?? '选择话题', style: TextStyle(fontSize: 14, color: _selectedCategoryName != null ? const Color(0xFFFF2442) : const Color(0xFFCCCCCC), fontWeight: _selectedCategoryName != null ? FontWeight.w500 : FontWeight.w400)),
        ]),
      ),
    );
  }

  Widget _buildBlock(int idx) {
    final b = _blocks[idx];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Padding(padding: const EdgeInsets.only(left: 8, top: 6), child: Text(_blockLabel(b.type), style: const TextStyle(fontSize: 10, color: Color(0xFF999999), fontWeight: FontWeight.w500))),
          const Spacer(),
          if (idx > 0) GestureDetector(onTap: () => _moveBlock(idx, idx - 1), child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.keyboard_arrow_up, size: 16, color: Color(0xFFCCCCCC)))),
          if (idx < _blocks.length - 1) GestureDetector(onTap: () => _moveBlock(idx, idx + 1), child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFFCCCCCC)))),
          if (_blocks.length > 1) GestureDetector(onTap: () => _removeBlock(idx), child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, size: 14, color: Color(0xFFCCCCCC)))),
        ]),
        _buildBlockContent(idx, b),
        const SizedBox(height: 6),
      ]),
    );
  }

  String _blockLabel(_BlockType t) {
    switch (t) {
      case _BlockType.text: return '文字';
      case _BlockType.image: return '图片';
      case _BlockType.voice: return '音频';
      case _BlockType.link: return '链接';
    }
  }

  Widget _buildBlockContent(int idx, _ContentBlock b) {
    switch (b.type) {
      case _BlockType.text: return _buildTextBlock(idx, b);
      case _BlockType.image: return _buildImageBlock(idx, b);
      case _BlockType.voice: return _buildVoiceBlock(idx, b);
      case _BlockType.link: return _buildLinkBlock(idx, b);
    }
  }

  Widget _buildTextBlock(int idx, _ContentBlock b) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: b.textCtrl,
        focusNode: idx == _blocks.length - 1 ? _textFocus : null,
        onChanged: (v) => b.text = v,
        maxLines: null, minLines: 2,
        style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.8),
        decoration: const InputDecoration(hintText: '添加正文', hintStyle: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)), border: InputBorder.none, contentPadding: EdgeInsets.zero),
      ),
    );
  }

  Widget _buildImageBlock(int idx, _ContentBlock b) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('布局', style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
          const SizedBox(width: 6),
          _buildLayoutOpt(idx, 'grid', '九宫格'),
          const SizedBox(width: 4),
          _buildLayoutOpt(idx, 'double', '双列'),
          const SizedBox(width: 4),
          _buildLayoutOpt(idx, 'stack', '折叠'),
          const SizedBox(width: 4),
          _buildLayoutOpt(idx, 'full', '全宽'),
        ]),
        const SizedBox(height: 6),
        _renderImageLayout(idx, b),
      ]),
    );
  }

  Widget _buildLayoutOpt(int idx, String layout, String label) {
    final isOn = _blocks[idx].imageLayout == layout;
    return GestureDetector(
      onTap: () => setState(() => _blocks[idx].imageLayout = layout),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: isOn ? const Color(0xFFFFF0F0) : const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6), border: isOn ? Border.all(color: const Color(0xFFFF2442), width: 0.5) : null),
        child: Text(label, style: TextStyle(fontSize: 10, color: isOn ? const Color(0xFFFF2442) : const Color(0xFF999999))),
      ),
    );
  }

  Widget _imgPreview(String src, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (src.startsWith('http')) {
      return CachedNetworkImage(imageUrl: src, width: width, height: height, fit: fit, placeholder: (ctx, url) => Container(color: const Color(0xFFF5F5F5)), errorWidget: (ctx, url, err) => Container(color: const Color(0xFFF5F5F5), child: const Icon(Icons.broken_image, color: Color(0xFFCCCCCC))));
    }
    if (src.startsWith('/')) {
      return CachedNetworkImage(imageUrl: fullUrl(src), width: width, height: height, fit: fit, placeholder: (ctx, url) => Container(color: const Color(0xFFF5F5F5)), errorWidget: (ctx, url, err) => Container(color: const Color(0xFFF5F5F5), child: const Icon(Icons.broken_image, color: Color(0xFFCCCCCC))));
    }
    return Image.file(File(src), fit: fit);
  }

  Widget _imgStack(String src, Widget image, {VoidCallback? onRemove}) {
    return Stack(children: [
      ClipRRect(borderRadius: BorderRadius.circular(4), child: image),
      if (onRemove != null) Positioned(top: 2, right: 2, child: GestureDetector(onTap: onRemove, child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: Color(0x8C000000), shape: BoxShape.circle), child: const Icon(Icons.close, size: 10, color: Colors.white)))),
    ]);
  }

  Widget _renderImageLayout(int idx, _ContentBlock b) {
    final entries = <_ImgSrc>[
      for (final url in b.existingUrls) _ImgSrc(url, true, () => setState(() => b.existingUrls.remove(url))),
      for (final e in b.imagePaths.asMap().entries) _ImgSrc(e.value, false, () => setState(() => b.imagePaths.removeAt(e.key))),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    if (b.imageLayout == 'full') {
      return Column(children: entries.map((e) => _imgStack(e.src, _imgPreview(e.src, width: double.infinity), onRemove: e.onRemove)).toList());
    }
    if (b.imageLayout == 'double') {
      return Wrap(spacing: 3, runSpacing: 3, children: entries.map((e) => SizedBox(
        width: (MediaQuery.of(context).size.width - 44) / 2 - 4,
        child: AspectRatio(aspectRatio: 1, child: _imgStack(e.src, _imgPreview(e.src, fit: BoxFit.cover), onRemove: e.onRemove)),
      )).toList());
    }
    if (b.imageLayout == 'stack') {
      return SizedBox(height: 220, child: Stack(children: [
        for (int i = entries.length - 1; i >= 0; i--)
          AnimatedPositioned(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic, left: i * 8.0, top: i * 6.0, right: (entries.length - 1 - i) * 8.0, bottom: (entries.length - 1 - i) * 6.0, child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _imgPreview(entries[i].src, fit: BoxFit.cover)))),
      ]));
    }
    final s = (MediaQuery.of(context).size.width - 44) / 3;
    return Wrap(spacing: 3, runSpacing: 3, children: entries.map((e) => SizedBox(
      width: s, height: s,
      child: _imgStack(e.src, _imgPreview(e.src, fit: BoxFit.cover), onRemove: e.onRemove),
    )).toList());
  }

  Widget _buildVoiceBlock(int idx, _ContentBlock b) {
    if (_isRecording && _recordingBlockIdx == idx) {
      return Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(16, (i) {
            final h = (6.0 + (i * 11.0 + i * i * 7.0) % 18.0).clamp(4.0, 24.0);
            return AnimatedContainer(duration: Duration(milliseconds: 200 + (i % 3) * 80), margin: const EdgeInsets.symmetric(horizontal: 1.5), width: 3, height: h, decoration: BoxDecoration(color: const Color(0xFFFF2442).withValues(alpha: 0.7), borderRadius: BorderRadius.circular(1.5)));
          })),
          const SizedBox(height: 10),
          Text(fmtVoiceTime(_recordSeconds), style: const TextStyle(fontSize: 24, color: Color(0xFFFF2442), fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 8),
          GestureDetector(onTap: _stopRecording, child: Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFFF2442), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFFFF2442).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))]), child: const Icon(Icons.stop, color: Colors.white, size: 24))),
        ]),
      );
    }
    if (b.voicePath != null) {
      final isPlaying = _playingVoiceIdx == idx;
      final isLoading = isPlaying && _voiceLoading;
      return GestureDetector(
        onTap: () => _previewVoice(idx, b.voicePath!),
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Container(width: 28, height: 28, decoration: const BoxDecoration(color: Color(0xFFFF2442), shape: BoxShape.circle), child: Center(child: isLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : (isPlaying ? const Icon(Icons.pause, color: Colors.white, size: 14) : const Icon(Icons.play_arrow, color: Colors.white, size: 14)))),
            const SizedBox(width: 8),
            Expanded(child: Text(b.voicePath!.split(Platform.pathSeparator).last, style: const TextStyle(fontSize: 12, color: Color(0xFF333333)), overflow: TextOverflow.ellipsis)),
            if (b.voiceDuration > 0) Text(fmtVoiceTime(b.voiceDuration), style: const TextStyle(fontSize: 11, color: Color(0xFFFF2442), fontWeight: FontWeight.w600)),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => _pickAudioFile(idx),
          child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: const Color(0xFFE6F7FF), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('上传音频文件', style: TextStyle(fontSize: 13, color: Color(0xFF1890FF))))),
        )),
        const SizedBox(width: 8),
        Expanded(child: GestureDetector(
          onTap: () => _startRecording(idx),
          child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('录制音频', style: TextStyle(fontSize: 13, color: Color(0xFFFF2442))))),
        )),
      ]),
    );
  }

  Widget _buildLinkBlock(int idx, _ContentBlock b) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: b.linkCtrl,
        onChanged: (v) => b.linkUrl = v,
        style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
        decoration: InputDecoration(
          hintText: '输入链接地址', hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCCCCCC)),
          filled: true, fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          prefixIcon: const Icon(Icons.link, size: 16, color: Color(0xFF999999)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildKeyboardToolbar() {
    return Container(
      height: 44,
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF0F0F0), width: 0.5))),
      child: Row(children: [
        const SizedBox(width: 12),
        _buildToolBtn(Icons.image_outlined, const Color(0xFFE6F7FF), const Color(0xFF1890FF), _addImageBlock),
        const SizedBox(width: 10),
        _buildToolBtn(Icons.mic_outlined, const Color(0xFFFFF0F0), const Color(0xFFFF2442), _addVoiceBlock),
        const Spacer(),
        _buildToolBtn(Icons.link_outlined, const Color(0xFFF0F5FF), const Color(0xFF1890FF), _addLinkBlock),
        const SizedBox(width: 12),
      ]),
    );
  }

  Widget _buildToolBtn(IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 32, height: 32, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Center(child: Icon(icon, size: 16, color: fg))),
    );
  }

  Widget _buildOverlay() {
    return GestureDetector(
      onTap: _closeOverlay,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(color: Colors.black.withValues(alpha: 0.4), child: GestureDetector(onTap: () {}, child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [SlideTransition(position: _slideAnim, child: _currentOverlay == _OverlayType.topic ? _buildTopicSheet() : _currentOverlay == _OverlayType.voice ? _buildVoiceSheet() : _buildLinkSheet())]))),
      ),
    );
  }

  Widget _buildTopicSheet() {
    final pp = Provider.of<PostProvider>(context, listen: true);
    final isAdmin = Provider.of<UserProvider>(context, listen: false).userInfo?.role == 1;
    final visibleCats = pp.categories.where((c) => c.publishRestriction != 1 || isAdmin).toList();
    return Container(
      width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 32, height: 4, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('选择话题', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: visibleCats.map((c) {
          final isOn = _selectedCategoryId == c.id.toString();
          return GestureDetector(
            onTap: () { setState(() { _selectedCategoryId = c.id.toString(); _selectedCategoryName = c.name; }); _closeOverlay(); },
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), curve: Curves.easeOut, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: isOn ? const Color(0xFFFFF0F0) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16), border: isOn ? Border.all(color: const Color(0xFFFF2442), width: 0.5) : null), child: Text(c.name, style: TextStyle(fontSize: 13, color: isOn ? const Color(0xFFFF2442) : const Color(0xFF666666)))),
          );
        }).toList()),
        const SizedBox(height: 16),
        GestureDetector(onTap: _closeOverlay, child: Container(width: double.infinity, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('取消', style: TextStyle(fontSize: 15, color: Color(0xFF999999)))))),
      ]),
    );
  }

  Widget _buildVoiceSheet() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 32, height: 4, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('添加音频', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () { _closeOverlay(); Future.delayed(const Duration(milliseconds: 350), () { if (mounted) { setState(() { _blocks.add(_ContentBlock(type: _BlockType.voice)); _pickAudioFile(_blocks.length - 2); }); } }); },
            child: Container(padding: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(color: const Color(0xFFE6F7FF), borderRadius: BorderRadius.circular(12)), child: const Column(children: [Icon(Icons.upload_file, color: Color(0xFF1890FF), size: 28), SizedBox(height: 6), Text('上传音频', style: TextStyle(fontSize: 13, color: Color(0xFF1890FF)))])),
          )),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: () { _closeOverlay(); Future.delayed(const Duration(milliseconds: 350), () { if (mounted) { setState(() { _blocks.add(_ContentBlock(type: _BlockType.voice)); _startRecording(_blocks.length - 2); }); } }); },
            child: Container(padding: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(12)), child: const Column(children: [Icon(Icons.mic, color: Color(0xFFFF2442), size: 28), SizedBox(height: 6), Text('录制音频', style: TextStyle(fontSize: 13, color: Color(0xFFFF2442)))])),
          )),
        ]),
        const SizedBox(height: 16),
        GestureDetector(onTap: _closeOverlay, child: Container(width: double.infinity, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('取消', style: TextStyle(fontSize: 15, color: Color(0xFF999999)))))),
      ]),
    );
  }

  Widget _buildLinkSheet() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 32, height: 4, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('添加链接', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
        const SizedBox(height: 16),
        TextField(controller: _linkCtrl, decoration: InputDecoration(hintText: '输入链接地址', hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)), filled: true, fillColor: const Color(0xFFF5F5F5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), style: const TextStyle(fontSize: 14, color: Color(0xFF222222))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GestureDetector(onTap: _closeOverlay, child: Container(height: 40, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('取消', style: TextStyle(fontSize: 14, color: Color(0xFF999999))))))),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(onTap: () { setState(() { _blocks.add(_ContentBlock(type: _BlockType.link, linkUrl: _linkCtrl.text.trim())); _blocks.add(_ContentBlock(type: _BlockType.text)); }); _linkCtrl.clear(); _closeOverlay(); Future.delayed(const Duration(milliseconds: 400), () { if (mounted) _textFocus.requestFocus(); }); }, child: Container(height: 40, decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('确定', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)))))),
        ]),
      ]),
    );
  }
}

class _ImgSrc {
  final String src;
  final bool isRemote;
  final VoidCallback onRemove;
  _ImgSrc(this.src, this.isRemote, this.onRemove);
}

enum _OverlayType { none, topic, voice, link }
