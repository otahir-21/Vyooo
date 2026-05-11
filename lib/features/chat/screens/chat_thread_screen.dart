import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/user_facing_errors.dart';
import '../../../core/models/app_user_model.dart';
import '../models/call_session_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/call_signaling_service.dart';
import '../services/chat_media_service.dart';
import '../services/chat_notification_service.dart';
import '../services/chat_service.dart';
import '../services/presence_service.dart';
import '../services/typing_indicator_service.dart';
import '../utils/chat_constants.dart';
import '../utils/view_once_helpers.dart';
import '../widgets/audio_message_bubble.dart';
import '../widgets/call_message_bubble.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/media_message_widget.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';
import '../widgets/typing_indicator_widget.dart';
import '../widgets/view_once_message_widget.dart';
import 'chat_call_screen.dart';
import 'chat_info_screen.dart';
import 'group_info_screen.dart';
import 'incoming_call_screen.dart';
import 'view_once_media_viewer_screen.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.chatId,
    required this.currentUser,
    this.otherUser,
    this.chatType = ChatTypes.direct,
    this.groupName,
    this.groupImageUrl,
    this.participantIds = const [],
  });

  final String chatId;
  final AppUserModel currentUser;
  final AppUserModel? otherUser;
  final String chatType;
  final String? groupName;
  final String? groupImageUrl;
  final List<String> participantIds;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final ChatService _chatService = ChatService();
  final ChatMediaService _mediaService = ChatMediaService();
  final ScrollController _scrollController = ScrollController();
  final TypingIndicatorService _typingService = TypingIndicatorService.instance;
  final CallSignalingService _callSignaling = CallSignalingService();

  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _uploadError;
  bool _isStartingCall = false;

  ChatModel? _chatModel;
  bool _isMuted = false;
  String? _presenceText;
  StreamSubscription<Map<String, dynamic>?>? _presenceSub;
  StreamSubscription<List<CallSessionModel>>? _incomingCallSub;

  bool get _isGroup =>
      widget.chatType == ChatTypes.group ||
      (_chatModel?.type == ChatTypes.group);

  List<String> get _participantIds {
    if (_chatModel != null) return _chatModel!.participantIds;
    if (widget.participantIds.isNotEmpty) return widget.participantIds;
    if (widget.otherUser != null) {
      return [widget.currentUser.uid, widget.otherUser!.uid];
    }
    return [widget.currentUser.uid];
  }

  @override
  void initState() {
    super.initState();
    ChatNotificationService.instance.setActiveChatId(widget.chatId);
    _chatService.markChatRead(
      uid: widget.currentUser.uid,
      chatId: widget.chatId,
    );
    _loadChatModel();
    _startPresenceWatch();
    _startIncomingCallWatch();
  }

  Future<void> _loadChatModel() async {
    final chat = await _chatService.getChat(widget.chatId);
    if (!mounted) return;
    setState(() {
      _chatModel = chat;
      _isMuted = chat?.mutedBy.contains(widget.currentUser.uid) ?? false;
    });
  }

  void _startPresenceWatch() {
    if (_isGroup) return;
    final otherUid = widget.otherUser?.uid;
    if (otherUid == null || otherUid.isEmpty) return;
    _presenceSub = PresenceService.instance.watchPresence(otherUid).listen((
      data,
    ) {
      if (!mounted) return;
      String? text;
      if (data != null) {
        final isOnline = data['isOnline'] as bool? ?? false;
        if (isOnline) {
          text = 'Active now';
        } else {
          final lastActive = data['lastActiveAt'] as Timestamp?;
          if (lastActive != null) {
            final diff = DateTime.now().difference(lastActive.toDate());
            if (diff.inMinutes < 1) {
              text = 'Active just now';
            } else if (diff.inMinutes < 60) {
              text = 'Active ${diff.inMinutes}m ago';
            } else if (diff.inHours < 24) {
              text = 'Active ${diff.inHours}h ago';
            }
          }
        }
      }
      setState(() => _presenceText = text);
    });
  }

  @override
  void dispose() {
    ChatNotificationService.instance.setActiveChatId(null);
    _presenceSub?.cancel();
    _incomingCallSub?.cancel();
    _typingService.clearTyping(
      chatId: widget.chatId,
      uid: widget.currentUser.uid,
    );
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend(String text) {
    _chatService.sendTextMessage(
      chatId: widget.chatId,
      senderId: widget.currentUser.uid,
      participantIds: _participantIds,
      text: text,
    );
    _chatService.markChatRead(
      uid: widget.currentUser.uid,
      chatId: widget.chatId,
    );
  }

  Future<void> _handleMediaAction(MediaAction action) async {
    XFile? file;
    String type;
    bool isViewOnce = false;

    try {
      switch (action) {
        case MediaAction.galleryPhoto:
          file = await _mediaService.pickImageFromGallery();
          type = ChatMessageTypes.image;
        case MediaAction.galleryVideo:
          file = await _mediaService.pickVideoFromGallery();
          type = ChatMessageTypes.video;
        case MediaAction.cameraPhoto:
          file = await _mediaService.captureImageFromCamera();
          type = ChatMessageTypes.image;
        case MediaAction.cameraVideo:
          file = await _mediaService.captureVideoFromCamera();
          type = ChatMessageTypes.video;
        case MediaAction.viewOncePhoto:
          file = await _mediaService.pickImageFromGallery();
          type = ChatMessageTypes.image;
          isViewOnce = true;
        case MediaAction.viewOnceVideo:
          file = await _mediaService.pickVideoFromGallery();
          type = ChatMessageTypes.video;
          isViewOnce = true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not pick media: $e')));
      }
      return;
    }

    if (file == null) return;
    await _uploadAndSend(file, type, isViewOnce: isViewOnce);
  }

  Future<void> _handleVoiceNote(File file, int durationMs) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadError = null;
    });
    try {
      if (!file.existsSync()) {
        throw const ChatMediaException('Recording file not found');
      }
      final fileSize = file.lengthSync();
      if (fileSize == 0) {
        throw const ChatMediaException('Recording file is empty');
      }
      debugPrint(
        '[ChatThread] voice note: path=${file.path} size=$fileSize dur=$durationMs',
      );

      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc();
      final messageId = messageRef.id;

      debugPrint('[ChatThread] voice note: uploading to storage...');
      final result = await _mediaService.uploadAudioMessage(
        chatId: widget.chatId,
        senderId: widget.currentUser.uid,
        messageId: messageId,
        file: file,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
      debugPrint('[ChatThread] voice note: upload OK, writing message...');

      await _chatService.sendMediaMessage(
        chatId: widget.chatId,
        senderId: widget.currentUser.uid,
        participantIds: _participantIds,
        type: ChatMessageTypes.audio,
        mediaUrl: result.mediaUrl,
        storagePath: result.storagePath,
        durationMs: durationMs,
      );
      debugPrint('[ChatThread] voice note: sent OK');

      _chatService.markChatRead(
        uid: widget.currentUser.uid,
        chatId: widget.chatId,
      );
    } on ChatMediaException catch (e) {
      debugPrint('[ChatThread] voice note media error: ${e.message}');
      if (mounted) {
        setState(() => _uploadError = e.message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e, st) {
      debugPrint('[ChatThread] voice note send error: $e');
      debugPrint('[ChatThread] voice note stacktrace: $st');
      if (mounted) {
        setState(() => _uploadError = '$e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice note error: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  Future<void> _uploadAndSend(
    XFile file,
    String type, {
    bool isViewOnce = false,
  }) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadError = null;
    });

    try {
      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc();
      final messageId = messageRef.id;

      final isImage = type == ChatMessageTypes.image;
      final result = isImage
          ? await _mediaService.uploadImageMessage(
              chatId: widget.chatId,
              senderId: widget.currentUser.uid,
              messageId: messageId,
              file: file,
              onProgress: (p) {
                if (mounted) setState(() => _uploadProgress = p);
              },
            )
          : await _mediaService.uploadVideoMessage(
              chatId: widget.chatId,
              senderId: widget.currentUser.uid,
              messageId: messageId,
              file: file,
              onProgress: (p) {
                if (mounted) setState(() => _uploadProgress = p);
              },
            );

      if (isViewOnce) {
        await _chatService.sendViewOnceMediaMessage(
          chatId: widget.chatId,
          senderId: widget.currentUser.uid,
          participantIds: _participantIds,
          type: type,
          mediaUrl: result.mediaUrl,
          storagePath: result.storagePath,
          thumbnailUrl: result.thumbnailUrl,
          width: result.width,
          height: result.height,
          durationMs: result.durationMs,
        );
      } else {
        await _chatService.sendMediaMessage(
          chatId: widget.chatId,
          senderId: widget.currentUser.uid,
          participantIds: _participantIds,
          type: type,
          mediaUrl: result.mediaUrl,
          storagePath: result.storagePath,
          thumbnailUrl: result.thumbnailUrl,
          width: result.width,
          height: result.height,
          durationMs: result.durationMs,
        );
      }

      _chatService.markChatRead(
        uid: widget.currentUser.uid,
        chatId: widget.chatId,
      );
    } on ChatMediaException catch (e) {
      if (mounted) {
        setState(() => _uploadError = e.message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadError = 'Upload failed');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to send media')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  Future<void> _handleToggleMute() async {
    if (_isMuted) {
      await _chatService.unmuteChat(
        uid: widget.currentUser.uid,
        chatId: widget.chatId,
      );
    } else {
      await _chatService.muteChat(
        uid: widget.currentUser.uid,
        chatId: widget.chatId,
      );
    }
    setState(() => _isMuted = !_isMuted);
  }

  Future<void> _handleClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1B2E),
        title: const Text('Clear chat', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will hide all messages for you. Other participants are not affected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.deleteRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _chatService.clearChat(
          uid: widget.currentUser.uid,
          chatId: widget.chatId,
        );
        await _loadChatModel();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat cleared')));
      } catch (e) {
        debugPrint('[ChatThread] clearChat failed: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not clear chat')));
      }
    }
  }

  void _openGroupInfo() {
    if (_chatModel == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupInfoScreen(
          chatId: widget.chatId,
          currentUser: widget.currentUser,
          chatModel: _chatModel!,
        ),
      ),
    );
  }

  void _handleHeaderTap() {
    if (_isGroup) {
      _openGroupInfo();
    } else if (widget.otherUser != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatInfoScreen(
            chatId: widget.chatId,
            currentUser: widget.currentUser,
            otherUser: widget.otherUser!,
            isMuted: _isMuted,
            onMuteToggled: () {
              if (mounted) setState(() => _isMuted = !_isMuted);
            },
            onChatCleared: () {
              _loadChatModel();
            },
          ),
        ),
      );
    }
  }

  Future<void> _handleDeleteMessage(MessageModel msg) async {
    final isSender = msg.senderId == widget.currentUser.uid;
    final canDeleteForEveryone =
        isSender &&
        msg.createdAt != null &&
        DateTime.now().difference(msg.createdAt!.toDate()).inMinutes <=
            ChatLimits.deleteForEveryoneWindowMinutes;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1B2E),
        title: const Text(
          'Delete message',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Choose how to delete this message.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'self'),
            child: const Text('Delete for me'),
          ),
          if (canDeleteForEveryone)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'everyone'),
              child: const Text(
                'Delete for everyone',
                style: TextStyle(color: AppColors.deleteRed),
              ),
            ),
        ],
      ),
    );

    if (result == 'self') {
      await _chatService.deleteMessageForUser(
        uid: widget.currentUser.uid,
        chatId: widget.chatId,
        messageId: msg.id,
      );
    } else if (result == 'everyone') {
      await _chatService.deleteMessageForEveryone(
        uid: widget.currentUser.uid,
        chatId: widget.chatId,
        messageId: msg.id,
        messageCreatedAt: msg.createdAt,
      );
    }
  }

  String _formatMessageTime(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String? _senderName(MessageModel msg) {
    if (!_isGroup) return null;
    if (msg.senderId == widget.currentUser.uid) return null;
    final participant = _chatModel?.participantMap[msg.senderId];
    if (participant != null) {
      final dn = participant.displayName.trim();
      return dn.isNotEmpty ? dn : participant.username;
    }
    return msg.senderId.substring(0, 6);
  }

  String? _seenText(MessageModel msg, bool isSent, bool isLastSentMsg) {
    if (!isSent || !isLastSentMsg) return null;
    if (msg.deletedForEveryone) return null;
    final seenBy = msg.seenBy;
    if (_isGroup) {
      final othersWhoSeen = seenBy
          .where((uid) => uid != widget.currentUser.uid)
          .length;
      if (othersWhoSeen > 0) return 'Seen by $othersWhoSeen';
      return 'Sent';
    } else {
      final otherUid = widget.otherUser?.uid;
      if (otherUid != null && seenBy.contains(otherUid)) return 'Seen';
      return 'Sent';
    }
  }

  Widget _buildMediaBubble(
    MessageModel msg,
    bool isSent,
    String time, {
    String? seenText,
  }) {
    final name = _senderName(msg);
    final media = MediaMessageWidget(
      message: msg,
      isSent: isSent,
      time: time,
      seenText: seenText,
    );
    if (name == null) return media;
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 2),
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.brandMagenta,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          media,
        ],
      ),
    );
  }

  void _handleTypingChanged(bool isTyping) {
    if (isTyping) {
      _typingService.setTyping(
        chatId: widget.chatId,
        uid: widget.currentUser.uid,
        displayName:
            widget.currentUser.displayName ?? widget.currentUser.username ?? '',
      );
    } else {
      _typingService.clearTyping(
        chatId: widget.chatId,
        uid: widget.currentUser.uid,
      );
    }
  }

  final Set<String> _shownIncomingCallIds = {};

  void _startIncomingCallWatch() {
    _incomingCallSub = _callSignaling
        .watchIncomingCalls(widget.currentUser.uid)
        .listen((calls) {
          if (!mounted) return;
          final relevant = calls
              .where((c) => c.chatId == widget.chatId)
              .toList();
          if (relevant.isEmpty) return;
          final call = relevant.first;
          if (_shownIncomingCallIds.contains(call.id)) return;
          _shownIncomingCallIds.add(call.id);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => IncomingCallScreen(
                callSession: call,
                currentUid: widget.currentUser.uid,
                callerName: _isGroup
                    ? (_chatModel?.groupName ?? widget.groupName)
                    : (widget.otherUser?.displayName ??
                          widget.otherUser?.username),
                callerAvatarUrl: _isGroup
                    ? (_chatModel?.groupImageUrl ?? widget.groupImageUrl)
                    : widget.otherUser?.profileImage,
              ),
            ),
          );
        });
  }

  Future<void> _handleAudioCall() async {
    await _startCall(CallType.audio);
  }

  Future<void> _handleVideoCall() async {
    await _startCall(CallType.video);
  }

  Future<void> _startCall(String type) async {
    if (_isStartingCall) return;
    setState(() => _isStartingCall = true);
    try {
      debugPrint(
        '[ChatThread] _startCall: chatId=${widget.chatId} '
        'callerId=${widget.currentUser.uid} participants=$_participantIds type=$type',
      );
      final callSession = await _callSignaling.startCall(
        chatId: widget.chatId,
        callerId: widget.currentUser.uid,
        participantIds: _participantIds,
        type: type,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatCallScreen(
            callSession: callSession,
            currentUid: widget.currentUser.uid,
            callerName: _isGroup
                ? (_chatModel?.groupName ?? widget.groupName)
                : (widget.otherUser?.displayName ?? widget.otherUser?.username),
          ),
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, st) {
      debugPrint('[ChatThread] _startCall failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not start call')));
    } finally {
      if (mounted) setState(() => _isStartingCall = false);
    }
  }

  void _openViewOnceMedia(MessageModel msg) {
    if (!ViewOnceHelpers.canOpen(
      message: msg,
      currentUid: widget.currentUser.uid,
    )) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ViewOnceMediaViewerScreen(
          message: msg,
          currentUid: widget.currentUser.uid,
          chatId: widget.chatId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emptyName = _isGroup
        ? (widget.groupName ?? 'the group')
        : (widget.otherUser?.displayName ??
              widget.otherUser?.username ??
              'them');

    return Scaffold(
      backgroundColor: const Color(0xFF07010F),
      appBar: ChatAppBar(
        otherUser: widget.otherUser,
        chatType: _isGroup ? ChatTypes.group : ChatTypes.direct,
        groupName: _chatModel?.groupName ?? widget.groupName,
        groupImageUrl: _chatModel?.groupImageUrl ?? widget.groupImageUrl,
        memberCount:
            _chatModel?.participantIds.length ?? widget.participantIds.length,
        isMuted: _isMuted,
        onMenuMute: _handleToggleMute,
        onMenuClear: _handleClearChat,
        onMenuGroupInfo: _isGroup ? _openGroupInfo : null,
        presenceText: _presenceText,
        onHeaderTap: _handleHeaderTap,
        onAudioCall: _participantIds.length >= 2 && !_isStartingCall
            ? _handleAudioCall
            : null,
        onVideoCall: _participantIds.length >= 2 && !_isStartingCall
            ? _handleVideoCall
            : null,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.4, 1.0],
                  colors: [
                    Color(0xFF1A0826),
                    Color(0xFF10041A),
                    Color(0xFF07010F),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -80,
            right: -80,
            child: Container(
              height: 360,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x55DE106B), Color(0x00000000)],
                  radius: 0.7,
                ),
              ),
            ),
          ),
          Column(
            children: [
              if (_isUploading) _buildUploadIndicator(),
              if (_uploadError != null && !_isUploading) _buildRetryBanner(),
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _chatService.watchMessages(
                    widget.chatId,
                    widget.currentUser.uid,
                    clearedAt: _chatModel?.clearedAtBy[widget.currentUser.uid],
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFDE106B),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            messageForFirestore(snapshot.error),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                        ),
                      );
                    }

                    final messages = snapshot.data ?? [];
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white.withValues(alpha: 0.2),
                              size: 64,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Say hi to $emptyName!',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    _chatService.markMessagesSeen(
                      chatId: widget.chatId,
                      uid: widget.currentUser.uid,
                      messages: messages,
                    );
                    _chatService.markChatRead(
                      uid: widget.currentUser.uid,
                      chatId: widget.chatId,
                    );

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });

                    int? lastSentIdx;
                    for (var i = messages.length - 1; i >= 0; i--) {
                      if (messages[i].senderId == widget.currentUser.uid &&
                          !messages[i].deletedForEveryone) {
                        lastSentIdx = i;
                        break;
                      }
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isSent = msg.senderId == widget.currentUser.uid;
                        final time = _formatMessageTime(msg.createdAt);
                        final isLastSent = index == lastSentIdx;
                        final seen = _seenText(msg, isSent, isLastSent);

                        Widget bubble;
                        if (msg.deletedForEveryone) {
                          bubble = MessageBubble(
                            text: '',
                            isSent: isSent,
                            time: time,
                            isDeleted: true,
                            senderName: _senderName(msg),
                          );
                        } else if (msg.isViewOnce &&
                            (msg.type == ChatMessageTypes.image ||
                                msg.type == ChatMessageTypes.video)) {
                          bubble = ViewOnceMessageWidget(
                            message: msg,
                            isSent: isSent,
                            time: time,
                            currentUid: widget.currentUser.uid,
                            isGroup: _isGroup,
                            senderName: _senderName(msg),
                            onTap: () => _openViewOnceMedia(msg),
                          );
                        } else if (msg.type == ChatMessageTypes.image ||
                            msg.type == ChatMessageTypes.video) {
                          bubble = _buildMediaBubble(
                            msg,
                            isSent,
                            time,
                            seenText: seen,
                          );
                        } else if (msg.type == ChatMessageTypes.call) {
                          bubble = CallMessageBubble(
                            message: msg,
                            isSent: isSent,
                          );
                        } else if (msg.type == ChatMessageTypes.audio) {
                          bubble = AudioMessageBubble(
                            message: msg,
                            isSent: isSent,
                            time: time,
                            senderName: _senderName(msg),
                            seenText: seen,
                          );
                        } else {
                          bubble = MessageBubble(
                            text: msg.text,
                            isSent: isSent,
                            time: time,
                            isDeleted: false,
                            senderName: _senderName(msg),
                            seenText: seen,
                          );
                        }

                        return GestureDetector(
                          onLongPress: () => _handleDeleteMessage(msg),
                          child: bubble,
                        );
                      },
                    );
                  },
                ),
              ),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _typingService.watchTyping(
                  chatId: widget.chatId,
                  excludeUid: widget.currentUser.uid,
                ),
                builder: (context, snapshot) {
                  final typingUsers = snapshot.data ?? [];
                  return TypingIndicatorWidget(
                    typingUsers: typingUsers,
                    isGroup: _isGroup,
                  );
                },
              ),
              MessageInputBar(
                onSend: _handleSend,
                onMediaAction: _handleMediaAction,
                mediaLoading: _isUploading,
                onTypingChanged: _handleTypingChanged,
                onVoiceNoteSend: _handleVoiceNote,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1A061E),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: Color(0xFFDE106B),
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sending media...',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.white12,
                    color: AppColors.brandMagenta,
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.deleteRed.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.deleteRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _uploadError ?? 'Upload failed',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _uploadError = null),
            child: const Icon(Icons.close, color: Colors.white38, size: 18),
          ),
        ],
      ),
    );
  }
}
