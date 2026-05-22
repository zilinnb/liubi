import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../widgets/app_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/post.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';
import '../utils/helpers.dart';
import '../utils/image_picker_util.dart';
import '../utils/emoji_assets.dart';
import '../widgets/emoji_picker_panel.dart';
import 'package:extended_text_field/extended_text_field.dart';

class _EditorItem {
  String type;
  String text;
  List<String> imagePaths;
  List<Uint8List> imageThumbs;
  List<String> existingUrls;
  List<String> liveVideoPaths;
  List<String> existingLiveVideoUrls;
  String imageLayout;
  String? voicePath;
  int voiceDuration;
  String linkUrl;

  _EditorItem({
    required this.type,
    this.text = '',
    this.imagePaths = const [],
    this.imageThumbs = const [],
    this.existingUrls = const [],
    this.liveVideoPaths = const [],
    this.existingLiveVideoUrls = const [],
    this.imageLayout = 'grid',
    this.voicePath,
    this.voiceDuration = 0,
    this.linkUrl = '',
  });
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
  final List<_EditorItem> _items = [_EditorItem(type: 'text')];
  bool _publishing = false;
  int? _editingPostId;

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  int? _recordingItemIdx;
  AudioPlayer? _previewPlayer;
  int _playingVoiceIdx = -1;
  bool _voiceLoading = false;

  bool _showEmojiPanel = false;
  bool _emojiInserting = false;
  final FocusNode _titleFocus = FocusNode();
  final List<FocusNode> _textFocusNodes = [];
  int _currentTextIndex = 0;
  final Set<int> _expandedStacks = {};

  // 红包相关
  int? _redpacketId;
  int _redpacketCoins = 0;
  int _redpacketCount = 0;
  String _redpacketMessage = '恭喜发财';
  bool _hasRedpacket = false;

  VideoPlayerController? _livePhotoCtrl;
  bool _livePhotoPlaying = false;
  String? _livePhotoPath;

  final List<TextEditingController> _textControllers = [];

  bool get _canPublish => _titleCtrl.text.trim().isNotEmpty && _selectedCategoryId != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() => setState(() {}));
    _textControllers.add(EmojiTextEditingController());
    _textFocusNodes.add(FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pp = Provider.of<PostProvider>(context, listen: false);
      final up = Provider.of<UserProvider>(context, listen: false);
      // 每次进入发布页都重新获取分类列表和用户信息，确保等级限制等最新
      await pp.fetchCategories();
      if (up.isLoggedIn) await up.fetchProfile();

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
        _loadPostContent(routeArgs);
        return;
      }

      if (widget.initialCategoryId != null) {
        final cat = pp.categories.where((c) => c.id == widget.initialCategoryId).firstOrNull;
        if (cat != null) {
          // 检查等级限制（管理员跳过）
          final isAdmin = up.userInfo?.role == 1;
          final userLevel = up.userInfo?.levelInfo?.level ?? 1;
          if (!isAdmin && cat.minLevel > 0 && userLevel < cat.minLevel) {
            if (mounted) {
              AppToast.info(context, message: '需要到达Lv.${cat.minLevel}以后才能发布笔记');
            }
          } else {
            setState(() {
              _selectedCategoryId = cat.id.toString();
              _selectedCategoryName = cat.name;
            });
          }
        }
      }
    });
  }

  void _loadPostContent(Post post) {
    _items.clear();
    _textControllers.clear();
    _textFocusNodes.clear();

    if (post.contentBlocks.isNotEmpty) {
      for (final cb in post.contentBlocks) {
        if (cb.type == 'text') {
          _items.add(_EditorItem(type: 'text', text: cb.content));
          _textControllers.add(EmojiTextEditingController(text: cb.content));
          _textFocusNodes.add(FocusNode());
        } else if (cb.type == 'image' || cb.type == 'images') {
          final urls = cb.images.map((e) => e['url'] as String? ?? '').where((u) => u.isNotEmpty).toList();
          _items.add(_EditorItem(type: 'image', existingUrls: urls, imageLayout: cb.layout.isNotEmpty ? cb.layout : 'grid'));
        } else if (cb.type == 'voice') {
          _items.add(_EditorItem(type: 'voice', voicePath: cb.url, voiceDuration: cb.duration));
        } else if (cb.type == 'link') {
          _items.add(_EditorItem(type: 'link', linkUrl: cb.url));
          _textControllers.add(TextEditingController(text: cb.url));
          _textFocusNodes.add(FocusNode());
        }
      }
    } else {
      if (post.content.isNotEmpty) {
        _items.add(_EditorItem(type: 'text', text: post.content));
        _textControllers[0].text = post.content;
      }
      if (post.images.isNotEmpty) {
        final urls = post.images.map((e) => e.url).where((u) => u.isNotEmpty).toList();
        _items.add(_EditorItem(type: 'image', existingUrls: urls, imageLayout: 'grid'));
      }
      if (post.voiceUrl.isNotEmpty) {
        _items.add(_EditorItem(type: 'voice', voicePath: post.voiceUrl, voiceDuration: post.voiceDuration));
      }
      if (post.link.isNotEmpty) {
        _items.add(_EditorItem(type: 'link', linkUrl: post.link));
      }
    }

    if (_items.isEmpty || _items.every((i) => i.type == 'text' && i.text.isEmpty)) {
      _items.clear();
      _textControllers.clear();
      _textFocusNodes.clear();
      _items.add(_EditorItem(type: 'text'));
      _textControllers.add(EmojiTextEditingController());
      _textFocusNodes.add(FocusNode());
    }
    setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocus.dispose();
    for (final c in _textControllers) c.dispose();
    for (final f in _textFocusNodes) f.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    _previewPlayer?.dispose();
    _livePhotoCtrl?.dispose();
    super.dispose();
  }

  void _insertImageAt(int index) async {
    final result = await ImagePickerUtil.pickImages(context);
    if (result == null || result.imagePaths.isEmpty) return;

    final count = result.imagePaths.length;
    String layout;
    if (count == 1) {
      layout = 'full';
    } else if (count == 2) {
      layout = 'dual';
    } else if (count <= 9) {
      layout = 'grid';
    } else {
      layout = 'stack';
    }

    setState(() {
      _items.insert(index, _EditorItem(
        type: 'image',
        imagePaths: result.imagePaths,
        imageThumbs: result.imageThumbs,
        liveVideoPaths: result.liveVideoPaths,
        imageLayout: layout,
      ));
      _textControllers.insert(index, EmojiTextEditingController());
      _textFocusNodes.insert(index, FocusNode());
    });
  }

  void _addImagesToItem(int idx) async {
    final result = await ImagePickerUtil.pickImages(context);
    if (result == null || result.imagePaths.isEmpty) return;

    setState(() {
      final item = _items[idx];
      item.imagePaths.addAll(result.imagePaths);
      item.imageThumbs.addAll(result.imageThumbs);
      item.liveVideoPaths.addAll(result.liveVideoPaths);
      final totalCount = item.imagePaths.length + item.existingUrls.length;
      if (totalCount == 1) {
        item.imageLayout = 'full';
      } else if (totalCount == 2) {
        item.imageLayout = 'dual';
      } else if (totalCount <= 9) {
        item.imageLayout = 'grid';
      } else {
        item.imageLayout = 'stack';
      }
    });
  }

  void _insertTextAt(int index) {
    setState(() {
      _items.insert(index, _EditorItem(type: 'text'));
      _textControllers.insert(index, EmojiTextEditingController());
      _textFocusNodes.insert(index, FocusNode());
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (index < _textFocusNodes.length) {
        _textFocusNodes[index].requestFocus();
      }
    });
  }

  void _insertVoiceAt(int index) {
    setState(() {
      _items.insert(index, _EditorItem(type: 'voice'));
      _textControllers.insert(index, EmojiTextEditingController());
      _textFocusNodes.insert(index, FocusNode());
    });
  }

  void _insertLinkAt(int index) {
    setState(() {
      _items.insert(index, _EditorItem(type: 'link'));
      _textControllers.insert(index, EmojiTextEditingController());
      _textFocusNodes.insert(index, FocusNode());
    });
  }

  void _removeItem(int idx) {
    setState(() {
      if (idx < _textControllers.length) {
        _textControllers[idx].dispose();
        _textControllers.removeAt(idx);
      }
      if (idx < _textFocusNodes.length) {
        _textFocusNodes[idx].dispose();
        _textFocusNodes.removeAt(idx);
      }
      _items.removeAt(idx);
      if (_items.isEmpty) {
        _items.add(_EditorItem(type: 'text'));
        _textControllers.add(EmojiTextEditingController());
        _textFocusNodes.add(FocusNode());
      }
    });
  }

  void _onTextChanged(int idx, String value) {
    _items[idx].text = value;
  }

  void _insertEmoji(String emoji) {
    if (_currentTextIndex >= 0 && _currentTextIndex < _textControllers.length) {
      final controller = _textControllers[_currentTextIndex];
      final text = controller.text;
      final selection = controller.selection;
      final newText = text.replaceRange(selection.start, selection.end, emoji);
      controller.text = newText;
      controller.selection = TextSelection.collapsed(offset: selection.start + emoji.length);
      _items[_currentTextIndex].text = newText;
    }
  }

  void _insertGifEmoji(String assetPath) {
    final idx = _currentTextIndex;
    if (idx < 0 || idx >= _textControllers.length) return;
    final controller = _textControllers[idx];
    final filename = assetPath.split('/').last;
    final marker = '[emoji:$filename]';
    final text = controller.text;

    _emojiInserting = true;

    int cursorPos;
    if (_textFocusNodes[idx].hasFocus) {
      cursorPos = controller.selection.start;
      if (cursorPos < 0) cursorPos = text.length;
    } else {
      cursorPos = text.length;
    }

    final newText = text.substring(0, cursorPos) + marker + text.substring(cursorPos);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: cursorPos + marker.length);
    _onTextChanged(idx, controller.text);

    Future.microtask(() {
      _emojiInserting = false;
    });
  }

  void _showInsertMenu(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('插入内容', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInsertOption(Icons.image_outlined, '图片', const Color(0xFFE6F7FF), const Color(0xFF1890FF), () {
                    Navigator.pop(ctx);
                    _insertImageAt(index);
                  }),
                  _buildInsertOption(Icons.mic_outlined, '音频', const Color(0xFFFFF0F0), const Color(0xFFFF2442), () {
                    Navigator.pop(ctx);
                    _insertVoiceAt(index);
                  }),
                  _buildInsertOption(Icons.link_outlined, '链接', const Color(0xFFF0F5FF), const Color(0xFF1890FF), () {
                    Navigator.pop(ctx);
                    _insertLinkAt(index);
                  }),
                  _buildInsertOption(Icons.text_fields, '文字', const Color(0xFFF5F5F5), const Color(0xFF666666), () {
                    Navigator.pop(ctx);
                    _insertTextAt(index);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsertOption(IconData icon, String label, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, size: 24, color: fg),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildNav(),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _showEmojiPanel = false);
                  FocusScope.of(context).unfocus();
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleField(),
                      _buildTopicRow(),
                      const Divider(height: 1, indent: 14, endIndent: 14, color: Color(0xFFF5F5F5)),
                      ..._buildEditorItems(),
                      const SizedBox(height: 20),
                      if (!_showEmojiPanel && _currentTextIndex < 0) _buildAddMoreButton(),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomToolbar(),
            if (_showEmojiPanel) _buildEmojiPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildNav() {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 56, height: 44, alignment: Alignment.center, child: const Icon(Icons.close, size: 22, color: Color(0xFF333333))),
        ),
        const Expanded(child: Center(child: Text('发布笔记', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222))))),
        GestureDetector(
          onTap: _canPublish && !_publishing ? _doPublish : null,
          child: Container(
            width: 68,
            height: 44,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _canPublish ? const Color(0xFFFF2442) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _publishing
                  ? const SizedBox(width: 16, height: 16, child: CupertinoActivityIndicator(radius: 8, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_hasRedpacket) ...[
                        const Icon(Icons.card_giftcard, size: 13, color: Colors.white),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        _editingPostId != null ? '保存' : '发布',
                        style: TextStyle(
                          fontSize: 13,
                          color: _canPublish ? Colors.white : const Color(0xFF999999),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildTitleField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: TextField(
        controller: _titleCtrl,
        focusNode: _titleFocus,
        maxLength: 20,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
        decoration: const InputDecoration(
          hintText: '填写标题会有更多赞哦～',
          hintStyle: TextStyle(fontSize: 17, color: Color(0xFFCCCCCC)),
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildTopicRow() {
    return GestureDetector(
      onTap: _showTopicPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          const Text('#', style: TextStyle(fontSize: 16, color: Color(0xFFFF2442), fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text(
            _selectedCategoryName ?? '选择话题',
            style: TextStyle(
              fontSize: 14,
              color: _selectedCategoryName != null ? const Color(0xFFFF2442) : const Color(0xFFCCCCCC),
              fontWeight: _selectedCategoryName != null ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _buildEditorItems() {
    final widgets = <Widget>[];
    for (int i = 0; i < _items.length; i++) {
      widgets.add(_buildEditorItem(i));
      // 非文本项下方自动添加文本输入区域
      if (_items[i].type != 'text') {
        // 如果下一项不是文本，自动插入一个文本项
        if (i == _items.length - 1 || _items[i + 1].type != 'text') {
          widgets.add(_buildInlineTextAfter(i));
        }
      }
      if (i < _items.length - 1) {
        widgets.add(_buildInsertDivider(i + 1));
      }
    }
    return widgets;
  }

  Widget _buildInlineTextAfter(int afterIdx) {
    // 在非文本项下方提供一个可点击的文本输入区域
    return GestureDetector(
      onTap: () {
        // 在 afterIdx+1 位置插入文本项
        _insertTextAt(afterIdx + 1);
        // 自动聚焦新插入的文本框
        Future.delayed(const Duration(milliseconds: 100), () {
          if (afterIdx + 1 < _textFocusNodes.length) {
            _textFocusNodes[afterIdx + 1].requestFocus();
          }
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Text(
          '点击输入文本...',
          style: TextStyle(fontSize: 15, color: const Color(0xFFCCCCCC), height: 2.0),
        ),
      ),
    );
  }

  Widget _buildEditorItem(int idx) {
    final item = _items[idx];
    switch (item.type) {
      case 'text':
        return _buildTextItem(idx);
      case 'image':
        return _buildImageItem(idx);
      case 'voice':
        return _buildVoiceItem(idx);
      case 'link':
        return _buildLinkItem(idx);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextItem(int idx) {
    return _TextItemWidget(
      key: ValueKey('text_item_$idx'),
      idx: idx,
      controller: idx < _textControllers.length ? _textControllers[idx] : null,
      focusNode: idx < _textFocusNodes.length ? _textFocusNodes[idx] : null,
      onChanged: (v) => _onTextChanged(idx, v),
      onTap: () {
        setState(() {
          _currentTextIndex = idx;
        });
      },
      onFocus: (hasFocus) {
        if (hasFocus && !_emojiInserting) {
          setState(() => _showEmojiPanel = false);
        }
      },
    );
  }

  Widget _buildImageItem(int idx) {
    final item = _items[idx];
    final allPaths = [...item.existingUrls, ...item.imagePaths];
    if (allPaths.isEmpty) {
      return _buildEmptyImagePlaceholder(idx);
    }

    final liveIndices = <int>{};
    for (int i = 0; i < item.existingLiveVideoUrls.length; i++) {
      if (item.existingLiveVideoUrls[i].isNotEmpty) liveIndices.add(i);
    }
    for (int i = 0; i < item.liveVideoPaths.length; i++) {
      if (item.liveVideoPaths[i].isNotEmpty) liveIndices.add(item.existingUrls.length + i);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageGrid(idx, allPaths, liveIndices),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => _addImagesToItem(idx),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_photo_alternate_outlined, size: 14, color: Color(0xFF666666)),
                      SizedBox(width: 4),
                      Text('添加图片', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _removeItem(idx),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, size: 18, color: Color(0xFF999999)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLayoutBtn(idx, 'full', Icons.crop_original, '全宽'),
              _buildLayoutBtn(idx, 'dual', Icons.view_agenda, '双图'),
              _buildLayoutBtn(idx, 'grid', Icons.grid_view, '九宫格'),
              _buildLayoutBtn(idx, 'stack', Icons.layers, '堆叠'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyImagePlaceholder(int idx) {
    return GestureDetector(
      onTap: () => _addImagesToItem(idx),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 32, color: Color(0xFFCCCCCC)),
              SizedBox(height: 8),
              Text('点击添加图片', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutBtn(int idx, String layout, IconData icon, String label) {
    final item = _items[idx];
    final isActive = item.imageLayout == layout;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            item.imageLayout = layout;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFF0F0) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFFFF2442) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isActive ? const Color(0xFFFF2442) : const Color(0xFF666666)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? const Color(0xFFFF2442) : const Color(0xFF666666),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid(int idx, List<String> paths, Set<int> liveIndices) {
    final item = _items[idx];
    final layout = item.imageLayout;

    if (layout == 'stack' && paths.length > 1) {
      return _buildStackLayout(idx, paths, liveIndices);
    }
    if (layout == 'full') {
      return _buildReorderableColumn(idx, paths, liveIndices);
    }
    if (layout == 'dual' || (layout == 'grid' && paths.length == 2)) {
      return _buildReorderableRow(idx, paths, liveIndices);
    }
    return _buildReorderableWrap(idx, paths, liveIndices);
  }

  Widget _buildReorderableColumn(int idx, List<String> paths, Set<int> liveIndices) {
    return Column(
      children: paths.asMap().entries.map((e) => Padding(
        padding: EdgeInsets.only(bottom: e.key < paths.length - 1 ? 4 : 0),
        child: LongPressDraggable<int>(
          data: e.key,
          feedback: Material(elevation: 4, borderRadius: BorderRadius.circular(8), child: SizedBox(width: MediaQuery.of(context).size.width - 28, child: _buildSingleImage(idx, e.value, e.key, liveIndices.contains(e.key)))),
          childWhenDragging: Opacity(opacity: 0.3, child: _buildSingleImage(idx, e.value, e.key, liveIndices.contains(e.key))),
          child: DragTarget<int>(
            onAcceptWithDetails: (from) => _reorderImage(idx, from.data, e.key),
            builder: (ctx, candidate, rejected) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: candidate.isNotEmpty ? Border.all(color: const Color(0xFFFF2442), width: 2) : null,
              ),
              child: _buildSingleImage(idx, e.value, e.key, liveIndices.contains(e.key)),
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildReorderableRow(int idx, List<String> paths, Set<int> liveIndices) {
    return Row(
      children: paths.asMap().entries.map((e) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: e.key == 0 ? 4 : 0),
          child: LongPressDraggable<int>(
            data: e.key,
            feedback: Material(elevation: 4, borderRadius: BorderRadius.circular(6), child: SizedBox(width: (MediaQuery.of(context).size.width - 32) / 2, height: (MediaQuery.of(context).size.width - 32) / 2, child: _buildImageCell(idx, e.value, e.key, liveIndices.contains(e.key)))),
            childWhenDragging: Opacity(opacity: 0.3, child: AspectRatio(aspectRatio: 1, child: _buildImageCell(idx, e.value, e.key, liveIndices.contains(e.key)))),
            child: DragTarget<int>(
              onAcceptWithDetails: (from) => _reorderImage(idx, from.data, e.key),
              builder: (ctx, candidate, rejected) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: candidate.isNotEmpty ? Border.all(color: const Color(0xFFFF2442), width: 2) : null,
                ),
                child: AspectRatio(aspectRatio: 1, child: _buildImageCell(idx, e.value, e.key, liveIndices.contains(e.key))),
              ),
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildReorderableWrap(int idx, List<String> paths, Set<int> liveIndices) {
    const crossCount = 3;
    const spacing = 4.0;
    final width = (MediaQuery.of(context).size.width - 28 - spacing * (crossCount - 1)) / crossCount;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: paths.asMap().entries.map((e) => SizedBox(
        width: width,
        height: width,
        child: LongPressDraggable<int>(
          data: e.key,
          feedback: Material(elevation: 4, borderRadius: BorderRadius.circular(6), child: SizedBox(width: width, height: width, child: _buildImageCell(idx, e.value, e.key, liveIndices.contains(e.key)))),
          childWhenDragging: Opacity(opacity: 0.3, child: _buildImageCell(idx, e.value, e.key, liveIndices.contains(e.key))),
          child: DragTarget<int>(
            onAcceptWithDetails: (from) => _reorderImage(idx, from.data, e.key),
            builder: (ctx, candidate, rejected) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: candidate.isNotEmpty ? Border.all(color: const Color(0xFFFF2442), width: 2) : null,
              ),
              child: _buildImageCell(idx, e.value, e.key, liveIndices.contains(e.key)),
            ),
          ),
        ),
      )).toList(),
    );
  }

  void _reorderImage(int itemIdx, int fromIdx, int toIdx) {
    if (fromIdx == toIdx) return;
    setState(() {
      final item = _items[itemIdx];
      final allUrls = [...item.existingUrls, ...item.imagePaths];
      if (fromIdx >= allUrls.length || toIdx >= allUrls.length) return;

      final fromIsExisting = fromIdx < item.existingUrls.length;
      final toIsExisting = toIdx < item.existingUrls.length;

      if (fromIsExisting && toIsExisting) {
        final url = item.existingUrls.removeAt(fromIdx);
        final videoUrl = fromIdx < item.existingLiveVideoUrls.length ? item.existingLiveVideoUrls.removeAt(fromIdx) : '';
        final insertAt = toIdx > fromIdx ? toIdx : toIdx;
        item.existingUrls.insert(insertAt, url);
        if (videoUrl.isNotEmpty) {
          if (insertAt <= item.existingLiveVideoUrls.length) {
            item.existingLiveVideoUrls.insert(insertAt, videoUrl);
          } else {
            item.existingLiveVideoUrls.add(videoUrl);
          }
        }
      } else if (!fromIsExisting && !toIsExisting) {
        final localFrom = fromIdx - item.existingUrls.length;
        final localTo = toIdx - item.existingUrls.length;
        if (localFrom < item.imagePaths.length && localTo < item.imagePaths.length) {
          final path = item.imagePaths.removeAt(localFrom);
          final thumb = localFrom < item.imageThumbs.length ? item.imageThumbs.removeAt(localFrom) : null;
          final livePath = localFrom < item.liveVideoPaths.length ? item.liveVideoPaths.removeAt(localFrom) : null;
          final insertAt = localTo > localFrom ? localTo : localTo;
          item.imagePaths.insert(insertAt, path);
          if (thumb != null) {
            if (insertAt <= item.imageThumbs.length) {
              item.imageThumbs.insert(insertAt, thumb);
            } else {
              item.imageThumbs.add(thumb);
            }
          }
          if (livePath != null) {
            if (insertAt <= item.liveVideoPaths.length) {
              item.liveVideoPaths.insert(insertAt, livePath);
            } else {
              item.liveVideoPaths.add(livePath);
            }
          }
        }
      }
    });
  }

  Widget _buildStackLayout(int idx, List<String> paths, Set<int> liveIndices) {
    final isExpanded = _expandedStacks.contains(idx);
    if (isExpanded) {
      return _buildReorderableWrap(idx, paths, liveIndices);
    }
    return GestureDetector(
      onTap: () => setState(() => _expandedStacks.add(idx)),
      child: SizedBox(
        height: 200,
        child: Stack(
          children: paths.asMap().entries.map((e) {
            final offset = e.key * 8.0;
            return Positioned(
              left: offset,
              top: offset,
              child: Container(
                width: 180 - offset,
                height: 180 - offset,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImageCell(idx, e.value, e.key, liveIndices.contains(e.key)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSingleImage(int itemIdx, String src, int imgIdx, bool isLive) {
    Uint8List? thumbData;
    final item = _items[itemIdx];
    final localIdx = imgIdx - item.existingUrls.length;
    if (localIdx >= 0 && localIdx < item.imageThumbs.length) {
      thumbData = item.imageThumbs[localIdx];
    }
    final videoPath = isLive && localIdx >= 0 && localIdx < item.liveVideoPaths.length ? item.liveVideoPaths[localIdx] : null;
    final isPlaying = _livePhotoPlaying && _livePhotoPath == videoPath;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _imgPreview(src, thumbData: thumbData, fit: BoxFit.cover),
                if (isPlaying && _livePhotoCtrl != null && _livePhotoCtrl!.value.isInitialized)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _livePhotoCtrl!.value.size.width,
                      height: _livePhotoCtrl!.value.size.height,
                      child: VideoPlayer(_livePhotoCtrl!),
                    ),
                  ),
              ],
            ),
          ),
          if (isLive)
            Positioned(
              left: 8,
              bottom: 8,
              child: _publishLiveBadge(videoPath: videoPath),
            ),
          Positioned(
            right: 8,
            top: 8,
            child: GestureDetector(
              onTap: () => _removeSingleImage(itemIdx, imgIdx),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCell(int itemIdx, String src, int imgIdx, bool isLive) {
    Uint8List? thumbData;
    final item = _items[itemIdx];
    final localIdx = imgIdx - item.existingUrls.length;
    if (localIdx >= 0 && localIdx < item.imageThumbs.length) {
      thumbData = item.imageThumbs[localIdx];
    }
    final videoPath = isLive && localIdx >= 0 && localIdx < item.liveVideoPaths.length ? item.liveVideoPaths[localIdx] : null;
    final isPlaying = _livePhotoPlaying && _livePhotoPath == videoPath;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _imgPreview(src, thumbData: thumbData, fit: BoxFit.cover),
          if (isPlaying && _livePhotoCtrl != null && _livePhotoCtrl!.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _livePhotoCtrl!.value.size.width,
                height: _livePhotoCtrl!.value.size.height,
                child: VideoPlayer(_livePhotoCtrl!),
              ),
            ),
          if (isLive)
            Positioned(
              left: 4,
              bottom: 4,
              child: _publishLiveBadge(small: true, videoPath: videoPath),
            ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: () => _removeSingleImage(itemIdx, imgIdx),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _playPublishLivePhoto(String videoPath) async {
    if (_livePhotoPlaying) return;
    _stopPublishLivePhoto();
    _livePhotoCtrl = VideoPlayerController.file(File(videoPath));
    try {
      await _livePhotoCtrl!.initialize();
      _livePhotoCtrl!.setLooping(false);
      _livePhotoCtrl!.addListener(_onPublishLivePhotoEnd);
      _livePhotoCtrl!.play();
      _livePhotoPath = videoPath;
      setState(() => _livePhotoPlaying = true);
    } catch (_) {
      _livePhotoCtrl?.dispose();
      _livePhotoCtrl = null;
    }
  }

  void _onPublishLivePhotoEnd() {
    if (_livePhotoCtrl != null && !_livePhotoCtrl!.value.isPlaying && _livePhotoCtrl!.value.position >= _livePhotoCtrl!.value.duration) {
      _stopPublishLivePhoto();
    }
  }

  void _stopPublishLivePhoto() {
    _livePhotoCtrl?.removeListener(_onPublishLivePhotoEnd);
    _livePhotoCtrl?.pause();
    _livePhotoCtrl?.dispose();
    _livePhotoCtrl = null;
    _livePhotoPath = null;
    if (_livePhotoPlaying && mounted) {
      setState(() => _livePhotoPlaying = false);
    }
  }

  Widget _publishLiveBadge({bool small = false, String? videoPath}) {
    final isPlaying = _livePhotoPlaying && _livePhotoPath == videoPath;
    return GestureDetector(
      onTap: videoPath != null ? () => _playPublishLivePhoto(videoPath) : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 4 : 6, vertical: small ? 2 : 3),
        decoration: BoxDecoration(
          color: isPlaying
              ? const Color(0xFFFF2442).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(small ? 3 : 4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icons/icon_live_photo.png', width: small ? 10 : 14, height: small ? 10 : 14, color: isPlaying ? Colors.white : null),
            SizedBox(width: small ? 2 : 3),
            Text('LIVE', style: TextStyle(fontSize: small ? 8 : 10, color: isPlaying ? Colors.white : const Color(0xFF333333), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  void _removeSingleImage(int itemIdx, int imgIdx) {
    setState(() {
      final item = _items[itemIdx];
      if (imgIdx < item.existingUrls.length) {
        item.existingUrls.removeAt(imgIdx);
        if (imgIdx < item.existingLiveVideoUrls.length) {
          item.existingLiveVideoUrls.removeAt(imgIdx);
        }
      } else {
        final localIdx = imgIdx - item.existingUrls.length;
        if (localIdx < item.imagePaths.length) {
          item.imagePaths.removeAt(localIdx);
          if (localIdx < item.imageThumbs.length) {
            item.imageThumbs.removeAt(localIdx);
          }
          if (localIdx < item.liveVideoPaths.length) {
            item.liveVideoPaths.removeAt(localIdx);
          }
        }
      }
      if (item.existingUrls.isEmpty && item.imagePaths.isEmpty) {
        item.imageLayout = 'grid';
      }
    });
  }

  Widget _buildVoiceItem(int idx) {
    final item = _items[idx];
    if (item.voicePath != null) {
      final isPlaying = _playingVoiceIdx == idx;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _previewVoice(idx, item.voicePath!),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Color(0xFFFF2442), shape: BoxShape.circle),
                child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('语音消息', style: TextStyle(fontSize: 13, color: Color(0xFF333333), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Row(
                    children: List.generate(20, (i) => Container(
                      width: 3,
                      height: 4 + (i % 5) * 2.0,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2442).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    )),
                  ),
                ],
              ),
            ),
            if (item.voiceDuration > 0)
              Text(
                '${item.voiceDuration}s',
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _removeItem(idx),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.close, size: 14, color: Color(0xFF999999)),
              ),
            ),
          ],
        ),
      );
    }

    if (_isRecording && _recordingItemIdx == idx) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFF2442),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFFFF2442).withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '正在录制 ${_recordSeconds ~/ 60}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFFFF2442), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (_recordSeconds % 60) / 60.0,
                      backgroundColor: const Color(0xFFFFD9DD),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2442)),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2442),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('停止', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _startRecording(idx),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: Color(0xFFFF2442), shape: BoxShape.circle),
              child: const Icon(Icons.mic, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('点击录制语音', style: TextStyle(fontSize: 13, color: Color(0xFF333333), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                const Text('录制后可添加语音消息', style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _pickAudioFile(idx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('上传文件', style: TextStyle(fontSize: 12, color: Color(0xFF1890FF))),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _removeItem(idx),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.close, size: 14, color: Color(0xFF999999)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkItem(int idx) {
    final item = _items[idx];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: idx < _textControllers.length ? _textControllers[idx] : null,
              onChanged: (v) => item.linkUrl = v,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1890FF), decoration: TextDecoration.underline),
              decoration: const InputDecoration(
                hintText: '输入链接地址',
                hintStyle: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.link, size: 18, color: Color(0xFF999999)),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _removeItem(idx),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.delete_outline, size: 18, color: Color(0xFF999999)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsertDivider(int insertIndex) {
    return GestureDetector(
      onTap: () => _showInsertMenu(insertIndex),
      child: Container(
        height: 24,
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Center(
          child: Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddMoreButton() {
    return GestureDetector(
      onTap: () => _showInsertMenu(_items.length),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 18, color: Color(0xFF999999)),
            SizedBox(width: 4),
            Text('添加更多内容', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          _buildToolBtn(Icons.image_outlined, () {
            setState(() => _showEmojiPanel = false);
            _insertImageAt(_items.length);
          }),
          _buildToolBtn(Icons.mic_outlined, () {
            setState(() => _showEmojiPanel = false);
            _insertVoiceAt(_items.length);
          }),
          _buildToolBtn(Icons.link_outlined, () {
            setState(() => _showEmojiPanel = false);
            _insertLinkAt(_items.length);
          }),
          _buildToolBtn(
            _showEmojiPanel ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined,
            () {
              if (_showEmojiPanel) {
                setState(() => _showEmojiPanel = false);
                if (_currentTextIndex >= 0 && _currentTextIndex < _textFocusNodes.length) {
                  _textFocusNodes[_currentTextIndex].requestFocus();
                }
              } else {
                FocusScope.of(context).unfocus();
                setState(() => _showEmojiPanel = true);
              }
            },
          ),
          _buildToolBtn(
            _hasRedpacket ? Icons.card_giftcard : Icons.card_giftcard_outlined,
            () {
              setState(() => _showEmojiPanel = false);
              _showRedpacketDialog();
            },
            color: _hasRedpacket ? const Color(0xFFFF2442) : null,
          ),
          const Spacer(),
          if (_selectedCategoryName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '#$_selectedCategoryName',
                style: const TextStyle(fontSize: 12, color: Color(0xFFFF2442)),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildToolBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Icon(icon, size: 24, color: color ?? const Color(0xFF666666)),
      ),
    );
  }

  Widget _buildEmojiPanel() {
    return EmojiPickerPanel(
      onEmojiSelected: (assetPath) => _insertGifEmoji(assetPath),
    );
  }

  Widget _imgPreview(String src, {Uint8List? thumbData, double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (thumbData != null && thumbData.isNotEmpty) {
      return Image.memory(thumbData, width: width, height: height, fit: fit);
    }
    final file = File(src);
    if (file.existsSync()) {
      return Image.file(file, width: width, height: height, fit: fit);
    }
    if (src.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: src,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(width: width, height: height, color: const Color(0xFFF5F5F5)),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: const Color(0xFFF5F5F5),
          child: const Icon(Icons.broken_image, color: Color(0xFFCCCCCC)),
        ),
      );
    }
    if (src.startsWith('/')) {
      return CachedNetworkImage(
        imageUrl: fullUrl(src),
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(width: width, height: height, color: const Color(0xFFF5F5F5)),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: const Color(0xFFF5F5F5),
          child: const Icon(Icons.broken_image, color: Color(0xFFCCCCCC)),
        ),
      );
    }
    return Container(width: width, height: height, color: const Color(0xFFF5F5F5));
  }

  void _showRedpacketDialog() {
    final coinsCtrl = TextEditingController(text: _hasRedpacket ? _redpacketCoins.toString() : '');
    final countCtrl = TextEditingController(text: _hasRedpacket ? _redpacketCount.toString() : '');
    final msgCtrl = TextEditingController(text: _hasRedpacket ? _redpacketMessage : '恭喜发财');
    int? balance;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 32, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(children: [
                  const Icon(Icons.card_giftcard, color: Color(0xFFFF2442), size: 24),
                  const SizedBox(width: 8),
                  const Text('发留币红包', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.close, size: 16, color: Color(0xFF999999))),
                  ),
                ]),
              ),
              if (balance != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.account_balance_wallet, size: 16, color: Color(0xFFFF9800)),
                      const SizedBox(width: 6),
                      Text('留币余额: $balance', style: const TextStyle(fontSize: 13, color: Color(0xFF795548), fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TextField(
                  controller: coinsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '总留币数',
                    labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
                    prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20, color: Color(0xFFFF9800)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8E8E8))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8E8E8))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF2442))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: countCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '份数',
                    labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
                    prefixIcon: const Icon(Icons.people_outline, size: 20, color: Color(0xFF3378E5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8E8E8))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8E8E8))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF2442))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: msgCtrl,
                  decoration: InputDecoration(
                    labelText: '祝福语',
                    labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
                    prefixIcon: const Icon(Icons.favorite_border, size: 20, color: Color(0xFFFF2442)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8E8E8))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8E8E8))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF2442))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(children: [
                  if (_hasRedpacket)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _hasRedpacket = false;
                            _redpacketId = null;
                            _redpacketCoins = 0;
                            _redpacketCount = 0;
                            _redpacketMessage = '恭喜发财';
                          });
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          alignment: Alignment.center,
                          child: const Text('取消红包', style: TextStyle(fontSize: 15, color: Color(0xFF999999), fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                  if (_hasRedpacket) const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final coins = int.tryParse(coinsCtrl.text) ?? 0;
                        final count = int.tryParse(countCtrl.text) ?? 0;
                        if (coins <= 0) {
                          AppToast.error(context, message: '请输入留币数');
                          return;
                        }
                        if (count <= 0) {
                          AppToast.error(context, message: '请输入份数');
                          return;
                        }
                        if (coins < count) {
                          AppToast.error(context, message: '留币数不能少于份数');
                          return;
                        }
                        setState(() {
                          _hasRedpacket = true;
                          _redpacketCoins = coins;
                          _redpacketCount = count;
                          _redpacketMessage = msgCtrl.text.trim().isEmpty ? '恭喜发财' : msgCtrl.text.trim();
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: const Text('确认', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          );
        });
      },
    );
    Provider.of<PostProvider>(context, listen: false).getCoinBalance().then((res) {
      if (res['code'] == 200) {
        // 更新弹窗中的余额显示 - 由于弹窗是StatefulBuilder，这里无法直接更新
        // 余额信息会在下次打开时显示
      }
    });
  }

  void _showTopicPicker() {
    final pp = Provider.of<PostProvider>(context, listen: false);
    final isAdmin = Provider.of<UserProvider>(context, listen: false).userInfo?.role == 1;
    final cats = pp.categories.where((c) => c.publishRestriction != 1 || isAdmin).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Text('选择话题', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF999999)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('选择合适的话题能让更多人看到你的笔记', style: TextStyle(fontSize: 13, color: const Color(0xFF999999))),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final cat = cats[i];
                  final isSelected = _selectedCategoryId == cat.id.toString();
                  final user = Provider.of<UserProvider>(context, listen: false).userInfo;
                  final isAdmin = user?.role == 1;
                  final userLevel = user?.levelInfo?.level ?? 1;
                  final isLocked = !isAdmin && cat.minLevel > 0 && userLevel < cat.minLevel;
                  return GestureDetector(
                    onTap: () {
                      if (isLocked) {
                        AppToast.info(context, message: '需要到达Lv.${cat.minLevel}以后才能发布笔记');
                        return;
                      }
                      setState(() {
                        _selectedCategoryId = cat.id.toString();
                        _selectedCategoryName = cat.name;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: isLocked ? const Color(0xFFF5F5F5) : (isSelected ? const Color(0xFFFFF0F0) : const Color(0xFFF8F8F8)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFF2442) : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isLocked ? const Color(0xFFDDDDDD) : (isSelected ? const Color(0xFFFF2442) : const Color(0xFFEEEEEE)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: isLocked
                                  ? const Icon(Icons.lock_outline, size: 16, color: Color(0xFF999999))
                                  : Text(
                                '#',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isSelected ? Colors.white : const Color(0xFF999999),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(child: Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isLocked ? const Color(0xFFBBBBBB) : (isSelected ? const Color(0xFFFF2442) : const Color(0xFF333333)),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                )),
                                if (cat.minLevel > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isLocked ? const Color(0xFFEEEEEE) : const Color(0xFFFFF0F0),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(isLocked ? Icons.lock_outline : Icons.star_outline, size: 10, color: isLocked ? const Color(0xFFBBBBBB) : const Color(0xFFFF2442)),
                                        const SizedBox(width: 2),
                                        Text('Lv.${cat.minLevel}', style: TextStyle(fontSize: 10, color: isLocked ? const Color(0xFFBBBBBB) : const Color(0xFFFF2442), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected && !isLocked)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF2442),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 12, color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _doPublish() async {
    if (_publishing) return;

    // 发布前校验分类等级限制
    if (_selectedCategoryId != null) {
      final cats = Provider.of<PostProvider>(context, listen: false).categories;
      final cat = cats.firstWhere(
        (c) => c.id.toString() == _selectedCategoryId,
        orElse: () => cats.first,
      );
      final user = Provider.of<UserProvider>(context, listen: false).userInfo;
      final isAdmin = user?.role == 1;
      final userLevel = user?.levelInfo?.level ?? 1;
      if (!isAdmin && cat.minLevel > 0 && userLevel < cat.minLevel) {
        AppToast.info(context, message: '需要到达Lv.${cat.minLevel}以后才能发布笔记');
        return;
      }
    }

    setState(() => _publishing = true);

    try {
      final pp = Provider.of<PostProvider>(context, listen: false);

      // 先上传所有新图片和实况视频
      final uploadedImageUrls = <String>[];
      final uploadedLiveVideoUrls = <String>[];

      for (final item in _items.where((i) => i.type == 'image')) {
        for (int j = 0; j < item.imagePaths.length; j++) {
          final url = await pp.uploadImage(item.imagePaths[j]);
          if (url != null) {
            uploadedImageUrls.add(url);
            final isLive = j < item.liveVideoPaths.length && item.liveVideoPaths[j].isNotEmpty;
            if (isLive) {
              final videoUrl = await pp.uploadFile(item.liveVideoPaths[j]);
              uploadedLiveVideoUrls.add(videoUrl ?? '');
            } else {
              uploadedLiveVideoUrls.add('');
            }
          }
        }
      }

      // 上传音频
      String? voiceUrl;
      int voiceDuration = 0;
      for (final item in _items.where((i) => i.type == 'voice')) {
        if (item.voicePath != null && item.voicePath!.isNotEmpty) {
          voiceUrl = await pp.uploadFile(item.voicePath!);
          voiceDuration = item.voiceDuration;
        }
      }

      // 构建 content_blocks
      final contentBlocks = <Map<String, dynamic>>[];
      int uploadedIdx = 0;

      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (item.type == 'text' && item.text.trim().isNotEmpty) {
          contentBlocks.add({'type': 'text', 'content': item.text.trim()});
        } else if (item.type == 'image') {
          final imageData = <Map<String, dynamic>>[];
          // 已有图片
          for (int j = 0; j < item.existingUrls.length; j++) {
            imageData.add({
              'url': item.existingUrls[j],
              'type': j < item.existingLiveVideoUrls.length && item.existingLiveVideoUrls[j].isNotEmpty ? 'live' : 'image',
              'video_url': j < item.existingLiveVideoUrls.length ? item.existingLiveVideoUrls[j] : '',
              'ratio': 1.2,
            });
          }
          // 新上传图片
          for (int j = 0; j < item.imagePaths.length; j++) {
            if (uploadedIdx < uploadedImageUrls.length) {
              final isLive = j < item.liveVideoPaths.length && item.liveVideoPaths[j].isNotEmpty;
              imageData.add({
                'url': uploadedImageUrls[uploadedIdx],
                'type': isLive ? 'live' : 'image',
                'video_url': isLive && uploadedIdx < uploadedLiveVideoUrls.length ? uploadedLiveVideoUrls[uploadedIdx] : '',
                'ratio': 1.2,
              });
              uploadedIdx++;
            }
          }
          if (imageData.isNotEmpty) {
            contentBlocks.add({'type': 'images', 'images': imageData, 'layout': item.imageLayout});
          }
        } else if (item.type == 'voice' && voiceUrl != null) {
          contentBlocks.add({'type': 'voice', 'url': voiceUrl, 'duration': voiceDuration});
        } else if (item.type == 'link' && item.linkUrl.isNotEmpty) {
          contentBlocks.add({'type': 'link', 'url': item.linkUrl});
        }
      }

      // 构建 images 数组（用于后端 post_images 表）
      final imagesData = <Map<String, dynamic>>[];
      uploadedIdx = 0;
      for (final item in _items.where((i) => i.type == 'image')) {
        for (int j = 0; j < item.existingUrls.length; j++) {
          imagesData.add({
            'url': item.existingUrls[j],
            'type': j < item.existingLiveVideoUrls.length && item.existingLiveVideoUrls[j].isNotEmpty ? 'live' : 'image',
            'video_url': j < item.existingLiveVideoUrls.length ? item.existingLiveVideoUrls[j] : '',
            'ratio': 1.2,
          });
        }
        for (int j = 0; j < item.imagePaths.length; j++) {
          if (uploadedIdx < uploadedImageUrls.length) {
            final isLive = j < item.liveVideoPaths.length && item.liveVideoPaths[j].isNotEmpty;
            imagesData.add({
              'url': uploadedImageUrls[uploadedIdx],
              'type': isLive ? 'live' : 'image',
              'video_url': isLive && uploadedIdx < uploadedLiveVideoUrls.length ? uploadedLiveVideoUrls[uploadedIdx] : '',
              'ratio': 1.2,
            });
            uploadedIdx++;
          }
        }
      }

      // 收集正文内容
      String content = '';
      if (contentBlocks.isNotEmpty && contentBlocks[0]['type'] == 'text') {
        content = contentBlocks[0]['content'];
      }

      final data = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'content': content,
        'category_id': int.parse(_selectedCategoryId!),
        'images': imagesData,
        'content_blocks': contentBlocks,
        'voice_url': voiceUrl ?? '',
        'voice_duration': voiceDuration,
        'link': _items.where((i) => i.type == 'link').map((i) => i.linkUrl).firstWhere((u) => u.isNotEmpty, orElse: () => ''),
      };

      // 如果有红包，先发红包获取redpacket_id
      if (_hasRedpacket && _redpacketId == null) {
        try {
          final rpRes = await pp.sendRedpacket(
            totalCoins: _redpacketCoins,
            totalCount: _redpacketCount,
            message: _redpacketMessage,
          );
          if (rpRes['code'] == 200 && rpRes['data']?['redpacket_id'] != null) {
            _redpacketId = rpRes['data']['redpacket_id'] as int;
            data['redpacket_id'] = _redpacketId;
          } else {
            if (mounted) AppToast.error(context, message: rpRes['msg'] ?? '红包发送失败');
            setState(() => _publishing = false);
            return;
          }
        } catch (e) {
          if (mounted) AppToast.error(context, message: '红包发送失败');
          setState(() => _publishing = false);
          return;
        }
      } else if (_redpacketId != null) {
        data['redpacket_id'] = _redpacketId;
      }

      Map<String, dynamic> result;
      if (_editingPostId != null) {
        result = await pp.updatePost(_editingPostId!, data);
      } else {
        result = await pp.createPost(data);
      }

      if (result['code'] == 200 || result['code'] == 201) {
        AppToast.success(context, message: _editingPostId != null ? '修改成功' : '发布成功');
        Navigator.pop(context, true);
      } else {
        AppToast.error(context, message: result['msg'] ?? '发布失败');
      }
    } catch (e) {
      AppToast.error(context, message: '发布失败: $e');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _pickAudioFile(int idx) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() => _items[idx].voicePath = result.files.single.path);
    }
  }

  void _startRecording(int idx) async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      AppToast.error(context, message: '需要麦克风权限');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    setState(() {
      _isRecording = true;
      _recordingItemIdx = idx;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  void _stopRecording() async {
    final path = await _recorder.stop();
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      if (path != null && _recordingItemIdx != null) {
        _items[_recordingItemIdx!].voicePath = path;
        _items[_recordingItemIdx!].voiceDuration = _recordSeconds;
      }
      _recordingItemIdx = null;
    });
  }

  void _previewVoice(int idx, String path) async {
    await _previewPlayer?.stop();
    if (_playingVoiceIdx == idx) {
      setState(() => _playingVoiceIdx = -1);
      return;
    }
    setState(() { _playingVoiceIdx = idx; _voiceLoading = true; });
    _previewPlayer = AudioPlayer();
    await _previewPlayer!.play(DeviceFileSource(path));
    _previewPlayer!.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingVoiceIdx = -1);
    });
    setState(() => _voiceLoading = false);
  }
}

class EmojiTextEditingController extends TextEditingController {
  EmojiTextEditingController({super.text});
}

class _TextItemWidget extends StatefulWidget {
  final int idx;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final ValueChanged<bool>? onFocus;

  const _TextItemWidget({
    super.key,
    required this.idx,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onTap,
    this.onFocus,
  });

  @override
  State<_TextItemWidget> createState() => _TextItemWidgetState();
}

class _TextItemWidgetState extends State<_TextItemWidget> {
  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    widget.onFocus?.call(widget.focusNode?.hasFocus ?? false);
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 15, color: Color(0xFF333333), height: 1.8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ExtendedTextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        onTap: widget.onTap,
        maxLines: null,
        minLines: 1,
        style: textStyle,
        cursorColor: const Color(0xFFFF2442),
        specialTextSpanBuilder: MySpecialTextSpanBuilder(textStyle: textStyle),
        decoration: const InputDecoration(
          hintText: '正文',
          hintStyle: TextStyle(fontSize: 15, color: Color(0xFFCCCCCC)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

class EmojiText extends SpecialText {
  static const String flag = '[emoji:';
  final TextStyle? textStyle;
  final int startIndex;

  EmojiText(this.textStyle, {SpecialTextGestureTapCallback? onTap, required this.startIndex})
      : super(flag, ']', textStyle, onTap: onTap);

  @override
  InlineSpan finishText() {
    final String key = getContent();
    final assetPath = 'assets/emojis/$key';
    return ImageSpan(
      AssetImage(assetPath),
      actualText: toString(),
      start: startIndex,
      imageWidth: 22,
      imageHeight: 22,
      fit: BoxFit.contain,
      alignment: PlaceholderAlignment.middle,
    );
  }
}

class MySpecialTextSpanBuilder extends SpecialTextSpanBuilder {
  final TextStyle? textStyle;

  MySpecialTextSpanBuilder({this.textStyle});

  @override
  SpecialText? createSpecialText(String flag, {TextStyle? textStyle, SpecialTextGestureTapCallback? onTap, int? index}) {
    if (isStart(flag, EmojiText.flag)) {
      final startIndex = (index ?? 0) - EmojiText.flag.length + 1;
      return EmojiText(textStyle ?? this.textStyle, onTap: onTap, startIndex: startIndex);
    }
    return null;
  }
}
