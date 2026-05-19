import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';
import '../utils/helpers.dart';
import '../utils/image_picker_util.dart';
import '../utils/emoji_text.dart';
import '../utils/emoji_assets.dart';
import '../widgets/emoji_picker_panel.dart';
import '../widgets/app_toast.dart';
import 'package:extended_text_field/extended_text_field.dart';
import '../widgets/image_preview.dart';

final _urlRegex = RegExp(r'https?://[^\s\u4e00-\u9fff\u3000-\u303f\uff00-\uffef]+');

class DetailScreen extends StatefulWidget {
  final int postId;
  final int? highlightCommentId;
  const DetailScreen({super.key, required this.postId, this.highlightCommentId});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> with TickerProviderStateMixin {
  Post? _post;
  List<Comment> _comments = [];
  bool _loading = true;
  bool _isPrivateBlocked = false;
  String _privateMsg = '';
  bool _commentsLoading = false;
  int _commentPage = 1;
  bool _noMoreComments = false;
  bool _isFollowing = false;
  bool _isFan = false;
  String _commentSort = 'latest';
  final Map<int, bool> _stackExpanded = {};
  final Map<int, bool> _subExpanded = {};

  VideoPlayerController? _livePhotoCtrl;
  bool _livePhotoPlaying = false;
  String? _livePhotoUrl;
  bool _livePhotoLoading = false;
  static final Map<String, VideoPlayerController> _videoCache = {};
  OverlayEntry? _livePhotoOverlay;

  late AnimationController _voiceWaveCtrl;
  int _playingVoiceIdx = -1;
  bool _voiceLoading = false;
  AudioPlayer? _audioPlayer;
  final _commentCtrl = TextEditingController();
  final _commentFocusNode = FocusNode();
  Comment? _replyToComment;
  int? _replyParentId;
  int? _replyToUserId;
  final ScrollController _scrollCtrl = ScrollController();
  bool _titlePinned = false;
  List<String> _commentImages = [];
  bool _isSubmitting = false;
  bool _showCommentEmojiPanel = false;
  bool _commentEmojiInserting = false;
  bool _isCommentRecording = false;
  int _commentRecordSeconds = 0;
  String? _commentVoicePath;
  int _commentVoiceDuration = 0;
  int _playingCommentVoiceIdx = -1;
  bool _commentVoiceLoading = false;
  bool _isPreviewingCommentVoice = false;
  bool _imageUploading = false;
  bool _isSavingImage = false;
  final ValueNotifier<String> _inputText = ValueNotifier('');
  bool _isEditing = false;
  int? _highlightCommentId;
  late AnimationController _highlightCtrl;
  late AnimationController _likeBounceCtrl;
  late AnimationController _collectBounceCtrl;
  final Map<int, AnimationController> _commentLikeCtrls = {};
  final Map<int, GlobalKey> _commentKeys = {};

  static const _tGrad = <List<Color>>[
    [Color(0xFFFFFFFF)],
    [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
    [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
    [Color(0xFF1A1A2E), Color(0xFF16213E)],
    [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
    [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
    [Color(0xFFEFEBE9), Color(0xFFD7CCC8)],
    [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
  ];
  static const _tClr = <Color>[
    Color(0xFF222222), Color(0xFF5D4037), Color(0xFF2E7D32), Color(0xFFE0E0E0),
    Color(0xFF880E4F), Color(0xFF1565C0), Color(0xFF3E2723), Color(0xFF6A1B9A),
  ];

  @override
  void initState() {
    super.initState();
    _voiceWaveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _highlightCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _likeBounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _collectBounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scrollCtrl.addListener(_onScroll);
    _commentCtrl.addListener(() => _inputText.value = _commentCtrl.text);
    _commentFocusNode.addListener(() {
      if (_commentFocusNode.hasFocus && !_commentEmojiInserting) {
        setState(() => _showCommentEmojiPanel = false);
      }
      _onFocusChange();
    });
    _loadPost();
  }

  @override
  void dispose() {
    _livePhotoCtrl?.removeListener(_onLivePhotoEnd);
    if (!_videoCache.containsKey(_livePhotoUrl)) {
      _livePhotoCtrl?.dispose();
    }
    _livePhotoOverlay?.remove();
    _voiceWaveCtrl.dispose();
    _highlightCtrl.dispose();
    _likeBounceCtrl.dispose();
    _collectBounceCtrl.dispose();
    for (final ctrl in _commentLikeCtrls.values) { ctrl.dispose(); }
    _commentCtrl.dispose();
    _commentFocusNode.dispose();
    _inputText.dispose();
    _scrollCtrl.dispose();
    _audioPlayer?.dispose();
    _commentRecorder.dispose();
    _commentRecTimer?.cancel();
    super.dispose();
  }

  void _dismissKeyboard() {
    _commentFocusNode.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  double _bounceScale(double t) {
    if (t <= 0) return 1.0;
    if (t < 0.3) return 1.0 + 0.5 * (t / 0.3);
    return 1.0 + 0.5 * ((1.0 - t) / 0.7);
  }

  void _showActionLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442))),
    );
  }

  void _dismissActionLoading() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _onFocusChange() {
    if (!_commentFocusNode.hasFocus && _isEditing && !_showCommentEmojiPanel) {
      setState(() {
        _isEditing = false;
        _showCommentEmojiPanel = false;
        if (_commentCtrl.text.trim().isEmpty && _commentImages.isEmpty && _commentVoicePath == null) {
          _replyToComment = null;
          _replyParentId = null;
          _replyToUserId = null;
        }
      });
    }
  }

  void _onScroll() {
    final show = _scrollCtrl.offset > 200;
    if (show != _titlePinned) setState(() => _titlePinned = show);
    // Load more comments when near bottom
    if (!_commentsLoading && !_noMoreComments && _scrollCtrl.hasClients) {
      final max = _scrollCtrl.position.maxScrollExtent;
      final current = _scrollCtrl.offset;
      if (max - current < 300) {
        _commentPage++;
        _loadComments();
      }
    }
  }

  Future<void> _loadPost() async {
    final pp = Provider.of<PostProvider>(context, listen: false);
    try {
      final res = await pp.fetchPostById(widget.postId);
      if (mounted) {
        if (res['code'] == 200 && res['post'] != null) {
          final post = res['post'] as Post;
          debugPrint('[Detail] post loaded: id=${post.id}, title=${post.title}, blocks=${post.contentBlocks.length}, images=${post.images.length}');
          setState(() { _post = post; _isFollowing = post.isFollowed; _isFan = post.isFan; _loading = false; });
          _loadComments();
          _preloadLivePhotoVideos(post);
        } else if (res['code'] == 403) {
          setState(() { _loading = false; _isPrivateBlocked = true; _privateMsg = res['msg'] ?? '该图文已被对方私密，无法查看'; });
        } else {
          debugPrint('[Detail] load failed: code=${res['code']}, msg=${res['msg']}');
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      debugPrint('[Detail] loadPost error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadData() async {
    final pp = Provider.of<PostProvider>(context, listen: false);
    final res = await pp.fetchPostById(widget.postId);
    if (mounted) {
      if (res['code'] == 200 && res['post'] != null) {
        final post = res['post'] as Post;
        setState(() { _post = post; _isFollowing = post.isFollowed; _isFan = post.isFan; _loading = false; });
        _loadComments();
      } else if (res['code'] == 403) {
        setState(() { _loading = false; _isPrivateBlocked = true; _privateMsg = res['msg'] ?? '该图文已被对方私密，无法查看'; });
      } else {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadComments() async {
    if (_commentsLoading) return;
    setState(() => _commentsLoading = true);
    final pp = Provider.of<PostProvider>(context, listen: false);
    final r = await pp.fetchComments(widget.postId, _commentPage, 20, _commentSort);
    if (mounted) {
      final List<Comment> newComments = r['comments'] as List<Comment>;
      final int total = r['total'] as int? ?? 0;
      setState(() {
        if (newComments.isNotEmpty) {
          if (_commentPage == 1) { _comments = newComments; } else { _comments.addAll(newComments); }
        }
        _noMoreComments = _comments.length >= total;
        _commentsLoading = false;
      });
      if (widget.highlightCommentId != null && _commentPage == 1) {
        _scrollToCommentById(widget.highlightCommentId!);
      }
    }
  }

  void _scrollToCommentById(int commentId) {
    _highlightCommentId = commentId;
    _highlightCtrl.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final key = _commentKeys[commentId];
      if (key?.currentContext != null) {
        final box = key!.currentContext!.findRenderObject() as RenderBox;
        final scrollBox = _scrollCtrl.position.context.storageContext.findRenderObject() as RenderBox;
        final offset = box.localToGlobal(Offset.zero, ancestor: scrollBox).dy + _scrollCtrl.offset;
        final viewH = _scrollCtrl.position.viewportDimension;
        final target = (offset - viewH * 0.3).clamp(0.0, _scrollCtrl.position.maxScrollExtent);
        _scrollCtrl.animateTo(target, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;
    final was = _post!.isLiked;
    setState(() => _post = _post!.copyWith(isLiked: !was, likesCount: was ? _post!.likesCount - 1 : _post!.likesCount + 1));
    if (!was) _likeBounceCtrl.forward(from: 0);
    await Provider.of<PostProvider>(context, listen: false).toggleLike(widget.postId);
  }

  Future<void> _toggleCollect() async {
    if (_post == null) return;
    final was = _post!.isCollected;
    setState(() => _post = _post!.copyWith(isCollected: !was, collectsCount: was ? _post!.collectsCount - 1 : _post!.collectsCount + 1));
    if (!was) _collectBounceCtrl.forward(from: 0);
    await Provider.of<PostProvider>(context, listen: false).toggleCollect(widget.postId);
  }

  void _toggleFollow() {
    if (_post == null) return;
    final up = Provider.of<UserProvider>(context, listen: false);
    up.followUser(_post!.userId).then((res) {
      if (res['code'] == 200 && mounted) {
        final followed = res['data']?['followed'] as bool? ?? !_isFollowing;
        final isFan = res['data']?['is_fan'] as bool? ?? _isFan;
        setState(() {
          _isFollowing = followed;
          _isFan = isFan;
        });
      }
    });
  }

  Future<void> _toggleVoice(int idx, String url) async {
    if (_playingVoiceIdx == idx) {
      await _audioPlayer?.stop();
      setState(() { _playingVoiceIdx = -1; _voiceLoading = false; _voiceWaveCtrl.stop(); });
      return;
    }
    await _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _audioPlayer = AudioPlayer();
    setState(() { _playingVoiceIdx = idx; _voiceLoading = true; });
    try {
      await _audioPlayer!.play(UrlSource(fullUrl(url)));
      if (mounted) setState(() { _voiceLoading = false; _voiceWaveCtrl.repeat(); });
    } catch (_) {
      if (mounted) setState(() { _playingVoiceIdx = -1; _voiceLoading = false; });
      return;
    }
    _audioPlayer!.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playingVoiceIdx = -1; _voiceLoading = false; _voiceWaveCtrl.stop(); });
    });
  }

  void _toggleStack(int blockIdx) {
    setState(() { _stackExpanded[blockIdx] = !(_stackExpanded[blockIdx] ?? false); });
  }

  void _openGallery(List<String> urls, int initialIndex, {String? liveVideoUrl}) {
    _dismissKeyboard();
    ImagePreview.open(context, url: fullUrl(urls[initialIndex]), liveVideoUrl: liveVideoUrl);
  }

  void _setReplyTo(Comment c, {int? parentId, int? replyToUserId}) {
    setState(() {
      _isEditing = true;
      _replyToComment = c;
      _replyParentId = parentId ?? c.id;
      _replyToUserId = replyToUserId ?? c.userId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _commentFocusNode.requestFocus();
    });
  }

  void _scrollToCommentArea() {
    if (!_scrollCtrl.hasClients) return;
    final offset = _scrollCtrl.position.maxScrollExtent;
    _scrollCtrl.animateTo(offset.clamp(0, offset), duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  Future<void> _submitComment() async {
    if (_isSubmitting) return;
    final c = _commentCtrl.text.trim();
    if (c.isEmpty && _commentImages.isEmpty && _commentVoicePath == null) return;
    setState(() => _isSubmitting = true);
    final pp = Provider.of<PostProvider>(context, listen: false);
    final imageStr = _commentImages.isNotEmpty ? _commentImages.join(',') : '';

    String? voiceUrl;
    int voiceDuration = _commentVoiceDuration;
    if (_commentVoicePath != null) {
      voiceUrl = await pp.uploadFile(_commentVoicePath!);
      if (voiceUrl == null && mounted) {
        setState(() => _isSubmitting = false);
        AppToast.error(context, message: '语音上传失败');
        return;
      }
    }

    final res = await pp.addComment(
      postId: widget.postId,
      content: c,
      parentId: _replyParentId,
      imageUrl: imageStr,
      voiceUrl: voiceUrl ?? '',
      voiceDuration: voiceDuration,
      replyToUserId: _replyToUserId,
    );
    if (res['code'] == 200 && mounted) {
      _commentCtrl.clear();
      _inputText.value = '';
      final newId = res['data']?['id'] as int? ?? 0;
      final newLocation = res['data']?['location'] as String? ?? '';
      final up = Provider.of<UserProvider>(context, listen: false);
      final newComment = Comment(
        id: newId,
        postId: widget.postId,
        userId: up.userInfo?.id ?? 0,
        parentId: _replyParentId ?? 0,
        replyToUserId: _replyToUserId ?? 0,
        replyToNickname: _replyToComment?.nickname ?? '',
        content: c,
        imageUrl: imageStr,
        voiceUrl: voiceUrl ?? '',
        voiceDuration: voiceDuration,
        nickname: up.userInfo?.nickname ?? '',
        avatar: up.userInfo?.avatar ?? '',
        location: newLocation,
        createdAt: DateTime.now().toIso8601String(),
      );

      // Dismiss keyboard & restore normal state
      _commentFocusNode.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');

      final savedParentId = _replyParentId;
      setState(() {
        _isEditing = false;
        _commentImages = [];
        _commentVoicePath = null;
        _commentVoiceDuration = 0;
        _replyToComment = null;
        _replyParentId = null;
        _replyToUserId = null;
        _isSubmitting = false;
        _highlightCommentId = newId;

        if (savedParentId != null && savedParentId > 0) {
          // Reply: rebuild parent comment with new subComment
          _comments = _comments.map((pc) {
            if (pc.id == savedParentId) {
              _subExpanded[pc.id] = true;
              return Comment(
                id: pc.id, postId: pc.postId, userId: pc.userId,
                parentId: pc.parentId, content: pc.content, imageUrl: pc.imageUrl,
                likesCount: pc.likesCount, status: pc.status, location: pc.location,
                isPinned: pc.isPinned, isLiked: pc.isLiked, nickname: pc.nickname,
                avatar: pc.avatar, createdAt: pc.createdAt,
                subComments: [...pc.subComments, newComment],
              );
            }
            return pc;
          }).toList();
        } else {
          // Top-level comment
          _comments = [..._comments, newComment];
        }

        if (_post != null) {
          _post = _post!.copyWith(commentsCount: _post!.commentsCount + 1);
        }
      });

      // Start highlight animation
      _highlightCtrl.forward(from: 0);

      AppToast.success(context, message: '评论成功');
      // Scroll to new comment after layout rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollCtrl.hasClients) return;
        final key = _commentKeys[newId];
        if (key?.currentContext != null) {
          final box = key!.currentContext!.findRenderObject() as RenderBox;
          final scrollBox = _scrollCtrl.position.context.storageContext.findRenderObject() as RenderBox;
          final offset = box.localToGlobal(Offset.zero, ancestor: scrollBox).dy + _scrollCtrl.offset;
          final viewH = _scrollCtrl.position.viewportDimension;
          final target = (offset - viewH * 0.3).clamp(0.0, _scrollCtrl.position.maxScrollExtent);
          _scrollCtrl.animateTo(target, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        } else {
          final target = _scrollCtrl.position.maxScrollExtent;
          _scrollCtrl.animateTo(target.clamp(0, target), duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        }
      });
    } else if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _toggleCommentLike(Comment c) async {
    final was = c.isLiked;
    setState(() {
      c.isLiked = !was;
      c.likesCount = was ? c.likesCount - 1 : c.likesCount + 1;
    });
    if (!was) {
      _commentLikeCtrls.putIfAbsent(c.id, () => AnimationController(vsync: this, duration: const Duration(milliseconds: 350)));
      _commentLikeCtrls[c.id]?.forward(from: 0);
    }
    await Provider.of<PostProvider>(context, listen: false).toggleCommentLike(c.id);
  }

  Future<void> _pickCommentImage() async {
    final imgPath = await ImagePickerUtil.pickSingleImage(context);
    if (imgPath == null) return;
    setState(() { _imageUploading = true; });
    final pp = Provider.of<PostProvider>(context, listen: false);
    final url = await pp.uploadImage(imgPath);
    if (url != null && mounted) {
      setState(() { _commentImages.add(url); _imageUploading = false; });
    } else if (mounted) {
      setState(() { _imageUploading = false; });
      AppToast.error(context, message: '图片上传失败');
    }
  }

  Timer? _commentRecTimer;
  final AudioRecorder _commentRecorder = AudioRecorder();

  Future<void> _startCommentRecording() async {
    try {
      if (!await _commentRecorder.hasPermission()) return;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/comment_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _commentRecorder.start(const RecordConfig(), path: path);
      setState(() {
        _isCommentRecording = true;
        _commentRecordSeconds = 0;
        _commentVoicePath = null;
        _commentVoiceDuration = 0;
      });
      _commentRecTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _commentRecordSeconds++);
      });
    } catch (e) {
      if (mounted) AppToast.error(context, message: '录音失败');
    }
  }

  Future<void> _stopCommentRecording() async {
    _commentRecTimer?.cancel();
    final path = await _commentRecorder.stop();
    setState(() {
      _isCommentRecording = false;
      _commentVoicePath = path;
      _commentVoiceDuration = _commentRecordSeconds;
    });
  }

  void _removeCommentVoice() {
    _audioPlayer?.stop();
    setState(() {
      _commentVoicePath = null;
      _commentVoiceDuration = 0;
      _isPreviewingCommentVoice = false;
    });
  }

  Future<void> _previewCommentVoice(String path) async {
    if (_isPreviewingCommentVoice) {
      await _audioPlayer?.stop();
      setState(() => _isPreviewingCommentVoice = false);
      return;
    }
    setState(() => _commentVoiceLoading = true);
    try {
      _audioPlayer?.dispose();
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.play(DeviceFileSource(path));
      if (mounted) setState(() { _isPreviewingCommentVoice = true; _commentVoiceLoading = false; });
      _audioPlayer!.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _isPreviewingCommentVoice = false);
      });
    } catch (e) {
      if (mounted) { setState(() { _commentVoiceLoading = false; _isPreviewingCommentVoice = false; }); AppToast.error(context, message: '播放失败'); }
    }
  }

  Future<void> _playCommentVoice(String url) async {
    final voiceUrl = url.startsWith('http') ? url : fullUrl(url);
    if (_playingCommentVoiceIdx >= 0) {
      await _audioPlayer?.stop();
      _audioPlayer?.dispose();
      _audioPlayer = null;
      setState(() { _playingCommentVoiceIdx = -1; _commentVoiceLoading = false; });
      return;
    }
    _audioPlayer?.dispose();
    _audioPlayer = AudioPlayer();
    setState(() { _playingCommentVoiceIdx = url.hashCode; _commentVoiceLoading = true; });
    try {
      await _audioPlayer!.play(UrlSource(voiceUrl));
      if (mounted) setState(() => _commentVoiceLoading = false);
      _audioPlayer!.onPlayerComplete.listen((_) {
        if (mounted) {
          _audioPlayer?.dispose();
          _audioPlayer = null;
          setState(() { _playingCommentVoiceIdx = -1; _commentVoiceLoading = false; });
        }
      });
    } catch (e) {
      if (mounted) {
        _audioPlayer?.dispose();
        _audioPlayer = null;
        setState(() { _playingCommentVoiceIdx = -1; _commentVoiceLoading = false; });
        AppToast.error(context, message: '播放失败');
      }
    }
  }

  void _onCommentTextChanged(String text) {
    // Auto-show mention picker when user types @ followed by a letter
    if (text.endsWith('@')) {
      Future.delayed(const Duration(milliseconds: 200), _showMentionPicker);
    }
  }

  void _showMentionPicker() {
    final ctrl = TextEditingController();
    List<Map<String, dynamic>> users = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (ctx) {
        return StatefulBuilder(builder: (_, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.55,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            child: Column(children: [
              Container(width: 32, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '搜索用户',
                    hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF999999)),
                    suffixIcon: searching ? const Padding(padding: EdgeInsets.all(12), child: CupertinoActivityIndicator(radius: 8)) : null,
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (q) async {
                    if (q.trim().isEmpty) {
                      setModalState(() => users = []);
                      return;
                    }
                    setModalState(() => searching = true);
                    final pp = Provider.of<PostProvider>(context, listen: false);
                    final results = await pp.searchUsers(q.trim());
                    setModalState(() { users = results; searching = false; });
                  },
                ),
              ),
              Expanded(child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (_, i) {
                  final u = users[i];
                  final av = fullUrl(u['avatar'] as String? ?? '');
                  final name = u['nickname'] as String? ?? u['username'] as String? ?? '';
                  return ListTile(
                    leading: av.isNotEmpty
                      ? CircleAvatar(radius: 18, backgroundImage: CachedNetworkImageProvider(av))
                      : CircleAvatar(radius: 18, backgroundColor: getColorForId(u['id'] as int?), child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 12, color: Colors.white))),
                    title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text('@${u['username'] as String? ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                    onTap: () {
                      Navigator.pop(ctx);
                      // Insert @username into comment text
                      final uname = u['username'] as String? ?? u['nickname'] as String? ?? '';
                      final text = _commentCtrl.text;
                      final atIdx = text.lastIndexOf('@');
                      if (atIdx >= 0) {
                        _commentCtrl.text = '${text.substring(0, atIdx)}@$uname ';
                      } else {
                        _commentCtrl.text = '$text@$uname ';
                      }
                      _commentCtrl.selection = TextSelection.collapsed(offset: _commentCtrl.text.length);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _commentFocusNode.requestFocus();
                      });
                    },
                  );
                },
              )),
            ]),
          );
        });
      },
    );
  }



  void _showCommentActionSheet(Comment c) {
    _dismissKeyboard();
    final up = Provider.of<UserProvider>(context, listen: false);
    final isPostAuthor = _post?.userId == up.userInfo?.id;
    final isCommentMine = c.userId == up.userInfo?.id;
    final isAdmin = up.userInfo?.role == 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 32, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                  Expanded(child: _actionItem(Icons.copy_outlined, '复制', const Color(0xFF333333), () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: c.content));
                    AppToast.success(context, message: '已复制');
                  })),
                  if (isPostAuthor)
                    Expanded(child: _actionItem(c.isPinned == 1 ? Icons.push_pin : Icons.push_pin_outlined, c.isPinned == 1 ? '取消置顶' : '置顶', const Color(0xFF333333), () {
                      Navigator.pop(context);
                      _showXhsConfirm('确定${c.isPinned == 1 ? '取消置顶' : '置顶'}这条评论吗？', onConfirm: () async {
                        _showActionLoading();
                        final pp = Provider.of<PostProvider>(context, listen: false);
                        final res = await pp.pinComment(c.id);
                        _dismissActionLoading();
                        Navigator.pop(context);
                        if (res['code'] == 200 && mounted) {
                          setState(() { _commentPage = 1; _noMoreComments = false; });
                          _loadComments();
                          AppToast.success(context, message: res['msg'] ?? '操作成功');
                        }
                      });
                    })),
                  if (isPostAuthor || isCommentMine || isAdmin)
                    Expanded(child: _actionItem(Icons.delete_outline, '删除', const Color(0xFFFF2442), () {
                      Navigator.pop(context);
                      _showXhsConfirm('确定删除这条评论吗？', onConfirm: () async {
                        _showActionLoading();
                        final pp = Provider.of<PostProvider>(context, listen: false);
                        final res = await pp.deleteComment(c.id);
                        _dismissActionLoading();
                        Navigator.pop(context);
                        if (res['code'] == 200 && mounted) {
                          setState(() {
                            _comments = _comments.where((x) => x.id != c.id).toList();
                            _comments = _comments.map((pc) => Comment(
                              id: pc.id, postId: pc.postId, userId: pc.userId,
                              parentId: pc.parentId, content: pc.content, imageUrl: pc.imageUrl,
                              likesCount: pc.likesCount, status: pc.status, location: pc.location,
                              isPinned: pc.isPinned, isLiked: pc.isLiked, nickname: pc.nickname,
                              avatar: pc.avatar, createdAt: pc.createdAt,
                              subComments: pc.subComments.where((s) => s.id != c.id).toList(),
                            )).toList();
                            if (_post != null) _post = _post!.copyWith(commentsCount: _post!.commentsCount - 1);
                          });
                          AppToast.success(context, message: '已删除');
                        }
                      });
                    })),
                ],
              ),
            ),
            const Divider(height: 0.5, color: Color(0xFFF0F0F0)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                child: const Text('取消', style: TextStyle(fontSize: 16, color: Color(0xFF666666), fontWeight: FontWeight.w500)),
              ),
            ),
          ]),
        ),
      );
  }

  Widget _actionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  void _showXhsConfirm(String message, {required VoidCallback onConfirm}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 32, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 20), child: Text(message, style: const TextStyle(fontSize: 16, color: Color(0xFF333333), fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
            const Divider(height: 0.5, color: Color(0xFFF0F0F0)),
            Row(children: [
              Expanded(child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: Container(height: 50, alignment: Alignment.center, child: const Text('取消', style: TextStyle(fontSize: 16, color: Color(0xFF666666), fontWeight: FontWeight.w400))),
              )),
              Container(width: 0.5, height: 50, color: const Color(0xFFF0F0F0)),
              Expanded(child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onConfirm,
                child: Container(height: 50, alignment: Alignment.center, child: const Text('确定', style: TextStyle(fontSize: 16, color: Color(0xFFFF2442), fontWeight: FontWeight.w600))),
              )),
            ]),
          ]),
        ),
      );
  }

  void _showPostMenu() {
    // Ensure keyboard is dismissed and editing state is cleared
    _commentFocusNode.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    setState(() {
      _isEditing = false;
      _replyToComment = null;
      _replyParentId = null;
      _replyToUserId = null;
    });
    if (_post == null) return;
    final up = Provider.of<UserProvider>(context, listen: false);
    final isAuthor = _post!.userId == up.userInfo?.id;
    final isAdmin = up.userInfo?.role == 1;

    if (!isAuthor && !isAdmin) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 32, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                  if (isAuthor) Expanded(child: _actionItem(Icons.edit_outlined, '编辑', const Color(0xFF333333), () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/publish', arguments: _post).then((result) {
                      if (result == true && mounted) {
                        setState(() { _loading = true; });
                        _loadPost();
                      }
                    });
                  })),
                  if (isAuthor) Expanded(child: _actionItem(
                    _post!.isPrivate == 1 ? Icons.lock_open_outlined : Icons.lock_outline,
                    _post!.isPrivate == 1 ? '公开' : '私密',
                    const Color(0xFFFF9800),
                    () {
                      Navigator.pop(context);
                      final msg = _post!.isPrivate == 1 ? '确定将此笔记设为公开吗？' : '设为私密后，仅自己可见，确定吗？';
                      _showXhsConfirm(msg, onConfirm: () async {
                        _showActionLoading();
                        final pp = Provider.of<PostProvider>(context, listen: false);
                        final res = await pp.togglePrivate(widget.postId);
                        _dismissActionLoading();
                        Navigator.pop(context);
                        if (res['code'] == 200 && mounted) {
                          setState(() { _post = _post!.copyWith(isPrivate: _post!.isPrivate == 1 ? 0 : 1); });
                          AppToast.success(context, message: res['msg'] ?? '操作成功');
                        }
                      });
                    },
                  )),
                  if (isAdmin && _post!.categoryId > 0) Expanded(child: _actionItem(
                    _post!.isPinned == 1 ? Icons.push_pin : Icons.push_pin_outlined,
                    _post!.isPinned == 1 ? '取消置顶' : '置顶',
                    const Color(0xFF3378E5),
                    () {
                      Navigator.pop(context);
                      _showXhsConfirm('${_post!.isPinned == 1 ? '取消置顶' : '置顶'}此笔记？', onConfirm: () async {
                        _showActionLoading();
                        final pp = Provider.of<PostProvider>(context, listen: false);
                        final res = await pp.pinPost(widget.postId, _post!.categoryId);
                        _dismissActionLoading();
                        Navigator.pop(context);
                        if (res['code'] == 200 && mounted) {
                          setState(() { _post = _post!.copyWith(isPinned: _post!.isPinned == 1 ? 0 : 1); });
                          AppToast.success(context, message: res['msg'] ?? '操作成功');
                        }
                      });
                    },
                  )),
                  if (isAuthor) Expanded(child: _actionItem(Icons.delete_outline, '删除', const Color(0xFFFF2442), () {
                    Navigator.pop(context);
                    _showXhsConfirm('删除后将无法恢复，确定删除吗？', onConfirm: () async {
                      _showActionLoading();
                      final pp = Provider.of<PostProvider>(context, listen: false);
                      final res = await pp.deletePost(widget.postId);
                      _dismissActionLoading();
                      if (res['code'] == 200 && mounted) {
                        Navigator.pop(context); // dismiss confirm dialog
                        Navigator.pop(context, true); // dismiss detail screen
                        AppToast.success(context, message: '已删除');
                      }
                    });
                  })),
                ],
              ),
            ),
            const Divider(height: 0.5, color: Color(0xFFF0F0F0)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity, height: 50, alignment: Alignment.center,
                child: const Text('取消', style: TextStyle(fontSize: 16, color: Color(0xFF666666), fontWeight: FontWeight.w500)),
              ),
            ),
          ]),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final sbh = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
        ? const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442)))
        : _isPrivateBlocked
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline, size: 48, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 16),
            Text(_privateMsg, style: const TextStyle(fontSize: 15, color: Color(0xFF999999)), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(20)), child: const Text('返回', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)))),
          ]))
        : GestureDetector(
          onTap: _dismissKeyboard,
          child: Stack(children: [
            CustomScrollView(controller: _scrollCtrl, slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  _commentPage = 1;
                  _comments = [];
                  await _loadData();
                },
              ),
              SliverAppBar(
                pinned: true,
                floating: false,
                elevation: _titlePinned ? 0.5 : 0,
                backgroundColor: Colors.white,
                leadingWidth: 46,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF222222)),
                  ),
                ),
                titleSpacing: 0,
                title: _titlePinned && _post != null
                  ? Row(children: [
                      if (_post!.isPrivate == 1) ...[const Icon(Icons.lock_outline, size: 14, color: Color(0xFF999999)), const SizedBox(width: 4)],
                      Expanded(child: Text(
                        _post!.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                    ])
                  : null,
                actions: [
                  Consumer<UserProvider>(builder: (_, up, __) {
                    final isAuthor = _post?.userId == up.userInfo?.id;
                    final isAdmin = up.userInfo?.role == 1;
                    if (!isAuthor && !isAdmin) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: _showPostMenu,
                      child: const Padding(padding: EdgeInsets.only(right: 14), child: Icon(Icons.more_vert, size: 22, color: Color(0xFF555555))),
                    );
                  }),
                ],
                expandedHeight: sbh + 44,
                flexibleSpace: FlexibleSpaceBar(background: Container(padding: EdgeInsets.only(top: sbh), color: Colors.white)),
              ),
              if (_post != null) ...[
                SliverToBoxAdapter(child: _authorBar()),
                if (_post!.postType != 1) SliverToBoxAdapter(child: _title()),
                SliverToBoxAdapter(child: _content()),
                if (_post!.postType != 1) SliverToBoxAdapter(child: _tagRow()),
                SliverToBoxAdapter(child: _dateRow()),
                SliverToBoxAdapter(child: Container(height: 8, color: const Color(0xFFF5F5F5))),
                SliverToBoxAdapter(child: _commentHeader()),
                SliverList(delegate: SliverChildBuilderDelegate((_, i) {
                  if (i < _comments.length) return _buildCommentItem(_comments[i]);
                  if (!_noMoreComments) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CupertinoActivityIndicator(radius: 8)));
                  }
                  return const SizedBox.shrink();
                }, childCount: _comments.length + (_noMoreComments ? 0 : 1))),
                if (_comments.isEmpty)
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('还没有评论，来说点什么吧～', style: TextStyle(fontSize: 13, color: Color(0xFFCCCCCC)))))),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 70)),
            ]),
            // Dark overlay when editing
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isEditing,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  opacity: _isEditing ? 1.0 : 0.0,
                  child: GestureDetector(
                    onTap: _dismissKeyboard,
                    child: Container(color: Colors.black.withValues(alpha: 0.35)),
                  ),
                ),
              ),
            ),
            // Bottom bar on top of overlay
            Positioned(bottom: 0, left: 0, right: 0, child: _bottomBar()),
          ]),
        ),
    );
  }

  Widget _authorBar() {
    if (_post == null) return const SizedBox.shrink();
    final a = fullUrl(_post!.avatar);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            final u = Provider.of<UserProvider>(context, listen: false);
            if (_post!.userId != u.userInfo?.id) Navigator.pushNamed(context, '/user-profile', arguments: _post!.userId);
          },
          child: a.isNotEmpty
            ? CircleAvatar(radius: 18, backgroundImage: CachedNetworkImageProvider(a))
            : CircleAvatar(radius: 18, backgroundColor: getColorForId(_post!.userId), child: Text(_post!.nickname.isNotEmpty ? _post!.nickname[0] : '?', style: const TextStyle(fontSize: 14, color: Colors.white))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_post!.nickname, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
            if (_post!.isPrivate == 1) ...[const SizedBox(width: 6), const Icon(Icons.lock_outline, size: 13, color: Color(0xFF999999))],
          ]),
          Padding(padding: const EdgeInsets.only(top: 2), child: Text(fmtTime(_post!.createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)))),
        ])),
        Consumer<UserProvider>(builder: (_, up, _) {
          if (_post!.userId == up.userInfo?.id) return const SizedBox.shrink();
          return GestureDetector(
            onTap: _toggleFollow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: _isFollowing ? null : const LinearGradient(colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)]),
                color: _isFollowing ? const Color(0xFFF5F5F5) : null,
                borderRadius: BorderRadius.circular(12),
                border: _isFollowing ? Border.all(color: const Color(0xFFE8E8E8), width: 0.5) : null,
              ),
              child: Text(
                _isFollowing && _isFan ? '互关' : (_isFollowing ? '已关注' : (_isFan ? '回关' : '+ 关注')),
                style: TextStyle(fontSize: 12, color: _isFollowing ? const Color(0xFF999999) : Colors.white, fontWeight: _isFollowing ? FontWeight.w400 : FontWeight.w600),
              ),
            ),
          );
        }),
      ]),
    );
  }

  Widget _title() {
    if (_post == null || _post!.title.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.fromLTRB(12, 2, 12, 0), child: Text(_post!.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222), height: 1.5)));
  }

  Widget _content() {
    if (_post == null) return const SizedBox.shrink();
    if (_post!.postType == 1 && _post!.content.isNotEmpty) return _textCard();
    List<Widget> ch = [];
    if (_post!.contentBlocks.isNotEmpty) {
      for (int i = 0; i < _post!.contentBlocks.length; i++) {
        try {
          ch.add(_block(_post!.contentBlocks[i], i));
        } catch (_) {}
      }
    } else {
      if (_post!.content.isNotEmpty) ch.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: _buildLinkableText(_post!.content, style: const TextStyle(fontSize: 15, color: Color(0xFF333333), height: 2.0))));
      if (_post!.images.isNotEmpty) {
        final imgs = _post!.images.where((x) => x.url.isNotEmpty).toList();
        if (imgs.isNotEmpty) ch.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: _imgLayout(imgs, imgs.length == 1 ? 'full' : 'grid', -1)));
      }
      if (_post!.voiceUrl.isNotEmpty) ch.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: _voiceBlock(0, _post!.voiceDuration, _post!.voiceUrl)));
      if (_post!.link.isNotEmpty) ch.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: _linkBoxWidget(_post!.link)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: ch);
  }

  Widget _block(ContentBlock b, int blockIdx) {
    if (b.type == 'text' && b.content.isNotEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: _buildLinkableText(b.content, style: const TextStyle(fontSize: 15, color: Color(0xFF333333), height: 2.0)));
    }
    if (b.type == 'images' || b.type == 'image') {
      final imgs = b.images.map((e) => PostImage.fromJson(e)).where((x) => x.url.isNotEmpty).toList();
      if (imgs.isNotEmpty) return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: _imgLayout(imgs, b.layout.isEmpty ? 'grid' : b.layout, blockIdx));
    }
    if (b.type == 'voice') {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: _voiceBlock(blockIdx, b.duration, b.url));
    }
    if (b.type == 'link' && b.url.isNotEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: _linkBoxWidget(b.url));
    }
    return const SizedBox.shrink();
  }

  Widget _textCard() {
    final i = _post!.textTemplate.clamp(0, 7);
    final g = _tGrad[i];
    final tc = _tClr[i];
    final dateStr = _formatDate(_post!.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(minHeight: 210),
      decoration: BoxDecoration(
        gradient: g.length > 1 ? LinearGradient(colors: g, begin: Alignment(-1, -1), end: Alignment(1, 1)) : null,
        color: g.length == 1 ? g.first : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Text(dateStr, style: TextStyle(fontSize: 14, color: tc.withValues(alpha: 0.6), fontWeight: FontWeight.w500, height: 1.5))),
        if (_post!.title.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Text(_post!.title, textAlign: TextAlign.left, style: TextStyle(fontSize: 22, color: tc, fontWeight: FontWeight.w700, height: 1.4))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: _buildLinkableText(_post!.content, style: TextStyle(fontSize: 15, color: tc.withValues(alpha: 0.85), height: 1.8), textAlign: TextAlign.left)),
        if (_post!.link.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), child: _innerLinkCard(_post!.link, tc))
        else
          const SizedBox(height: 20),
      ]),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day},\n${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _innerLinkCard(String url, Color textColor) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/browser', arguments: {'url': url}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: textColor.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Row(children: [
          Icon(Icons.link, size: 14, color: textColor.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(child: Text(url, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Icon(Icons.open_in_new, size: 12, color: textColor.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  Widget _imgLayout(List<PostImage> imgs, String l, int blockIdx) {
    if (imgs.isEmpty) return const SizedBox.shrink();
    final urls = imgs.map((e) => e.url).toList();
    if (l == 'full' || imgs.length == 1) {
      return Column(children: imgs.asMap().entries.map((e) => _livePhotoWrapper(e.value, urls, e.key, isFull: true)).toList());
    }
    if (l == 'double') {
      return Wrap(spacing: 3, runSpacing: 3, children: imgs.asMap().entries.map((e) => _livePhotoWrapper(e.value, urls, e.key, isDouble: true)).toList());
    }
    if (l == 'stack') return _stackLayout(urls, blockIdx);
    final w = MediaQuery.of(context).size.width - 24;
    final s = (w - 6) / 3;
    return Wrap(spacing: 3, runSpacing: 3, children: imgs.asMap().entries.take(9).map((e) => _livePhotoWrapper(e.value, urls, e.key, gridSize: s)).toList());
  }

  Widget _livePhotoWrapper(PostImage img, List<String> allUrls, int index, {bool isFull = false, bool isDouble = false, double? gridSize}) {
    final isLive = img.videoUrl.isNotEmpty;
    final ratio = img.ratio > 0 ? img.ratio : 1.2;
    final isPlaying = _livePhotoPlaying && _livePhotoUrl == img.videoUrl;
    Widget imageWidget;
    if (isFull) {
      final w = MediaQuery.of(context).size.width - 24;
      imageWidget = ClipRRect(borderRadius: BorderRadius.circular(6), child: CachedNetworkImage(imageUrl: fullUrl(img.url), width: w, height: w / ratio, fit: BoxFit.cover, memCacheWidth: (w * 2).toInt()));
    } else if (isDouble) {
      imageWidget = FractionallySizedBox(widthFactor: 0.495, child: AspectRatio(aspectRatio: 1, child: ClipRRect(borderRadius: BorderRadius.circular(6), child: CachedNetworkImage(imageUrl: fullUrl(img.url), fit: BoxFit.cover, memCacheWidth: 400))));
    } else if (gridSize != null) {
      imageWidget = ClipRRect(borderRadius: BorderRadius.circular(6), child: CachedNetworkImage(imageUrl: fullUrl(img.url), width: gridSize, height: gridSize, fit: BoxFit.cover, memCacheWidth: gridSize.toInt()));
    } else {
      imageWidget = ClipRRect(borderRadius: BorderRadius.circular(6), child: CachedNetworkImage(imageUrl: fullUrl(img.url), fit: BoxFit.cover, memCacheWidth: 400));
    }

    if (!isLive) {
      return GestureDetector(
        onTap: () => _openGallery(allUrls, index),
        onLongPress: () => _showImageSaveDialog(img.url),
        child: isFull ? Padding(padding: const EdgeInsets.only(bottom: 4), child: imageWidget) : imageWidget,
      );
    }

    Widget videoOverlay = const SizedBox.shrink();
    if (isPlaying && _livePhotoCtrl != null && _livePhotoCtrl!.value.isInitialized) {
      videoOverlay = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _livePhotoCtrl!.value.size.width,
            height: _livePhotoCtrl!.value.size.height,
            child: VideoPlayer(_livePhotoCtrl!),
          ),
        ),
      );
    }

    if (isFull) {
      final w = MediaQuery.of(context).size.width - 24;
      return GestureDetector(
        onTap: () => _openGallery(allUrls, index, liveVideoUrl: img.videoUrl),
        onLongPress: () => _showImageSaveDialog(img.url),
        child: Padding(padding: const EdgeInsets.only(bottom: 4), child: SizedBox(
          width: w,
          height: w / ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageWidget,
              if (isPlaying) videoOverlay,
              Positioned(left: 8, bottom: 8, child: GestureDetector(
                onTap: () {
                  if (isPlaying) _stopLivePhoto();
                  else _playLivePhoto(img.videoUrl);
                },
                child: _liveBadge(),
              )),
            ],
          ),
        )),
      );
    }

    return GestureDetector(
      onTap: () => _openGallery(allUrls, index, liveVideoUrl: img.videoUrl),
      onLongPress: () => _showImageSaveDialog(img.url),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          if (isPlaying) videoOverlay,
          Positioned(left: 4, bottom: 4, child: GestureDetector(
            onTap: () {
              if (isPlaying) _stopLivePhoto();
              else _playLivePhoto(img.videoUrl);
            },
            child: _liveBadge(small: true),
          )),
        ],
      ),
    );
  }

  void _showImageSaveDialog(String imageUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 32, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Expanded(child: _actionItem(Icons.save_alt, '保存图片', const Color(0xFF333333), () {
                Navigator.pop(ctx);
                _saveImage(imageUrl);
              })),
            ]),
          ),
          const Divider(height: 0.5, color: Color(0xFFF0F0F0)),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(ctx),
            child: Container(
              width: double.infinity,
              height: 50,
              alignment: Alignment.center,
              child: const Text('取消', style: TextStyle(fontSize: 16, color: Color(0xFF666666), fontWeight: FontWeight.w500)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _saveImage(String imageUrl) async {
    if (_isSavingImage) return;
    setState(() => _isSavingImage = true);
    _showActionLoading();
    try {
      final url = fullUrl(imageUrl);
      final response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/liubi_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(Uint8List.fromList(response.data));
      await Gal.putImage(filePath, album: '留笔');
      _dismissActionLoading();
      if (mounted) {
        AppToast.success(context, message: '已保存到相册');
      }
      try { await file.delete(); } catch (_) {}
    } catch (e) {
      _dismissActionLoading();
      if (mounted) AppToast.error(context, message: '保存失败');
    } finally {
      if (mounted) setState(() => _isSavingImage = false);
    }
  }

  Widget _liveBadge({bool small = false}) {
    final isPlaying = _livePhotoPlaying;
    final isLoading = _livePhotoLoading;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 4 : 6, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: isLoading
            ? const Color(0xFFFF9800).withValues(alpha: 0.9)
            : isPlaying
            ? const Color(0xFFFF2442).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(small ? 3 : 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(width: small ? 10 : 14, height: small ? 10 : 14, child: const CupertinoActivityIndicator(radius: 5, color: Colors.white))
          else
            Image.asset('assets/icons/icon_live_photo.png', width: small ? 10 : 14, height: small ? 10 : 14, color: isPlaying ? Colors.white : null),
          SizedBox(width: small ? 2 : 3),
          Text(isLoading ? '...' : 'LIVE', style: TextStyle(fontSize: small ? 8 : 10, color: (isLoading || isPlaying) ? Colors.white : const Color(0xFF333333), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  void _preloadLivePhotoVideos(Post post) async {
    final videoUrls = <String>[];
    for (final img in post.images) {
      if (img.videoUrl.isNotEmpty && !_videoCache.containsKey(img.videoUrl)) {
        videoUrls.add(img.videoUrl);
      }
    }
    for (final block in post.contentBlocks) {
      if (block.type == 'images' || block.type == 'image') {
        for (final imgData in block.images) {
          final img = PostImage.fromJson(imgData);
          if (img.videoUrl.isNotEmpty && !_videoCache.containsKey(img.videoUrl)) {
            videoUrls.add(img.videoUrl);
          }
        }
      }
    }
    for (final url in videoUrls) {
      try {
        final ctrl = VideoPlayerController.networkUrl(Uri.parse(fullUrl(url)));
        await ctrl.initialize();
        ctrl.setLooping(false);
        if (!_videoCache.containsKey(url)) {
          _videoCache[url] = ctrl;
          if (_videoCache.length > 10) {
            final oldest = _videoCache.keys.first;
            _videoCache[oldest]?.dispose();
            _videoCache.remove(oldest);
          }
        } else {
          ctrl.dispose();
        }
      } catch (_) {}
    }
  }

  void _playLivePhoto(String videoUrl) async {
    if (_livePhotoPlaying || _livePhotoLoading) return;
    _stopLivePhoto();
    setState(() => _livePhotoLoading = true);
    _livePhotoUrl = videoUrl;

    if (_videoCache.containsKey(videoUrl)) {
      _livePhotoCtrl = _videoCache[videoUrl]!;
      _livePhotoCtrl!.setLooping(false);
      _livePhotoCtrl!.addListener(_onLivePhotoEnd);
      _livePhotoCtrl!.seekTo(Duration.zero);
      _livePhotoCtrl!.play();
      setState(() { _livePhotoPlaying = true; _livePhotoLoading = false; });
      return;
    }

    _livePhotoCtrl = VideoPlayerController.networkUrl(Uri.parse(fullUrl(videoUrl)));
    try {
      await _livePhotoCtrl!.initialize();
      _livePhotoCtrl!.setLooping(false);
      _livePhotoCtrl!.addListener(_onLivePhotoEnd);
      _videoCache[videoUrl] = _livePhotoCtrl!;
      if (_videoCache.length > 10) {
        final oldest = _videoCache.keys.first;
        _videoCache[oldest]?.dispose();
        _videoCache.remove(oldest);
      }
      _livePhotoCtrl!.play();
      if (mounted) setState(() { _livePhotoPlaying = true; _livePhotoLoading = false; });
    } catch (_) {
      _livePhotoCtrl?.dispose();
      _livePhotoCtrl = null;
      _livePhotoUrl = null;
      if (mounted) setState(() { _livePhotoPlaying = false; _livePhotoLoading = false; });
    }
  }

  void _onLivePhotoEnd() {
    if (_livePhotoCtrl != null && !_livePhotoCtrl!.value.isPlaying && _livePhotoCtrl!.value.position >= _livePhotoCtrl!.value.duration) {
      _stopLivePhoto();
    }
  }

  void _stopLivePhoto() {
    _livePhotoCtrl?.removeListener(_onLivePhotoEnd);
    _livePhotoCtrl?.pause();
    if (!_videoCache.containsKey(_livePhotoUrl)) {
      _livePhotoCtrl?.dispose();
    }
    _livePhotoCtrl = null;
    _livePhotoUrl = null;
    if ((_livePhotoPlaying || _livePhotoLoading) && mounted) {
      setState(() { _livePhotoPlaying = false; _livePhotoLoading = false; });
    }
  }

  Widget _stackLayout(List<String> u, int blockIdx) {
    final expanded = _stackExpanded[blockIdx] ?? false;
    final w = MediaQuery.of(context).size.width - 24;
    if (expanded) {
      final s = (w - 6) / 3;
      return Column(children: [
        Wrap(spacing: 3, runSpacing: 3, children: u.asMap().entries.map((e) => GestureDetector(
          onTap: () => _openGallery(u, e.key),
          child: ClipRRect(borderRadius: BorderRadius.circular(6), child: CachedNetworkImage(imageUrl: fullUrl(e.value), width: s, height: s, fit: BoxFit.cover, memCacheWidth: s.toInt())),
        )).toList()),
        const SizedBox(height: 8),
        Center(child: GestureDetector(onTap: () => _toggleStack(blockIdx), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)), child: const Text('收起', style: TextStyle(fontSize: 12, color: Color(0xFF666666)))))),
      ]);
    }
    final showCount = u.length > 3 ? 3 : u.length;
    return GestureDetector(
      onTap: () => _toggleStack(blockIdx),
      child: SizedBox(width: w, height: w * 0.7, child: Stack(clipBehavior: Clip.none, children: [
        for (int i = showCount - 1; i >= 0; i--)
          Positioned(left: i * 8.0, top: i * 4.0, child: GestureDetector(
            onTap: () => _openGallery(u, i),
            child: Container(width: w * 0.85, height: w * 0.62, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))]), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: fullUrl(u[i]), fit: BoxFit.cover, memCacheWidth: (w * 0.85).toInt())))),
          ),
        if (u.length > 3) Positioned(right: 8, bottom: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)), child: Text('${u.length}张', style: const TextStyle(fontSize: 11, color: Colors.white)))),
      ])),
    );
  }

  Widget _voiceBlock(int blockIdx, int dur, String url) {
    final isPlaying = _playingVoiceIdx == blockIdx;
    final isLoading = isPlaying && _voiceLoading;
    return GestureDetector(
      onTap: () => _toggleVoice(blockIdx, url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28, height: 28,
            decoration: const BoxDecoration(color: Color(0xFFFF2442), shape: BoxShape.circle),
            child: Center(child: isLoading
                ? const CupertinoActivityIndicator(radius: 7, color: Colors.white)
                : (isPlaying ? const Icon(Icons.pause, size: 14, color: Colors.white) : const Icon(Icons.play_arrow, size: 14, color: Colors.white))),
          ),
          const SizedBox(width: 10),
          Expanded(child: isLoading
              ? Row(mainAxisSize: MainAxisSize.min, children: List.generate(6, (i) => Container(width: 3, height: 4.0 + (i % 3) * 4.0, margin: const EdgeInsets.only(right: 3), decoration: BoxDecoration(color: const Color(0xFFFF2442).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(1.5)))))
              : AnimatedBuilder(animation: _voiceWaveCtrl, builder: (_, _) {
            return Row(mainAxisSize: MainAxisSize.min, children: List.generate(6, (i) {
              double h;
              if (isPlaying) {
                h = 4 + 14 * (0.5 + 0.5 * sin(i * 1.2 + _voiceWaveCtrl.value * 2 * pi));
              } else {
                h = 4.0 + (i % 3) * 4.0;
              }
              return Container(width: 3, height: h, margin: const EdgeInsets.only(right: 3), decoration: BoxDecoration(color: const Color(0xFFFF2442).withValues(alpha: isPlaying ? 1.0 : 0.5), borderRadius: BorderRadius.circular(1.5)));
            }));
          })),
          const SizedBox(width: 6),
          Text(fmtVoiceTime(dur), style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
        ]),
      ),
    );
  }

  Widget _linkBoxWidget(String url) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/browser', arguments: {'url': url}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE8ECF0), width: 0.5)),
        child: Row(children: [
          const Icon(Icons.link, size: 14, color: Color(0xFF3378E5)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('外部链接', style: TextStyle(fontSize: 12, color: Color(0xFF333333), fontWeight: FontWeight.w500)),
            Text(url, style: const TextStyle(fontSize: 10, color: Color(0xFF999999)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const Text('›', style: TextStyle(fontSize: 16, color: Color(0xFFCCCCCC))),
        ]),
      ),
    );
  }

  static final _emojiRegexp = emojiRegexp;

  Widget _buildLinkableText(String text, {TextStyle? style, TextAlign? textAlign}) {
    final urlMatches = _urlRegex.allMatches(text).toList();
    final emojiMatches = _emojiRegexp.allMatches(text).toList();
    final contextMenuBuilder = (_, EditableTextState editableTextState) {
      final List<ContextMenuButtonItem> items = editableTextState.contextMenuButtonItems.map((item) {
        if (item.type == ContextMenuButtonType.copy) {
          final origOnPressed = item.onPressed;
          return ContextMenuButtonItem(
            type: item.type,
            label: item.label,
            onPressed: () {
              origOnPressed?.call();
              AppToast.success(context, message: '已复制');
            },
          );
        }
        return item;
      }).toList();
      return AdaptiveTextSelectionToolbar.buttonItems(buttonItems: items, anchors: editableTextState.contextMenuAnchors);
    };

    if (urlMatches.isEmpty && emojiMatches.isEmpty) {
      return SelectableText(text, style: style, textAlign: textAlign, contextMenuBuilder: contextMenuBuilder);
    }

    final allMatches = <_TextMatch>[];
    for (final m in urlMatches) {
      allMatches.add(_TextMatch(m.start, m.end, _TextMatchType.url, m.group(0)!));
    }
    for (final m in emojiMatches) {
      allMatches.add(_TextMatch(m.start, m.end, _TextMatchType.emoji, m.group(1)!));
    }
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final m in allMatches) {
      if (m.start < lastEnd) continue;
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, m.start), style: style));
      }
      if (m.type == _TextMatchType.url) {
        spans.add(TextSpan(
          text: m.value,
          style: style?.copyWith(color: const Color(0xFFFF2442), decoration: TextDecoration.underline, decorationColor: const Color(0xFFFF2442)) ?? const TextStyle(color: Color(0xFFFF2442), decoration: TextDecoration.underline, decorationColor: Color(0xFFFF2442)),
          recognizer: TapGestureRecognizer()..onTap = () => Navigator.pushNamed(context, '/browser', arguments: {'url': m.value}),
        ));
      } else {
        final assetPath = 'assets/emojis/${m.value}';
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Image.asset(
            assetPath,
            width: 22,
            height: 22,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: const Text('😀', style: TextStyle(fontSize: 13)),
            ),
          ),
        ));
      }
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return SelectableText.rich(
      TextSpan(children: spans, style: style),
      textAlign: textAlign,
      contextMenuBuilder: contextMenuBuilder,
    );
  }

  Widget _tagRow() {
    if (_post == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(children: [
      if (_post!.categoryName.isNotEmpty) GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/category', arguments: _post!.categoryId),
        child: Text('# ${_post!.categoryName}', style: const TextStyle(fontSize: 12, color: Color(0xFF3378E5), fontWeight: FontWeight.w500)),
      ),
    ]));
  }

  Widget _dateRow() {
    if (_post == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${fmtTime(_post!.createdAt)}${_post!.location.isNotEmpty ? ' · IP属地 ${_post!.location}' : ''}', style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
      const SizedBox(height: 4),
      Text('${_post!.viewsCount} 浏览', style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
    ]));
  }

  Widget _commentHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(children: [
        Text('共 ${_post?.commentsCount ?? 0} 条评论', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
        const Spacer(),
        GestureDetector(
          onTap: () {
            setState(() {
              _commentSort = _commentSort == 'latest' ? 'hot' : 'latest';
              _commentPage = 1;
              _comments = [];
            });
            _loadComments();
          },
          child: Row(children: [
            Icon(Icons.swap_vert, size: 14, color: _commentSort == 'hot' ? const Color(0xFFFF2442) : const Color(0xFF999999)),
            const SizedBox(width: 2),
            Text(_commentSort == 'hot' ? '最热' : '最新', style: TextStyle(fontSize: 12, color: _commentSort == 'hot' ? const Color(0xFFFF2442) : const Color(0xFF999999), fontWeight: _commentSort == 'hot' ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCommentItem(Comment c) {
    final a = fullUrl(c.avatar);
    final isA = c.userId == _post?.userId;
    final highlight = _highlightCommentId == c.id;
    _commentKeys.putIfAbsent(c.id, () => GlobalKey());
    return GestureDetector(
      key: _commentKeys[c.id],
      onTap: () => _setReplyTo(c),
      onLongPress: () => _showCommentActionSheet(c),
      child: _highlightWrap(
        highlight: highlight,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(onTap: () => Navigator.pushNamed(context, '/user-profile', arguments: c.userId), child: a.isNotEmpty ? CircleAvatar(radius: 17, backgroundImage: CachedNetworkImageProvider(a)) : CircleAvatar(radius: 17, backgroundColor: getColorForId(c.userId), child: Text(c.nickname.isNotEmpty ? c.nickname[0] : '?', style: const TextStyle(fontSize: 12, color: Colors.white)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(c.nickname, style: const TextStyle(fontSize: 13, color: Color(0xFF666666), fontWeight: FontWeight.w500)),
                if (isA) ...[ const SizedBox(width: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFFFF0F3), borderRadius: BorderRadius.circular(3)), child: const Text('作者', style: TextStyle(fontSize: 9, color: Color(0xFFFF2442), fontWeight: FontWeight.w500)))],
                if (c.isPinned == 1) ...[ const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFFFF0F3), borderRadius: BorderRadius.circular(3)), child: const Text('置顶', style: TextStyle(fontSize: 9, color: Color(0xFFFF2442), fontWeight: FontWeight.w500)))],
              ]),
              if (c.content.isNotEmpty) ...[
                const SizedBox(height: 4),
                buildEmojiRichText(c.content, style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.7)),
              ],
              if (c.voiceUrl.isNotEmpty) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _playCommentVoice(c.voiceUrl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Center(
                          child: _commentVoiceLoading && _playingCommentVoiceIdx == c.voiceUrl.hashCode
                              ? const CupertinoActivityIndicator(radius: 8, color: Color(0xFFFF2442))
                              : Icon(_playingCommentVoiceIdx == c.voiceUrl.hashCode ? Icons.pause_circle : Icons.play_circle, size: 24, color: const Color(0xFFFF2442)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ...List.generate(15, (i) => Container(width: 2, height: 4 + (i % 4) * 2.0, margin: const EdgeInsets.only(right: 1.5), decoration: BoxDecoration(color: const Color(0xFFFF2442).withValues(alpha: 0.4), borderRadius: BorderRadius.circular(1)))),
                      const SizedBox(width: 6),
                      Text('${c.voiceDuration}s', style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                    ]),
                  ),
                ),
              ],
              if (c.imageUrl.isNotEmpty) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _openGallery([c.imageUrl], 0),
                  child: ClipRRect(borderRadius: BorderRadius.circular(8), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200), child: CachedNetworkImage(imageUrl: fullUrl(c.imageUrl), width: 140, fit: BoxFit.cover))),
                ),
              ],
              const SizedBox(height: 6),
              Row(children: [
                Text(fmtTime(c.createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
                if (c.location.isNotEmpty) ...[ const SizedBox(width: 6), Text(c.location, style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)))],
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _setReplyTo(c),
                  child: const Text('回复', style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w500)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _toggleCommentLike(c),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: _commentLikeCtrls.containsKey(c.id)
                      ? AnimatedBuilder(
                          animation: _commentLikeCtrls[c.id]!,
                          builder: (_, child) => Transform.scale(scale: _bounceScale(_commentLikeCtrls[c.id]!.value), child: child),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(c.isLiked ? Icons.favorite : Icons.favorite_border, size: 14, color: c.isLiked ? const Color(0xFFFF2442) : const Color(0xFFCCCCCC)),
                            const SizedBox(width: 2),
                            if (c.likesCount > 0) Text('${c.likesCount}', style: TextStyle(fontSize: 11, color: c.isLiked ? const Color(0xFFFF2442) : const Color(0xFFCCCCCC))),
                          ]),
                        )
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(c.isLiked ? Icons.favorite : Icons.favorite_border, size: 14, color: c.isLiked ? const Color(0xFFFF2442) : const Color(0xFFCCCCCC)),
                          const SizedBox(width: 2),
                          if (c.likesCount > 0) Text('${c.likesCount}', style: TextStyle(fontSize: 11, color: c.isLiked ? const Color(0xFFFF2442) : const Color(0xFFCCCCCC))),
                        ]),
                  ),
                ),
              ]),
              if (c.subComments.isNotEmpty) _buildSubComments(c),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _buildSubComments(Comment parent) {
    final subs = parent.subComments;
    if (subs.isEmpty) return const SizedBox.shrink();
    final expanded = _subExpanded[parent.id] ?? false;
    final showAll = expanded || subs.length <= 3;
    final displaySubs = showAll ? subs : subs.sublist(0, 3);
    final hiddenCount = subs.length - 3;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ...displaySubs.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          final sa = fullUrl(s.avatar);
          final isLast = idx == displaySubs.length - 1;
          final isA = s.userId == _post?.userId;
          final highlight = _highlightCommentId == s.id;
          _commentKeys.putIfAbsent(s.id, () => GlobalKey());
          return GestureDetector(
            key: _commentKeys[s.id],
            onTap: () => _setReplyTo(s, parentId: parent.id, replyToUserId: s.userId),
            onLongPress: () => _showCommentActionSheet(s),
            child: _highlightWrap(
              highlight: highlight,
              child: Container(
                color: Colors.transparent,
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  sa.isNotEmpty
                    ? CircleAvatar(radius: 12, backgroundImage: CachedNetworkImageProvider(sa))
                    : CircleAvatar(radius: 12, backgroundColor: getColorForId(s.userId), child: Text(s.nickname.isNotEmpty ? s.nickname[0] : '?', style: const TextStyle(fontSize: 8, color: Colors.white))),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(s.nickname, style: const TextStyle(fontSize: 12, color: Color(0xFF666666), fontWeight: FontWeight.w500)),
                      if (isA) ...[ const SizedBox(width: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5), decoration: BoxDecoration(color: const Color(0xFFFFF0F3), borderRadius: BorderRadius.circular(2)), child: const Text('作者', style: TextStyle(fontSize: 8, color: Color(0xFFFF2442), fontWeight: FontWeight.w500)))],
                    ]),
                    const SizedBox(height: 2),
                    if (s.content.isNotEmpty)
                      RichText(text: TextSpan(style: const TextStyle(fontSize: 13, color: Color(0xFF333333), height: 1.5), children: [
                        TextSpan(text: '回复 ${s.replyToNickname.isNotEmpty ? s.replyToNickname : parent.nickname}：', style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                        buildEmojiTextSpan(s.content, style: const TextStyle(fontSize: 13, color: Color(0xFF333333)), emojiSize: 18),
                      ]))
                    else
                      RichText(text: TextSpan(style: const TextStyle(fontSize: 13, color: Color(0xFF333333), height: 1.5), children: [
                        TextSpan(text: '回复 ${s.replyToNickname.isNotEmpty ? s.replyToNickname : parent.nickname}', style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                      ])),
                    if (s.voiceUrl.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _playCommentVoice(s.voiceUrl),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Center(
                                child: _commentVoiceLoading && _playingCommentVoiceIdx == s.voiceUrl.hashCode
                                    ? const CupertinoActivityIndicator(radius: 7, color: Color(0xFFFF2442))
                                    : Icon(_playingCommentVoiceIdx == s.voiceUrl.hashCode ? Icons.pause_circle : Icons.play_circle, size: 20, color: const Color(0xFFFF2442)),
                              ),
                            ),
                            const SizedBox(width: 3),
                            ...List.generate(12, (i) => Container(width: 2, height: 3 + (i % 4) * 1.5, margin: const EdgeInsets.only(right: 1), decoration: BoxDecoration(color: const Color(0xFFFF2442).withValues(alpha: 0.4), borderRadius: BorderRadius.circular(1)))),
                            const SizedBox(width: 4),
                            Text('${s.voiceDuration}s', style: const TextStyle(fontSize: 10, color: Color(0xFF999999))),
                          ]),
                        ),
                      ),
                    ],
                    if (s.imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ClipRRect(borderRadius: BorderRadius.circular(6), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 140), child: CachedNetworkImage(imageUrl: fullUrl(s.imageUrl), width: 100, fit: BoxFit.cover))),
                    ],
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(fmtTime(s.createdAt), style: const TextStyle(fontSize: 10, color: Color(0xFFCCCCCC))),
                      if (s.location.isNotEmpty) ...[ const SizedBox(width: 4), Text(s.location, style: const TextStyle(fontSize: 10, color: Color(0xFFCCCCCC)))],
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _setReplyTo(s, parentId: parent.id, replyToUserId: s.userId),
                        child: const Text('回复', style: TextStyle(fontSize: 10, color: Color(0xFFCCCCCC), fontWeight: FontWeight.w500)),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _toggleCommentLike(s),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: _commentLikeCtrls.containsKey(s.id)
                            ? AnimatedBuilder(
                                animation: _commentLikeCtrls[s.id]!,
                                builder: (_, child) => Transform.scale(scale: _bounceScale(_commentLikeCtrls[s.id]!.value), child: child),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(s.isLiked ? Icons.favorite : Icons.favorite_border, size: 12, color: s.isLiked ? const Color(0xFFFF2442) : const Color(0xFFCCCCCC)),
                                  if (s.likesCount > 0) ...[ const SizedBox(width: 2), Text('${s.likesCount}', style: TextStyle(fontSize: 10, color: s.isLiked ? const Color(0xFFFF2442) : const Color(0xFFCCCCCC)))],
                                ]),
                              )
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(s.isLiked ? Icons.favorite : Icons.favorite_border, size: 12, color: s.isLiked ? const Color(0xFFFF2442) : const Color(0xFFCCCCCC)),
                                if (s.likesCount > 0) ...[ const SizedBox(width: 2), Text('${s.likesCount}', style: TextStyle(fontSize: 10, color: s.isLiked ? const Color(0xFFFF2442) : const Color(0xFFCCCCCC)))],
                              ]),
                        ),
                      ),
                    ]),
                  ])),
                ]),
              ),
            ),
          );
        }),
        if (!showAll)
          GestureDetector(
            onTap: () => setState(() => _subExpanded[parent.id] = true),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('展开另外 $hiddenCount 条回复', style: const TextStyle(fontSize: 12, color: Color(0xFF3378E5), fontWeight: FontWeight.w500)),
            ),
          ),
        if (showAll && subs.length > 3)
          GestureDetector(
            onTap: () => setState(() => _subExpanded[parent.id] = false),
            child: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('收起回复', style: TextStyle(fontSize: 12, color: Color(0xFF999999), fontWeight: FontWeight.w500)),
            ),
          ),
      ]),
    );
  }

  Widget _highlightWrap({required bool highlight, required Widget child}) {
    if (!highlight) return child;
    return AnimatedBuilder(
      animation: _highlightCtrl,
      builder: (_, __) {
        final t = _highlightCtrl.value;
        // 0→0.15 fade in, 0.15→0.85 hold, 0.85→1.0 fade out
        double alpha;
        if (t < 0.15) {
          alpha = t / 0.15;
        } else if (t < 0.85) {
          alpha = 1.0;
        } else {
          alpha = (1.0 - t) / 0.15;
        }
        return Container(
          decoration: BoxDecoration(
            color: Color.fromRGBO(255, 36, 66, alpha * 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        );
      },
    );
  }

  Widget _bottomBar() {
    final lk = _post?.isLiked ?? false;
    final cl = _post?.isCollected ?? false;
    final cc = _post?.commentsCount ?? 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      padding: _isEditing
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
        borderRadius: _isEditing ? const BorderRadius.vertical(top: Radius.circular(14)) : null,
        boxShadow: _isEditing
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2))]
            : [],
      ),
      child: SafeArea(top: false, child: _isEditing ? _buildEditingInput() : _buildNormalBar(lk, cl, cc)),
    );
  }

  Widget _buildNormalBar(bool lk, bool cl, int cc) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: GestureDetector(
        onTap: () {
          setState(() => _isEditing = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _commentFocusNode.requestFocus();
          });
          _scrollToCommentArea();
        },
        child: Container(
          constraints: const BoxConstraints(maxHeight: 100),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(19),
          ),
          child: _commentCtrl.text.isEmpty
              ? const Text('说点什么...', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Color(0xFF999999), height: 1.4))
              : buildEmojiRichText(_commentCtrl.text, style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.4), maxLines: 3),
        ),
      )),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: _toggleLike,
        child: AnimatedBuilder(
          animation: _likeBounceCtrl,
          builder: (_, child) => Transform.scale(scale: _bounceScale(_likeBounceCtrl.value), child: child),
          child: Padding(padding: const EdgeInsets.only(bottom: 2), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(lk ? Icons.favorite : Icons.favorite_border, size: 22, color: lk ? const Color(0xFFFF2442) : const Color(0xFF999999)),
            Text('${_post?.likesCount ?? 0}', style: TextStyle(fontSize: 9, color: lk ? const Color(0xFFFF2442) : const Color(0xFF999999))),
          ])),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _toggleCollect,
        child: AnimatedBuilder(
          animation: _collectBounceCtrl,
          builder: (_, child) => Transform.scale(scale: _bounceScale(_collectBounceCtrl.value), child: child),
          child: Padding(padding: const EdgeInsets.only(bottom: 2), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(cl ? Icons.star : Icons.star_border, size: 22, color: cl ? const Color(0xFFFFAA00) : const Color(0xFF999999)),
            Text('${_post?.collectsCount ?? 0}', style: TextStyle(fontSize: 9, color: cl ? const Color(0xFFFFAA00) : const Color(0xFF999999))),
          ])),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: () {
          setState(() => _isEditing = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _commentFocusNode.requestFocus();
          });
          _scrollToCommentArea();
        },
        child: Padding(padding: const EdgeInsets.only(bottom: 2), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.chat_bubble_outline, size: 22, color: Color(0xFF999999)),
          Text('$cc', style: const TextStyle(fontSize: 9, color: Color(0xFF999999))),
        ])),
      ),
    ]);
  }

  Widget _buildEditingInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_replyToComment != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('回复 ${_replyToComment!.nickname}', style: const TextStyle(fontSize: 12, color: Color(0xFFFF2442), fontWeight: FontWeight.w500)),
          ),
        Container(
          height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExtendedTextField(
            controller: _commentCtrl,
            focusNode: _commentFocusNode,
            autofocus: true,
            maxLines: null,
            expands: true,
            specialTextSpanBuilder: CommentEmojiSpanBuilder(),
            textAlignVertical: TextAlignVertical.top,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(fontSize: 15, height: 1.5),
            decoration: const InputDecoration(
              hintText: '说点什么...',
              hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(14, 12, 14, 12),
            ),
            onChanged: _onCommentTextChanged,
          ),
        ),
        if (_isCommentRecording)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF2442), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('正在录制 ${_commentRecordSeconds}s', style: const TextStyle(fontSize: 13, color: Color(0xFFFF2442), fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        if (_commentVoicePath != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                GestureDetector(
                  onTap: () => _previewCommentVoice(_commentVoicePath!),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: _commentVoiceLoading
                        ? const CupertinoActivityIndicator(radius: 10, color: Color(0xFFFF2442))
                        : Icon(_isPreviewingCommentVoice ? Icons.pause_circle : Icons.play_circle, size: 32, color: const Color(0xFFFF2442)),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${_commentVoiceDuration}s', style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
                const Spacer(),
                GestureDetector(onTap: _removeCommentVoice, child: const Icon(Icons.close, size: 16, color: Color(0xFF999999))),
              ]),
            ),
          ),
        if (_commentImages.isNotEmpty || _imageUploading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _commentImages.length + (_imageUploading ? 1 : 0),
                itemBuilder: (_, i) {
                  if (_imageUploading && i == _commentImages.length) {
                    return Container(
                      width: 72, height: 72, margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
                      child: const Center(child: CupertinoActivityIndicator(radius: 12, color: Color(0xFFFF2442))),
                    );
                  }
                  return Container(
                    width: 72, height: 72, margin: const EdgeInsets.only(right: 8),
                    child: Stack(clipBehavior: Clip.none, children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: fullUrl(_commentImages[i]), width: 72, height: 72, fit: BoxFit.cover)),
                      Positioned(top: -6, right: -6, child: GestureDetector(
                        onTap: () => setState(() => _commentImages.removeAt(i)),
                        child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Color(0xCC000000), shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: Colors.white)),
                      )),
                    ]),
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 6),
        Row(children: [
          GestureDetector(onTap: _pickCommentImage, behavior: HitTestBehavior.opaque, child: Container(width: 44, height: 44, alignment: Alignment.center, child: const Icon(Icons.image_outlined, size: 24, color: Color(0xFF666666)))),
          const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_isCommentRecording) {
                _stopCommentRecording();
              } else {
                _startCommentRecording();
              }
            },
            child: Container(width: 52, height: 52, alignment: Alignment.center, child: Icon(_isCommentRecording ? Icons.stop_circle : Icons.mic_none_outlined, size: 28, color: _isCommentRecording ? const Color(0xFFFF2442) : const Color(0xFF666666))),
          ),
          const SizedBox(width: 12),
          GestureDetector(onTap: _showMentionPicker, behavior: HitTestBehavior.opaque, child: Container(width: 44, height: 44, alignment: Alignment.center, child: const Icon(Icons.alternate_email, size: 24, color: Color(0xFF666666)))),
          const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_showCommentEmojiPanel) {
                setState(() => _showCommentEmojiPanel = false);
                _commentFocusNode.requestFocus();
              } else {
                _commentFocusNode.unfocus();
                setState(() => _showCommentEmojiPanel = true);
              }
            },
            child: Container(width: 44, height: 44, alignment: Alignment.center, child: Icon(_showCommentEmojiPanel ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined, size: 24, color: const Color(0xFF666666))),
          ),
          const Spacer(),
          ValueListenableBuilder<String>(
            valueListenable: _inputText,
            builder: (_, text, __) {
              final canSend = text.trim().isNotEmpty || _commentImages.isNotEmpty || _commentVoicePath != null;
              if (!canSend) return const SizedBox.shrink();
              return GestureDetector(
                onTap: _isSubmitting ? null : _submitComment,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: !_isSubmitting ? const Color(0xFFFF2442) : const Color(0xFFFFD6DD),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: _isSubmitting
                    ? const CupertinoActivityIndicator(radius: 8, color: Colors.white)
                    : const Text('发送', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              );
            },
          ),
        ]),
        if (_showCommentEmojiPanel)
          EmojiPickerPanel(
            height: 220,
            onEmojiSelected: (assetPath) {
              _commentEmojiInserting = true;
              final filename = assetPath.split('/').last;
              final marker = '[emoji:$filename]';
              final text = _commentCtrl.text;
              final cursorPos = _commentCtrl.selection.start;
              final insertPos = cursorPos < 0 ? text.length : cursorPos;
              _commentCtrl.text = text.substring(0, insertPos) + marker + text.substring(insertPos);
              _commentCtrl.selection = TextSelection.collapsed(offset: insertPos + marker.length);
              _onCommentTextChanged(_commentCtrl.text);
              Future.microtask(() => _commentEmojiInserting = false);
            },
          ),
      ]),
    );
  }
}

enum _TextMatchType { url, emoji }

class _TextMatch {
  final int start;
  final int end;
  final _TextMatchType type;
  final String value;
  _TextMatch(this.start, this.end, this.type, this.value);
}

class CommentEmojiText extends SpecialText {
  static const String flag = '[emoji:';
  final int startIndex;

  CommentEmojiText(TextStyle? textStyle, {SpecialTextGestureTapCallback? onTap, required this.startIndex})
      : super(flag, ']', textStyle, onTap: onTap);

  @override
  InlineSpan finishText() {
    final key = getContent();
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

class CommentEmojiSpanBuilder extends SpecialTextSpanBuilder {
  @override
  SpecialText? createSpecialText(String flag, {TextStyle? textStyle, SpecialTextGestureTapCallback? onTap, int? index}) {
    if (isStart(flag, CommentEmojiText.flag)) {
      final startIndex = (index ?? 0) - CommentEmojiText.flag.length + 1;
      return CommentEmojiText(textStyle, onTap: onTap, startIndex: startIndex);
    }
    return null;
  }
}



