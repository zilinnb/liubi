import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/image_picker_util.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../utils/helpers.dart';
import '../utils/emoji_text.dart';
import '../utils/emoji_assets.dart';
import '../widgets/emoji_picker_panel.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import '../widgets/app_toast.dart';
import 'image_viewer_screen.dart';

class ChatScreen extends StatefulWidget {
  final int conversationId;
  final String otherUserName;
  final String otherUserAvatar;
  final int otherUserId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.otherUserName = '',
    this.otherUserAvatar = '',
    this.otherUserId = 0,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  int _msgPage = 1;
  bool _noMoreMsg = false;
  bool _loadingMore = false;
  String _convName = '';
  int _convType = 1;
  int _memberCount = 0;
  bool _isGroupOwner = false;
  bool _hasText = false;
  bool _showPlusPanel = false;
  bool _showEmojiPanel = false;
  bool _emojiInserting = false;
  StreamSubscription? _msgSubscription;
  int? _currentUserId;
  String? _groupCode;

  late AnimationController _sendBtnCtrl;
  late AnimationController _plusPanelCtrl;
  late AnimationController _menuCtrl;
  late AnimationController _voiceWaveCtrl;
  OverlayEntry? _menuEntry;

  bool _isRecording = false;
  bool _recordCancelled = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _recordPath;
  final AudioRecorder _recorder = AudioRecorder();
  AudioPlayer? _voicePlayer;

  // 微信风格语音录制UI状态
  double _recordSlideY = 0.0; // 上滑距离
  bool _recordSlideUp = false; // 是否已上滑到取消区域
  int? _playingVoiceIdx;
  bool _voiceLoading = false;

  bool _isVoiceMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sendBtnCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80), lowerBound: 0.92, upperBound: 1.0);
    _sendBtnCtrl.value = 1.0;
    _plusPanelCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _menuCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _voiceWaveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _msgCtrl.addListener(() {
      final has = _msgCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !_emojiInserting) {
        _hidePlusPanel();
        setState(() => _showEmojiPanel = false);
        _scheduleScrollToBottom();
      }
    });

    final up = Provider.of<UserProvider>(context, listen: false);
    _currentUserId = up.userInfo?.id;
    final cs = Provider.of<ChatService>(context, listen: false);
    if (!cs.isConnected) cs.connect();

    _msgSubscription = cs.onMessage.listen((msg) {
      if (msg['type'] == 'chat') {
        final data = msg['data'] as Map? ?? {};
        if (data['conversation_id'] == widget.conversationId && mounted) {
          final senderId = data['sender_id'];
          if (senderId == _currentUserId) {
            final msgId = data['id'];
            // 用lastIndexWhere查找最近一条没有服务端ID的本地消息
            final idx = _messages.lastIndexWhere((m) =>
              m['sender_id'] == _currentUserId &&
              m['id'] == null
            );
            if (idx >= 0) {
              setState(() {
                _messages[idx]['id'] = msgId;
                _messages[idx]['content'] = data['content'] ?? _messages[idx]['content'];
                if (data['created_at'] != null) _messages[idx]['created_at'] = data['created_at'];
              });
              StorageService.saveChatMessages(widget.conversationId, _messages);
            } else {
              // 没找到匹配的本地消息，可能是刷新后收到的，不重复添加
              final existingIdx = _messages.indexWhere((m) => m['id'] != null && m['id'] == msgId);
              if (existingIdx < 0) {
                final msgData = Map<String, dynamic>.from(data);
                setState(() => _messages.add(msgData));
                StorageService.appendChatMessages(widget.conversationId, [msgData]);
              }
            }
            _scheduleScrollToBottom();
            return;
          }
          final msgId = data['id'];
          final existingIdx = _messages.indexWhere((m) => m['id'] != null && m['id'] == msgId);
          if (existingIdx >= 0) return;
          final msgData = Map<String, dynamic>.from(data);
          setState(() => _messages.add(msgData));
          _scheduleScrollToBottom();
          StorageService.appendChatMessages(widget.conversationId, [msgData]);
          _markAsRead();
        }
      } else if (msg['type'] == 'recall') {
        final data = msg['data'] as Map? ?? {};
        if (data['conversation_id'] == widget.conversationId && mounted) {
          final msgId = data['message_id'];
          setState(() {
            final idx = _messages.indexWhere((m) => m['id'] == msgId);
            if (idx >= 0) _messages[idx]['is_recalled'] = 1;
          });
          StorageService.saveChatMessages(widget.conversationId, _messages);
        }
      }
    });

    _loadMessages().then((_) => _markAsRead());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dismissMenu();
    _msgSubscription?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _sendBtnCtrl.dispose();
    _plusPanelCtrl.dispose();
    _menuCtrl.dispose();
    _voiceWaveCtrl.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    _voicePlayer?.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final keyboardH = WidgetsBinding.instance.window.viewInsets.bottom;
    if (keyboardH > 0 && _scrollCtrl.hasClients && mounted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _markAsRead() async {
    try { await ApiService().post('/chat/messages/${widget.conversationId}/read'); } catch (_) {}
  }

  Future<void> _loadMessages() async {
    final localMsgs = await StorageService.getChatMessages(widget.conversationId);
    if (localMsgs.isNotEmpty && mounted) {
      setState(() { _messages = localMsgs; _loading = false; });
      _ensureScrollToBottom();
    }

    try {
      final res = await ApiService().get('/chat/messages/${widget.conversationId}?page=1&pageSize=50');
      if (res['code'] == 200 && mounted) {
        final list = res['data'] as List? ?? [];
        final serverMsgs = list.map((e) => e as Map<String, dynamic>).toList();
        setState(() {
          final merged = <String, Map<String, dynamic>>{};
          for (final sm in serverMsgs) {
            final key = sm['id']?.toString();
            if (key != null && key.isNotEmpty) merged[key] = sm;
          }
          for (var m in localMsgs) {
            final idKey = m['id']?.toString();
            if (idKey != null && idKey.isNotEmpty && merged.containsKey(idKey)) continue;
            final contentKey = 'local_${m['sender_id']}_${m['content']}_${m['created_at']}';
            merged[contentKey] = m;
          }
          _messages = merged.values.toList()..sort((a, b) {
            final ta = DateTime.tryParse(a['created_at'] ?? '')?.millisecondsSinceEpoch ?? 0;
            final tb = DateTime.tryParse(b['created_at'] ?? '')?.millisecondsSinceEpoch ?? 0;
            return ta.compareTo(tb);
          });
          if (list.length < 50) _noMoreMsg = true;
          _loading = false;
        });
        StorageService.saveChatMessages(widget.conversationId, _messages);
        _loadConvInfo();
        _ensureScrollToBottom();
      }
    } catch (_) {
      if (_messages.isEmpty && mounted) setState(() => _loading = false);
    }
  }

  void _ensureScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollCtrl.hasClients && mounted) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _loadMoreMessages() async {
    if (_loadingMore || _noMoreMsg) return;
    setState(() => _loadingMore = true);
    _msgPage++;
    try {
      final prevMaxScroll = _scrollCtrl.hasClients ? _scrollCtrl.position.maxScrollExtent : 0.0;
      final res = await ApiService().get('/chat/messages/${widget.conversationId}?page=$_msgPage&pageSize=10');
      if (res['code'] == 200 && mounted) {
        final list = res['data'] as List? ?? [];
        final olderMsgs = list.map((e) => e as Map<String, dynamic>).toList();
        setState(() {
          _messages.insertAll(0, olderMsgs);
          if (list.length < 10) _noMoreMsg = true;
          _loadingMore = false;
        });
        StorageService.appendChatMessages(widget.conversationId, olderMsgs);
        if (_scrollCtrl.hasClients) {
          final newMaxScroll = _scrollCtrl.position.maxScrollExtent;
          _scrollCtrl.jumpTo(newMaxScroll - prevMaxScroll);
        }
      }
    } catch (_) {
      _msgPage--;
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadConvInfo() async {
    try {
      final res = await ApiService().get('/chat/conversations');
      if (res['code'] == 200 && mounted) {
        final list = res['data'] as List? ?? [];
        for (final c in list) {
          if (c['id'] == widget.conversationId) {
            setState(() {
              _convName = c['name'] ?? '';
              _convType = c['type'] ?? 1;
              _memberCount = c['member_count'] ?? 0;
              _isGroupOwner = c['is_owner'] == true || c['is_owner'] == 1;
              _groupCode = c['group_code']?.toString();
            });
            break;
          }
        }
      }
    } catch (_) {}
  }

  void _scheduleScrollToBottom() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
      // 额外延迟确保消息渲染完成
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToBottom();
      });
    });
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      return;
    }
    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    setState(() => _hasText = false);
    final up = Provider.of<UserProvider>(context, listen: false);
    final now = DateTime.now().toIso8601String();
    final localMsg = {
      'sender_id': up.userInfo?.id,
      'sender_name': up.userInfo?.nickname ?? '',
      'sender_avatar': up.userInfo?.avatar ?? '',
      'content': text,
      'type': 1,
      'is_recalled': 0,
      'created_at': now,
      '_localId': '${DateTime.now().microsecondsSinceEpoch}_${_messages.length}',
    };
    setState(() => _messages.add(localMsg));
    _scheduleScrollToBottom();
    StorageService.appendChatMessages(widget.conversationId, [localMsg]);
    try {
      final cs = Provider.of<ChatService>(context, listen: false);
      if (!cs.isConnected) {
        await cs.connect();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await cs.sendMessage(widget.conversationId, text, 1);
    } catch (e) {
      debugPrint('[ChatScreen] 发送消息失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('消息发送失败，请检查网络'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _sendImage() async {
    final result = await ImagePickerUtil.pickImages(context, maxAssets: 9);
    if (result == null || result.imagePaths.isEmpty || !mounted) return;
    final up = Provider.of<UserProvider>(context, listen: false);

    for (int i = 0; i < result.imagePaths.length; i++) {
      final imgPath = result.imagePaths[i];
      final isLive = result.isLiveList.isNotEmpty && result.isLiveList[i];
      final liveVideoPath = result.liveVideoPaths.isNotEmpty ? result.liveVideoPaths[i] : '';

      final now = DateTime.now().toIso8601String();
      final localMsg = {
        'sender_id': up.userInfo?.id,
        'sender_name': up.userInfo?.nickname ?? '',
        'sender_avatar': up.userInfo?.avatar ?? '',
        'content': '',
        'type': 2,
        'is_recalled': 0,
        'created_at': now,
        '_localPath': imgPath,
        '_uploading': true,
        '_isLive': isLive,
        '_liveVideoPath': liveVideoPath,
        '_localId': '${DateTime.now().microsecondsSinceEpoch}_${_messages.length}',
      };
      setState(() => _messages.add(localMsg));
      _scheduleScrollToBottom();
      StorageService.appendChatMessages(widget.conversationId, [localMsg]);

      try {
        final res = await ApiService().uploadFile('/upload/single', imgPath);
        if (res['code'] == 200) {
          final url = res['data']?['url'] as String?;
          if (url != null) {
            String? videoUrl;
            if (isLive && liveVideoPath.isNotEmpty) {
              final vRes = await ApiService().uploadFile('/upload/single', liveVideoPath);
              if (vRes['code'] == 200) videoUrl = vRes['data']?['url'] as String?;
            }
            setState(() {
              localMsg['content'] = url;
              localMsg['_uploading'] = false;
              if (videoUrl != null) localMsg['_videoUrl'] = videoUrl;
            });
            StorageService.saveChatMessages(widget.conversationId, _messages);
            final cs = Provider.of<ChatService>(context, listen: false);
            if (!cs.isConnected) {
              await cs.connect();
              await Future.delayed(const Duration(milliseconds: 500));
            }
            // 发送实况图片消息，content格式：url|videoUrl 或 url
            final msgContent = videoUrl != null ? '$url|$videoUrl' : url;
            await cs.sendMessage(widget.conversationId, msgContent, isLive ? 5 : 2);
          }
        } else {
          if (mounted) {
            setState(() {
              localMsg['_uploading'] = false;
              localMsg['_uploadFailed'] = true;
            });
          }
        }
      } catch (e) {
        debugPrint('[ChatScreen] 发送图片失败: $e');
        if (mounted) {
          setState(() {
            localMsg['_uploading'] = false;
            localMsg['_uploadFailed'] = true;
          });
        }
      }
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能录制语音'), duration: Duration(seconds: 2)),
        );
      }
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      _recordPath = '${dir.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: _recordPath!);
      setState(() {
        _isRecording = true;
        _recordCancelled = false;
        _recordSeconds = 0;
      });
      _voiceWaveCtrl.repeat(); // 启动声波动画
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      debugPrint('[ChatScreen] 录音启动失败: $e');
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _recordTimer?.cancel();
    _recordTimer = null;
    _voiceWaveCtrl.stop(); // 停止声波动画
    if (cancel) {
      try { await _recorder.stop(); } catch (_) {}
      setState(() {
        _isRecording = false;
        _recordCancelled = false;
        _recordSlideUp = false;
        _recordSlideY = 0.0;
        _recordSeconds = 0;
        _recordPath = null;
      });
      return;
    }
    final path = await _recorder.stop();
    final duration = _recordSeconds;
    setState(() {
      _isRecording = false;
      _recordSlideUp = false;
      _recordSlideY = 0.0;
      _recordSeconds = 0;
    });
    if (path == null || duration < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('说话时间太短'), duration: Duration(seconds: 1)),
        );
      }
      return;
    }
    _sendVoiceMessage(path, duration);
  }

  Future<void> _sendVoiceMessage(String localPath, int duration) async {
    final up = Provider.of<UserProvider>(context, listen: false);
    final now = DateTime.now().toIso8601String();
    final localMsg = {
      'sender_id': up.userInfo?.id,
      'sender_name': up.userInfo?.nickname ?? '',
      'sender_avatar': up.userInfo?.avatar ?? '',
      'content': '',
      'type': 4,
      'is_recalled': 0,
      'created_at': now,
      '_localPath': localPath,
      '_voiceDuration': duration,
      '_uploading': true,
    };
    setState(() => _messages.add(localMsg));
    _scheduleScrollToBottom();
    StorageService.appendChatMessages(widget.conversationId, [localMsg]);
    try {
      final res = await ApiService().uploadFile('/upload/single', localPath);
      if (res['code'] == 200) {
        final url = res['data']?['url'] as String?;
        if (url != null) {
          setState(() {
            localMsg['content'] = url;
            localMsg['_uploading'] = false;
          });
          StorageService.saveChatMessages(widget.conversationId, _messages);
          final cs = Provider.of<ChatService>(context, listen: false);
          if (!cs.isConnected) {
            await cs.connect();
            await Future.delayed(const Duration(milliseconds: 500));
          }
          await cs.sendMessage(widget.conversationId, url, 4, voiceDuration: duration);
        }
      }
    } catch (e) {
      debugPrint('[ChatScreen] 发送语音失败: $e');
      if (mounted) {
        setState(() {
          localMsg['_uploading'] = false;
          localMsg['_uploadFailed'] = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音发送失败，请检查网络'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _toggleVoicePlayback(int index, Map<String, dynamic> msg) async {
    if (_playingVoiceIdx == index) {
      await _voicePlayer?.stop();
      setState(() { _playingVoiceIdx = null; _voiceLoading = false; _voiceWaveCtrl.stop(); });
      return;
    }
    await _voicePlayer?.stop();
    _voicePlayer?.dispose();
    _voicePlayer = AudioPlayer();
    setState(() { _playingVoiceIdx = index; _voiceLoading = true; });
    try {
      final localPath = msg['_localPath'] as String?;
      if (localPath != null && msg['_uploading'] == true) {
        await _voicePlayer!.play(DeviceFileSource(localPath));
      } else {
        final url = fullUrl(msg['content'] ?? '');
        await _voicePlayer!.play(UrlSource(url));
      }
      if (mounted) setState(() { _voiceLoading = false; _voiceWaveCtrl.repeat(); });
    } catch (_) {
      if (mounted) setState(() { _playingVoiceIdx = null; _voiceLoading = false; });
      return;
    }
    _voicePlayer!.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playingVoiceIdx = null; _voiceLoading = false; _voiceWaveCtrl.stop(); });
    });
  }

  Future<void> _recallMessage(int? msgId) async {
    if (msgId == null) return;
    try {
      final cs = Provider.of<ChatService>(context, listen: false);
      cs.sendRaw({'type': 'recall', 'message_id': msgId, 'conversation_id': widget.conversationId});
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == msgId);
        if (idx >= 0) _messages[idx]['is_recalled'] = 1;
      });
    } catch (_) {}
  }

  void _showMsgMenu(Map<String, dynamic> msg, BuildContext bubbleCtx) {
    _dismissMenu();
    final up = Provider.of<UserProvider>(context, listen: false);
    final isSelfMsg = msg['sender_id'] == up.userInfo?.id;
    final created = DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
    final canRecall = isSelfMsg && DateTime.now().difference(created).inMinutes < 2;
    final msgType = msg['type'] ?? 1;

    final List<String> labels = [];
    final List<VoidCallback> callbacks = [];
    if (msgType == 1) {
      labels.add('复制');
      callbacks.add(() { _dismissMenu(); Clipboard.setData(ClipboardData(text: msg['content'] ?? '')); });
    }
    if (msgType == 2 || msgType == 5) {
      labels.add('保存');
      callbacks.add(() { _dismissMenu(); _saveChatImage((msg['content'] ?? '').split('|').first); });
    }
    if (canRecall) {
      labels.add('撤回');
      callbacks.add(() { _dismissMenu(); _recallMessage(msg['id'] as int?); });
    }
    if (labels.isEmpty) return;

    final overlay = Overlay.of(context);
    final bubbleBox = bubbleCtx.findRenderObject() as RenderBox;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
    final bubblePos = bubbleBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bubbleSize = bubbleBox.size;
    final screenSize = MediaQuery.of(context).size;

    double menuW = labels.length * 56.0;
    double menuH = 36.0;
    double left = (bubblePos.dx + bubbleSize.width / 2 - menuW / 2).clamp(8.0, screenSize.width - menuW - 8);
    double top = bubblePos.dy - menuH - 6;
    bool showAbove = true;
    if (top < screenSize.height * 0.1) { top = bubblePos.dy + bubbleSize.height + 6; showAbove = false; }

    _menuEntry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        onTap: _dismissMenu,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _menuCtrl,
          builder: (_, __) {
            final t = Curves.easeOut.transform(_menuCtrl.value);
            return Stack(
              children: [
                Container(color: Color.fromRGBO(0, 0, 0, 0.15 * t)),
                Positioned(
                  left: left, top: top,
                  child: Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * t,
                      alignment: showAbove ? Alignment.bottomCenter : Alignment.topCenter,
                      child: Container(
                        height: menuH,
                        decoration: BoxDecoration(color: const Color(0xFF4C4C4C), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(labels.length, (i) => GestureDetector(
                            onTap: callbacks[i],
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 56, height: menuH,
                              alignment: Alignment.center,
                              child: Text(labels[i], style: const TextStyle(fontSize: 13, color: Colors.white, decoration: TextDecoration.none)),
                            ),
                          )),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    overlay.insert(_menuEntry!);
    _menuCtrl.forward(from: 0);
  }

  void _dismissMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
    if (!_menuCtrl.isDismissed) _menuCtrl.reset();
  }

  Future<void> _saveChatImage(String imageUrl) async {
    final url = fullUrl(imageUrl);
    if (url.isEmpty) return;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF2442))),
    );
    try {
      final response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/liubi_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(Uint8List.fromList(response.data));
      await Gal.putImage(filePath, album: '留笔');
      try { await file.delete(); } catch (_) {}
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.success(context, message: '已保存到相册');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.error(context, message: '保存失败');
      }
    }
  }

  void _showGroupInfo() async {
    try {
      final res = await ApiService().get('/chat/conversation/${widget.conversationId}/members');
      if (res['code'] == 200 && mounted) {
        final members = (res['data'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
        final up = Provider.of<UserProvider>(context, listen: false);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 32, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
                Padding(padding: const EdgeInsets.all(16), child: Row(children: [Text(_convName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF222222))), const Spacer(), GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => Navigator.pop(context), child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.close, size: 18, color: Color(0xFF999999))))])),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('群聊号: ${_groupCode ?? widget.conversationId}', style: const TextStyle(fontSize: 12, color: Color(0xFF999999)))),
                const SizedBox(height: 8),
                Expanded(child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = members[i];
                    final mId = m['id'] as int? ?? 0;
                    final a = fullUrl(m['avatar'] as String? ?? '');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _buildAvatar(a, m['nickname'] as String? ?? '?', mId, 18),
                      title: Text(m['nickname'] ?? '', style: const TextStyle(fontSize: 14)),
                      trailing: _isGroupOwner && mId != up.userInfo?.id
                          ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: () async { await ApiService().post('/chat/conversation/kick', data: {'conversation_id': widget.conversationId, 'user_id': mId}); if (!mounted) return; Navigator.pop(context); }, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12), child: Text('移出', style: TextStyle(fontSize: 12, color: Color(0xFFFF2442)))))
                          : null,
                    );
                  },
                )),
                if (!_isGroupOwner)
                  Padding(padding: const EdgeInsets.all(16), child: GestureDetector(
                    onTap: () async { await ApiService().post('/chat/conversation/leave', data: {'conversation_id': widget.conversationId}); if (mounted) { Navigator.pop(context); Navigator.pop(context); } },
                    child: Container(width: double.infinity, height: 44, decoration: BoxDecoration(color: const Color(0xFFFF2442), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('退出群聊', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)))),
                  )),
              ],
            ),
          ),
        );
      }
    } catch (_) {}
  }

  void _togglePlusPanel() {
    if (_showPlusPanel) {
      _plusPanelCtrl.reverse().then((_) { if (mounted) setState(() => _showPlusPanel = false); });
    } else {
      setState(() {
        _showPlusPanel = true;
        _showEmojiPanel = false;
        _isVoiceMode = false; // 点击加号时退出语音模式
      });
      _plusPanelCtrl.forward(from: 0);
      _focusNode.unfocus();
      _scheduleScrollToBottom();
    }
  }

  void _hidePlusPanel() {
    if (_showPlusPanel) {
      _plusPanelCtrl.reverse().then((_) { if (mounted) setState(() => _showPlusPanel = false); });
    }
  }

  void _previewImage(String url) {
    final isLocal = !url.startsWith('http') && !url.startsWith('/');
    if (isLocal) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
        body: Center(child: Image.file(File(url), fit: BoxFit.contain)),
      )));
    } else {
      ImageViewerScreen.openSingle(context, url: url);
    }
  }

  String _formatChatTime(String? dateStr, int index) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    if (index > 0) {
      final prev = _messages[index - 1];
      final prevDate = DateTime.tryParse(prev['created_at'] ?? '');
      if (prevDate != null && date.difference(prevDate).inMinutes.abs() < 5) return '';
    }
    final now = DateTime.now();
    final diff = now.difference(date);
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24 && date.day == now.day) return '今天 $time';
    if (diff.inDays < 2) return '昨天 $time';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    if (date.year == now.year) return '${date.month}月${date.day}日 $time';
    return '${date.year}年${date.month}月${date.day}日 $time';
  }

  Widget _buildAvatar(String url, String name, int id, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
      backgroundColor: url.isEmpty ? getColorForId(id) : null,
      child: url.isEmpty ? Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(fontSize: radius * 0.7, color: Colors.white, fontWeight: FontWeight.w500)) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final viewBottom = MediaQuery.of(context).viewInsets.bottom;
    final up = Provider.of<UserProvider>(context);
    final panelHeight = _showPlusPanel ? 100.0 + (viewBottom > 0 ? 0 : bottomPad) : (_showEmojiPanel ? 260.0 : 0.0);
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildNavBar(statusBarH),
          Expanded(child: _buildMsgList(up)),
          _buildInputBar(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: panelHeight,
            child: _showPlusPanel
                ? SizeTransition(
                    sizeFactor: CurvedAnimation(parent: _plusPanelCtrl, curve: Curves.easeOutCubic),
                    axisAlignment: -1.0,
                    child: _buildPlusPanel(bottomPad),
                  )
                : _showEmojiPanel
                    ? _buildChatEmojiPanel()
                    : const SizedBox.shrink(),
          ),
          if (!_showPlusPanel && !_showEmojiPanel && viewBottom == 0)
            SizedBox(height: bottomPad),
        ],
      ),
    );
  }

  Widget _buildNavBar(double statusBarH) {
    return Container(
      padding: EdgeInsets.only(top: statusBarH),
      decoration: const BoxDecoration(color: Color(0xFFEDEDED), border: Border(bottom: BorderSide(color: Color(0xFFD9D9D9), width: 0.5))),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(left: 0, child: GestureDetector(onTap: () {
              _markAsRead();
              Navigator.pop(context, true);
            }, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF222222))))),
            Center(child: GestureDetector(
              onTap: () {
                if (_convType == 1 && widget.otherUserId > 0) Navigator.pushNamed(context, '/user-profile', arguments: widget.otherUserId);
                else if (_convType == 2) _showGroupInfo();
              },
              child: Text(_convName.isEmpty ? (widget.otherUserName.isEmpty ? '聊天' : widget.otherUserName) : '$_convName${_convType == 2 ? '($_memberCount)' : ''}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
            )),
            if (_convType == 2)
              Positioned(right: 0, child: GestureDetector(onTap: _showGroupInfo, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Icon(Icons.more_horiz, size: 20, color: Color(0xFF555555))))),
          ],
        ),
      ),
    );
  }

  Widget _buildMsgList(UserProvider up) {
    if (_loading) return const Center(child: CupertinoActivityIndicator(radius: 14, color: Color(0xFF07C160)));
    return GestureDetector(
      onTap: () { _focusNode.unfocus(); _hidePlusPanel(); },
      child: NotificationListener<ScrollNotification>(
        onNotification: (scroll) {
          if (scroll is ScrollUpdateNotification && scroll.metrics.pixels <= 50 && !_noMoreMsg && !_loadingMore) _loadMoreMessages();
          return false;
        },
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: _messages.length + (_loadingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == 0 && _loadingMore) return const Padding(padding: EdgeInsets.only(bottom: 10), child: Center(child: CupertinoActivityIndicator(radius: 8)));
            final msgIndex = _loadingMore ? i - 1 : i;
            final msg = _messages[msgIndex];
            final timeLabel = _formatChatTime(msg['created_at'] as String?, msgIndex);
            return Column(children: [
              if (timeLabel.isNotEmpty) _buildTimeLabel(timeLabel),
              _buildMsgItem(msg, up, msgIndex),
            ]);
          },
        ),
      ),
    );
  }

  Widget _buildTimeLabel(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 10, top: 6), child: Center(child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFFB0B0B0)))));
  }

  Widget _buildMsgItem(Map<String, dynamic> msg, UserProvider up, int index) {
    final isSelf = msg['sender_id'] == up.userInfo?.id;
    final isRecalled = msg['is_recalled'] == 1;
    final msgType = msg['type'] ?? 1;

    if (msgType == 3) return Padding(padding: const EdgeInsets.only(bottom: 10), child: Center(child: Text(msg['content'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF999999)))));
    if (isRecalled) return Padding(padding: const EdgeInsets.only(bottom: 10), child: Center(child: Text(isSelf ? '你撤回了一条消息' : '${msg['sender_name'] ?? ''}撤回了一条消息', style: const TextStyle(fontSize: 12, color: Color(0xFF999999)))));

    if (msgType == 4 && !msg.containsKey('_voiceDuration')) {
      msg['_voiceDuration'] = msg['voice_duration'] ?? 0;
    }

    final rawAvatar = isSelf ? (up.userInfo?.avatar ?? '') : (msg['sender_avatar'] as String? ?? '');
    final avatar = rawAvatar.isNotEmpty ? rawAvatar : (isSelf ? '' : widget.otherUserAvatar);
    final avatarUrl = fullUrl(avatar);
    final rawName = isSelf ? (up.userInfo?.nickname ?? '') : (msg['sender_name'] as String? ?? '');
    final avatarName = rawName.isNotEmpty ? rawName : (isSelf ? '?' : widget.otherUserName);
    final avatarId = isSelf ? (up.userInfo?.id ?? 0) : (msg['sender_id'] as int? ?? 0);

    return _MsgBubbleWrapper(
      onLongPress: (bubbleContext) => _showMsgMenu(msg, bubbleContext),
      isSelf: isSelf,
      convType: _convType,
      senderName: msg['sender_name'] as String? ?? '',
      avatarUrl: avatarUrl,
      avatarName: avatarName,
      avatarId: avatarId,
      bubble: _buildBubble(msg, isSelf, msgType),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, bool isSelf, int msgType) {
    if (msgType == 2) {
      final isUploading = msg['_uploading'] == true;
      final uploadFailed = msg['_uploadFailed'] == true;
      final localPath = msg['_localPath'] as String?;
      final imgUrl = fullUrl(msg['content'] ?? '');
      return GestureDetector(
        onTap: isUploading ? null : () => _previewImage(localPath != null && imgUrl.isEmpty ? localPath : imgUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(6), topRight: const Radius.circular(6),
            bottomLeft: Radius.circular(isSelf ? 6 : 2), bottomRight: Radius.circular(isSelf ? 2 : 6),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (localPath != null && imgUrl.isEmpty)
                  Image.file(File(localPath), fit: BoxFit.cover, width: 180, height: 180 * 0.75)
                else if (imgUrl.isNotEmpty)
                  CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover)
                else
                  Container(width: 180, height: 180 * 0.75, color: const Color(0xFFF0F0F0)),
                if (isUploading)
                  Container(
                    color: const Color(0x66000000),
                    child: const CupertinoActivityIndicator(radius: 14, color: Colors.white),
                  ),
                if (uploadFailed)
                  Container(
                    color: const Color(0x66000000),
                    child: const Icon(Icons.error_outline, color: Colors.white, size: 32),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (msgType == 5) {
      // 实况图片消息
      final isUploading = msg['_uploading'] == true;
      final uploadFailed = msg['_uploadFailed'] == true;
      final localPath = msg['_localPath'] as String?;
      final rawContent = msg['content'] ?? '';
      final parts = rawContent.split('|');
      final imgUrl = fullUrl(parts.isNotEmpty ? parts[0] : '');
      final videoUrl = parts.length > 1 ? parts[1] : (msg['_videoUrl'] ?? '');
      return GestureDetector(
        onTap: isUploading ? null : () {
          ImageViewerScreen.openSingle(context, url: localPath != null && imgUrl.isEmpty ? localPath : imgUrl, liveVideoUrl: videoUrl.isNotEmpty ? fullUrl(videoUrl) : null);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(6), topRight: const Radius.circular(6),
            bottomLeft: Radius.circular(isSelf ? 6 : 2), bottomRight: Radius.circular(isSelf ? 2 : 6),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Stack(
              children: [
                if (localPath != null && imgUrl.isEmpty)
                  Image.file(File(localPath), fit: BoxFit.cover, width: 180, height: 180 * 0.75)
                else if (imgUrl.isNotEmpty)
                  CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover)
                else
                  Container(width: 180, height: 180 * 0.75, color: const Color(0xFFF0F0F0)),
                // LIVE标识 - 左下角
                Positioned(bottom: 6, left: 6, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/icons/icon_live_photo.png', width: 10, height: 10),
                    const SizedBox(width: 2),
                    const Text('LIVE', style: TextStyle(fontSize: 8, color: Color(0xFF333333), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ]),
                )),
                if (isUploading)
                  Container(
                    color: const Color(0x66000000),
                    child: const CupertinoActivityIndicator(radius: 14, color: Colors.white),
                  ),
                if (uploadFailed)
                  Container(
                    color: const Color(0x66000000),
                    child: const Icon(Icons.error_outline, color: Colors.white, size: 32),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (msgType == 6) {
      // 留币红包消息 - 微信红包样式
      Map<String, dynamic> rpData = {};
      try { rpData = json.decode(msg['content'] ?? '{}'); } catch (_) {}
      final coins = rpData['coins'] ?? 0;
      final rpMsg = rpData['message'] ?? '恭喜发财，大吉大利';
      final isReceived = msg['sender_id'] != Provider.of<UserProvider>(context, listen: false).userInfo?.id;

      return GestureDetector(
        onTap: () => _openRedPacket(msg, coins, rpMsg),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isReceived ? const Color(0xFFFF4444) : const Color(0xFFFF6B6B),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(6), topRight: const Radius.circular(6),
              bottomLeft: Radius.circular(isSelf ? 6 : 2), bottomRight: Radius.circular(isSelf ? 2 : 6),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.card_giftcard, size: 28, color: Color(0xFFFFD700)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$coins 留币', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(rpMsg, style: const TextStyle(fontSize: 11, color: Color(0xFFFFE0B2)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
            const SizedBox(height: 8),
            const Divider(color: Color(0xFFFF8A80), height: 1),
            const SizedBox(height: 4),
            Text(isReceived ? '领取红包' : '查看红包', style: const TextStyle(fontSize: 10, color: Color(0xFFFFE0B2))),
          ]),
        ),
      );
    }

    if (msgType == 4) {
      final voiceDuration = msg['_voiceDuration'] as int? ?? 0;
      final isUploading = msg['_uploading'] == true;
      final uploadFailed = msg['_uploadFailed'] == true;
      final msgIndex = _messages.indexOf(msg);
      final isPlaying = _playingVoiceIdx == msgIndex;
      final isLoading = isPlaying && _voiceLoading;
      final bubbleWidth = 80.0 + (voiceDuration.clamp(1, 60) / 60.0 * 80.0);
      final bubbleColor = isSelf ? const Color(0xFF95EC69) : const Color(0xFFFFFFFF);
      final iconColor = isSelf ? const Color(0xFF222222) : const Color(0xFF666666);

      return GestureDetector(
        onTap: () => _toggleVoicePlayback(msgIndex, msg),
        child: Container(
          width: bubbleWidth.clamp(80.0, 160.0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(6), topRight: const Radius.circular(6),
              bottomLeft: Radius.circular(isSelf ? 6 : 2), bottomRight: Radius.circular(isSelf ? 2 : 6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (isSelf) ...[
                if (isUploading)
                  const SizedBox(width: 14, height: 14, child: CupertinoActivityIndicator(radius: 6))
                else if (uploadFailed)
                  Icon(Icons.error_outline, size: 14, color: iconColor),
                if (isUploading || uploadFailed) const SizedBox(width: 4),
                Text(
                  '$voiceDuration"',
                  style: TextStyle(fontSize: 13, color: iconColor, fontWeight: FontWeight.w400),
                ),
                const SizedBox(width: 6),
                _buildVoiceWaves(isPlaying, isLoading, iconColor),
              ] else ...[
                _buildVoiceWaves(isPlaying, isLoading, iconColor),
                const SizedBox(width: 6),
                Text(
                  '$voiceDuration"',
                  style: TextStyle(fontSize: 13, color: iconColor, fontWeight: FontWeight.w400),
                ),
                if (isUploading || uploadFailed) const SizedBox(width: 4),
                if (isUploading)
                  const SizedBox(width: 14, height: 14, child: CupertinoActivityIndicator(radius: 6))
                else if (uploadFailed)
                  Icon(Icons.error_outline, size: 14, color: iconColor),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isSelf ? const Color(0xFF95EC69) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(6), topRight: const Radius.circular(6),
          bottomLeft: Radius.circular(isSelf ? 6 : 2), bottomRight: Radius.circular(isSelf ? 2 : 6),
        ),
      ),
      child: buildEmojiRichText(msg['content'] ?? '', style: const TextStyle(fontSize: 15, color: Color(0xFF222222), height: 1.5), emojiSize: 24),
    );
  }

  Widget _buildVoiceWaves(bool isPlaying, bool isLoading, Color color) {
    return AnimatedBuilder(
      animation: _voiceWaveCtrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            double h;
            if (isPlaying && !isLoading) {
              h = 4 + 10 * (0.5 + 0.5 * sin(i * 1.2 + _voiceWaveCtrl.value * 2 * pi));
            } else {
              h = [4.0, 12.0, 7.0][i];
            }
            return Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: isPlaying && !isLoading ? color : color.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.only(left: 6, right: 6, top: 6, bottom: 6),
      decoration: const BoxDecoration(color: Color(0xFFF7F7F7), border: Border(top: BorderSide(color: Color(0xFFDFDFDF), width: 0.5))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(width: 36, height: 36, child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isVoiceMode = !_isVoiceMode;
                    if (_isVoiceMode) {
                      _focusNode.unfocus();
                      _hidePlusPanel();
                      _showEmojiPanel = false;
                    }
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Center(child: Icon(_isVoiceMode ? Icons.keyboard_outlined : Icons.mic_none, size: 24, color: const Color(0xFF666666))),
              )),
              const SizedBox(width: 4),
              if (_isVoiceMode)
                Expanded(
                  child: GestureDetector(
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressMoveUpdate: (details) {
                      final dy = details.globalPosition.dy;
                      final screenH = MediaQuery.of(context).size.height;
                      // 上滑超过 80px 触发取消区域
                      final slideUp = dy < screenH - 80;
                      if (slideUp != _recordSlideUp) {
                        setState(() {
                          _recordSlideUp = slideUp;
                          _recordCancelled = slideUp;
                        });
                      }
                      // 计算上滑距离用于动画
                      final slideDistance = (screenH - 80 - dy).clamp(0.0, 200.0);
                      setState(() => _recordSlideY = slideDistance);
                    },
                    onLongPressEnd: (_) => _stopRecording(cancel: _recordCancelled),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? (_recordSlideUp ? const Color(0xFFFF4444) : const Color(0xFFE0E0E0))
                            : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFDFDFDF), width: 0.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _isRecording
                            ? (_recordSlideUp ? '松开手指，取消发送' : '手指上滑，取消发送')
                            : '按住 说话',
                        style: TextStyle(
                          fontSize: 15,
                          color: _isRecording
                              ? (_recordSlideUp ? Colors.white : const Color(0xFF666666))
                              : const Color(0xFF666666),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 72, minHeight: 36),
                    child: ExtendedTextField(
                      controller: _msgCtrl,
                      focusNode: _focusNode,
                      style: const TextStyle(fontSize: 16, height: 1.3),
                      maxLines: null,
                      specialTextSpanBuilder: ChatEmojiSpanBuilder(),
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        hintStyle: const TextStyle(fontSize: 16, color: Color(0xFFCCCCCC), height: 1.3),
                        filled: true, fillColor: Colors.white, isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFDFDFDF), width: 0.5)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFDFDFDF), width: 0.5)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFDFDFDF), width: 0.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              SizedBox(width: 36, height: 36, child: GestureDetector(
                onTap: () {
                  if (_showEmojiPanel) {
                    setState(() => _showEmojiPanel = false);
                    _focusNode.requestFocus();
                  } else {
                    _focusNode.unfocus();
                    setState(() {
                      _showPlusPanel = false;
                      _showEmojiPanel = true;
                      _isVoiceMode = false; // 点击表情时退出语音模式
                    });
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Center(child: Icon(_showEmojiPanel ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined, size: 24, color: const Color(0xFF666666))),
              )),
              if (!_hasText && !_isVoiceMode) SizedBox(width: 36, height: 36, child: GestureDetector(onTap: _togglePlusPanel, behavior: HitTestBehavior.opaque, child: const Center(child: Icon(Icons.add_circle_outline, size: 24, color: Color(0xFF666666))))),
              if (_hasText)
                GestureDetector(
                  onTapDown: (_) => _sendBtnCtrl.reverse(),
                  onTapUp: (_) { _sendBtnCtrl.forward(); _sendMessage(); },
                  onTapCancel: () => _sendBtnCtrl.forward(),
                  child: ScaleTransition(
                    scale: _sendBtnCtrl,
                    child: Container(
                      height: 36, padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: const Color(0xFF07C160), borderRadius: BorderRadius.circular(4)),
                      alignment: Alignment.center,
                      child: const Text('发送', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500, height: 1.0)),
                    ),
                  ),
                ),
            ],
          ),
          if (_isRecording)
            _buildVoiceRecordOverlay(),
        ],
      ),
    );
  }

  /// 微信风格语音录制全屏覆盖层
  Widget _buildVoiceRecordOverlay() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: _recordSlideUp ? const Color(0xFFFFF0F0) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 声波动画条
            _buildVoiceWaveBars(),
            const SizedBox(height: 16),
            // 取消/发送提示
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 取消按钮
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _recordSlideUp ? const Color(0xFFFF4444) : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 14,
                      color: _recordSlideUp ? Colors.white : const Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // 中间提示文字
                Column(
                  children: [
                    Text(
                      _recordSlideUp ? '松开 取消' : '松开 发送',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF333333),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _recordSlideUp
                          ? '手指上滑，取消发送'
                          : '手指上滑，取消发送',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 录制时长
            Text(
              '${_recordSeconds ~/ 60}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 微信风格声波动画条（丝滑版，用AnimationController驱动）
  Widget _buildVoiceWaveBars() {
    return AnimatedBuilder(
      animation: _voiceWaveCtrl,
      builder: (_, __) {
        return SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(20, (i) {
              // 基础高度：中间高两边低的正弦包络
              final envelope = sin((i / 19) * pi);
              // 动态波动：多层正弦叠加，丝滑连续
              final wave1 = sin(_voiceWaveCtrl.value * 2 * pi + i * 0.6) * 0.4;
              final wave2 = sin(_voiceWaveCtrl.value * 2 * pi * 1.7 + i * 0.9) * 0.25;
              final wave3 = sin(_voiceWaveCtrl.value * 2 * pi * 0.5 + i * 1.3) * 0.15;
              final combined = envelope * (0.3 + wave1 + wave2 + wave3);
              final h = (combined * 32 + 4).clamp(4.0, 36.0);
              return Container(
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: _recordSlideUp ? const Color(0xFFFF4444) : const Color(0xFF07C160),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  void _showRedPacketDialog() {
    final coinsCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF4444), Color(0xFFE53935)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 20),
            const Text('发红包', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  const Text('留币', style: TextStyle(fontSize: 15, color: Color(0xFF333333), fontWeight: FontWeight.w500)),
                  const Spacer(),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: coinsCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      autofocus: true,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFF4444)),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(fontSize: 24, color: Color(0xFFCCCCCC), fontWeight: FontWeight.bold),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ]),
                const Divider(height: 24),
                TextField(
                  controller: msgCtrl,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
                  maxLength: 20,
                  decoration: const InputDecoration(
                    hintText: '恭喜发财，大吉大利',
                    hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
                    border: InputBorder.none,
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () async {
                  final coins = int.tryParse(coinsCtrl.text) ?? 0;
                  if (coins <= 0) { AppToast.info(context, message: '请输入留币数量'); return; }
                  if (coins > 10000) { AppToast.info(context, message: '单次最多10000留币'); return; }
                  Navigator.pop(context);
                  await _sendRedPacket(coins, msgCtrl.text.trim().isEmpty ? '恭喜发财，大吉大利' : msgCtrl.text.trim());
                },
                child: Container(
                  width: double.infinity, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFFB300)]),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: const Text('塞钱进红包', style: TextStyle(fontSize: 15, color: Color(0xFFBF360C), fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Future<void> _sendRedPacket(int coins, String message) async {
    final up = Provider.of<UserProvider>(context, listen: false);
    // 检查留币余额
    if ((up.userInfo?.coins ?? 0) < coins) {
      AppToast.info(context, message: '留币不足');
      return;
    }
    final now = DateTime.now().toIso8601String();
    final localMsg = {
      'sender_id': up.userInfo?.id,
      'sender_name': up.userInfo?.nickname ?? '',
      'sender_avatar': up.userInfo?.avatar ?? '',
      'content': json.encode({'coins': coins, 'message': message}),
      'type': 6,
      'is_recalled': 0,
      'created_at': now,
      '_uploading': true,
      '_localId': '${DateTime.now().microsecondsSinceEpoch}_${_messages.length}',
    };
    setState(() => _messages.add(localMsg));
    _scheduleScrollToBottom();
    StorageService.appendChatMessages(widget.conversationId, [localMsg]);

    try {
      final cs = Provider.of<ChatService>(context, listen: false);
      if (!cs.isConnected) {
        await cs.connect();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await cs.sendMessage(widget.conversationId, json.encode({'coins': coins, 'message': message}), 6);
      setState(() { localMsg['_uploading'] = false; });
      StorageService.saveChatMessages(widget.conversationId, _messages);
    } catch (e) {
      debugPrint('[ChatScreen] 发送红包失败: $e');
      if (mounted) {
        setState(() {
          localMsg['_uploading'] = false;
          localMsg['_uploadFailed'] = true;
        });
      }
    }
  }

  void _openRedPacket(Map<String, dynamic> msg, int coins, String rpMsg) {
    final up = Provider.of<UserProvider>(context, listen: false);
    final isSelf = msg['sender_id'] == up.userInfo?.id;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF4444), Color(0xFFD32F2F)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          CircleAvatar(
            radius: 24,
            backgroundImage: CachedNetworkImageProvider(fullUrl(msg['sender_avatar'] ?? '')),
          ),
          const SizedBox(height: 8),
          Text(msg['sender_name'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFFFFE0B2))),
          const SizedBox(height: 12),
          Text(rpMsg, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 16),
          Text('$coins', style: const TextStyle(fontSize: 40, color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, height: 1.2)),
          const Text('留币', style: TextStyle(fontSize: 13, color: Color(0xFFFFE0B2))),
          if (!isSelf) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(color: Color(0xFFFFD54F), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Text('开', style: TextStyle(fontSize: 28, color: Color(0xFFBF360C), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _buildPlusPanel(double bottomPad) {
    return Container(
      color: const Color(0xFFF7F7F7),
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 12 + bottomPad),
      child: Row(children: [
        _plusPanelItem(Icons.image_outlined, '图片', _sendImage),
        const SizedBox(width: 20),
        _plusPanelItem(Icons.card_giftcard, '红包', _showRedPacketDialog),
      ]),
    );
  }

  Widget _buildChatEmojiPanel() {
    return EmojiPickerPanel(
      onEmojiSelected: (assetPath) {
        _emojiInserting = true;
        final filename = assetPath.split('/').last;
        final marker = '[emoji:$filename]';
        final text = _msgCtrl.text;
        final cursorPos = _msgCtrl.selection.start;
        final insertPos = cursorPos < 0 ? text.length : cursorPos;
        _msgCtrl.text = text.substring(0, insertPos) + marker + text.substring(insertPos);
        _msgCtrl.selection = TextSelection.collapsed(offset: insertPos + marker.length);
        setState(() { _hasText = _msgCtrl.text.isNotEmpty; });
        Future.microtask(() => _emojiInserting = false);
      },
    );
  }

  Widget _plusPanelItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 26, color: const Color(0xFF666666))),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
      ]),
    );
  }
}

class _MsgBubbleWrapper extends StatelessWidget {
  final void Function(BuildContext bubbleContext) onLongPress;
  final bool isSelf;
  final int convType;
  final String senderName;
  final String avatarUrl;
  final String avatarName;
  final int avatarId;
  final Widget bubble;

  const _MsgBubbleWrapper({
    required this.onLongPress,
    required this.isSelf,
    required this.convType,
    required this.senderName,
    required this.avatarUrl,
    required this.avatarName,
    required this.avatarId,
    required this.bubble,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSelf) ...[
            GestureDetector(onTap: () { if (avatarId > 0) Navigator.pushNamed(context, '/user-profile', arguments: avatarId); }, child: _buildAvatar(avatarUrl, avatarName, avatarId, 20)),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (convType == 2 && !isSelf) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(senderName, style: const TextStyle(fontSize: 11, color: Color(0xFF999999)))),
              Builder(builder: (bubbleCtx) => GestureDetector(onLongPress: () => onLongPress(bubbleCtx), child: bubble)),
            ],
          ),
          if (isSelf) ...[
            const SizedBox(width: 8),
            _buildAvatar(avatarUrl, avatarName, avatarId, 20),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String url, String name, int id, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
      backgroundColor: url.isEmpty ? getColorForId(id) : null,
      child: url.isEmpty ? Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(fontSize: radius * 0.7, color: Colors.white, fontWeight: FontWeight.w500)) : null,
    );
  }
}

class ChatEmojiText extends SpecialText {
  static const String flag = '[emoji:';
  final int startIndex;

  ChatEmojiText(TextStyle? textStyle, {SpecialTextGestureTapCallback? onTap, required this.startIndex})
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

class ChatEmojiSpanBuilder extends SpecialTextSpanBuilder {
  @override
  SpecialText? createSpecialText(String flag, {TextStyle? textStyle, SpecialTextGestureTapCallback? onTap, int? index}) {
    if (isStart(flag, ChatEmojiText.flag)) {
      final startIndex = (index ?? 0) - ChatEmojiText.flag.length + 1;
      return ChatEmojiText(textStyle, onTap: onTap, startIndex: startIndex);
    }
    return null;
  }
}
