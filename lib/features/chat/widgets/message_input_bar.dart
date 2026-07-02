import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_padding.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../utils/chat_constants.dart';

enum MediaAction {
  galleryPhoto,
  galleryVideo,
  cameraPhoto,
  cameraVideo,
  viewOncePhoto,
  viewOnceVideo,
}

class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    required this.onSend,
    this.onMediaAction,
    this.onGifTap,
    this.mediaLoading = false,
    this.onTypingChanged,
    this.onVoiceNoteSend,
    this.replyingToSenderName,
    this.replyingToPreview,
    this.onCancelReply,
  });

  final void Function(String text) onSend;
  final void Function(MediaAction action)? onMediaAction;
  final VoidCallback? onGifTap;
  final bool mediaLoading;
  final void Function(bool isTyping)? onTypingChanged;
  final void Function(File file, int durationMs)? onVoiceNoteSend;
  final String? replyingToSenderName;
  final String? replyingToPreview;
  final VoidCallback? onCancelReply;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _canSend = false;
  bool _wasTyping = false;
  bool _showEmojiRow = false;

  bool _isRecording = false;
  RecorderController? _recorderController;

  String? _pendingFilePath;
  int _pendingDuration = 0;
  bool _isSendingVoice = false;

  static const List<String> _quickEmojis = [
    '😂',
    '❤️',
    '🔥',
    '👏',
    '😮',
    '😢',
    '😍',
    '👍',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _canSend) setState(() => _canSend = hasText);
      if (hasText && !_wasTyping) {
        _wasTyping = true;
        widget.onTypingChanged?.call(true);
      } else if (!hasText && _wasTyping) {
        _wasTyping = false;
        widget.onTypingChanged?.call(false);
      }
    });
  }

  @override
  void didUpdateWidget(MessageInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final startedReply =
        widget.replyingToSenderName != null && oldWidget.replyingToSenderName == null;
    if (startedReply) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    if (_wasTyping) widget.onTypingChanged?.call(false);
    _controller.dispose();
    _focusNode.dispose();
    _recorderController?.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    _wasTyping = false;
    widget.onTypingChanged?.call(false);
  }

  void _insertEmoji(String emoji) {
    final sel = _controller.selection;
    final text = _controller.text;
    final newText = text.replaceRange(
      sel.start < 0 ? text.length : sel.start,
      sel.end < 0 ? text.length : sel.end,
      emoji,
    );
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (sel.start < 0 ? text.length : sel.start) + emoji.length,
      ),
    );
  }

  Future<void> _startRecording() async {
    if (widget.onVoiceNoteSend == null) return;
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }
    _recorderController = RecorderController();
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorderController!.record(path: path);
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('[MessageInputBar] record error: $e');
      _recorderController?.dispose();
      _recorderController = null;
    }
  }

  Future<void> _stopRecording() async {
    if (_recorderController == null) return;
    try {
      final duration = _recorderController!.elapsedDuration.inMilliseconds;
      final path = await _recorderController!.stop();
      _recorderController!.dispose();
      _recorderController = null;
      setState(() {
        _isRecording = false;
        if (path != null && path.isNotEmpty && duration > 500) {
          _pendingFilePath = path;
          _pendingDuration = duration;
        } else if (path != null && path.isNotEmpty) {
          _pendingFilePath = path;
          _pendingDuration = duration > 0 ? duration : 1000;
        }
      });
    } catch (e) {
      debugPrint('[MessageInputBar] stop record error: $e');
      _recorderController?.dispose();
      _recorderController = null;
      setState(() => _isRecording = false);
    }
  }

  Future<void> _cancelRecording() async {
    if (_recorderController == null) return;
    try {
      await _recorderController!.stop();
    } catch (_) {}
    _recorderController?.dispose();
    _recorderController = null;
    setState(() => _isRecording = false);
    _discardPendingVoice();
  }

  void _sendPendingVoice() {
    if (_isSendingVoice) return;
    final path = _pendingFilePath;
    final dur = _pendingDuration;
    if (path == null || path.isEmpty || dur <= 0) return;
    setState(() => _isSendingVoice = true);
    widget.onVoiceNoteSend?.call(File(path), dur);
    setState(() {
      _pendingFilePath = null;
      _pendingDuration = 0;
      _isSendingVoice = false;
    });
  }

  void _discardPendingVoice() {
    final path = _pendingFilePath;
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    setState(() {
      _pendingFilePath = null;
      _pendingDuration = 0;
    });
  }

  void _showMediaSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0A2E), Color(0xFF0D0518)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _sheetTile(
                Icons.photo_library_outlined,
                'Photo from Gallery',
                MediaAction.galleryPhoto,
              ),
              _sheetTile(
                Icons.videocam_outlined,
                'Video from Gallery',
                MediaAction.galleryVideo,
              ),
              _sheetTile(
                Icons.camera_alt_outlined,
                'Take Photo',
                MediaAction.cameraPhoto,
              ),
              _sheetTile(
                Icons.videocam_outlined,
                'Record Video',
                MediaAction.cameraVideo,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.08),
                  height: 1,
                ),
              ),
              _sheetTile(
                Icons.photo_camera_outlined,
                'View-once Photo',
                MediaAction.viewOncePhoto,
              ),
              _sheetTile(
                Icons.videocam_outlined,
                'View-once Video',
                MediaAction.viewOnceVideo,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile(IconData icon, String label, MediaAction action) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF2A1540),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      onTap: () {
        Navigator.of(context).pop();
        widget.onMediaAction?.call(action);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = _pendingFilePath != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppPadding.screenHorizontal.left,
        AppSpacing.sm,
        AppPadding.screenHorizontal.right,
        AppSpacing.sm,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyingToSenderName != null &&
                widget.replyingToPreview != null)
              _buildReplyBanner(),
            if (hasPending)
              _buildVoicePreviewRow()
            else if (_isRecording)
              _buildRecordingRow()
            else
              _buildInputRow(),
            if (_showEmojiRow && !_isRecording && !hasPending) _buildEmojiRow(),
          ],
        ),
      ),
    );
  }

  Future<void> _stopAndSend() async {
    if (_recorderController == null) return;
    try {
      final duration = _recorderController!.elapsedDuration.inMilliseconds;
      final path = await _recorderController!.stop();
      _recorderController!.dispose();
      _recorderController = null;
      setState(() => _isRecording = false);
      if (path != null && path.isNotEmpty) {
        final dur = duration > 0 ? duration : 1000;
        widget.onVoiceNoteSend?.call(File(path), dur);
      }
    } catch (e) {
      debugPrint('[MessageInputBar] stopAndSend error: $e');
      _recorderController?.dispose();
      _recorderController = null;
      setState(() => _isRecording = false);
    }
  }

  Widget _buildRecordingRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _cancelRecording,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.deleteRed.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: AppColors.deleteRed,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AudioWaveforms(
            recorderController: _recorderController!,
            size: const Size(double.infinity, 36),
            waveStyle: const WaveStyle(
              waveColor: AppColors.brandMagenta,
              extendWaveform: true,
              showMiddleLine: false,
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.stop_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _stopAndSend,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFDE106B), Color(0xFF6B21A8)],
              ),
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  String _formatMs(int ms) {
    final s = (ms / 1000).floor();
    final m = (s / 60).floor().toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Widget _buildVoicePreviewRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _discardPendingVoice,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.deleteRed.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: AppColors.deleteRed,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDE106B), Color(0xFFB80D5A)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Expanded(child: _buildWaveformBars()),
                const SizedBox(width: 8),
                Text(
                  _formatMs(_pendingDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _isSendingVoice ? null : _sendPendingVoice,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFDE106B), Color(0xFF6B21A8)],
              ),
            ),
            child: _isSendingVoice
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildWaveformBars() {
    return CustomPaint(
      size: const Size(double.infinity, 20),
      painter: _WaveformBarsPainter(),
    );
  }

  Widget _buildReplyBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.chatSearchFill,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: AppColors.brandDeepMagenta, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.replyingToSenderName!,
                  style: const TextStyle(
                    color: AppColors.brandDeepMagenta,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replyingToPreview!,
                  style: const TextStyle(
                    color: AppColors.chatTextSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onCancelReply,
            icon: const Icon(
              Icons.close,
              color: AppColors.chatTextSecondary,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Container(
      height: AppSizes.chatMessageInputHeight,
      decoration: BoxDecoration(
        color: AppColors.chatInputBar,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 7.5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.md - AppSpacing.xs,
      ),
      child: Row(
        children: [
          _buildCameraButton(),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Message...',
                hintStyle: TextStyle(
                  color: AppColors.chatInputHint,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_canSend)
            _buildInputAction(
              icon: Icons.send_rounded,
              onTap: _handleSend,
              highlight: true,
            )
          else ...[
            if (widget.onVoiceNoteSend != null)
              _buildInputAction(
                icon: Icons.mic_none,
                onTap: _startRecording,
              ),
            _buildInputAction(
              assetPath: ChatAssets.inputGalleryIcon,
              assetWidth: 20,
              assetHeight: 20,
              onTap: widget.mediaLoading ? null : _showMediaSheet,
            ),
            _buildInputAction(
              assetPath: ChatAssets.inputStickerIcon,
              assetWidth: 22,
              assetHeight: 22,
              onTap: () => setState(() => _showEmojiRow = !_showEmojiRow),
              isActive: _showEmojiRow,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraButton() {
    return GestureDetector(
      onTap: widget.mediaLoading
          ? null
          : () => widget.onMediaAction?.call(MediaAction.cameraPhoto),
      child: Container(
        width: AppSizes.chatInputCameraButton,
        height: AppSizes.chatInputCameraButton,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.mediaLoading
              ? AppColors.chatDivider
              : AppColors.chatOutgoingBubble,
        ),
        child: Icon(
          Icons.camera_alt_outlined,
          color: widget.mediaLoading
              ? AppColors.chatTextSecondary
              : Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildInputAction({
    IconData? icon,
    String? assetPath,
    double? assetWidth,
    double? assetHeight,
    VoidCallback? onTap,
    bool highlight = false,
    bool isActive = false,
  }) {
    assert(icon != null || assetPath != null);

    final color = highlight
        ? Colors.white
        : (isActive
            ? AppColors.brandDeepMagenta
            : const Color(0xFFE6E6E6));

    final boxSize = assetPath != null
        ? (assetHeight ?? AppSizes.chatInputActionIcon) + AppSpacing.xs
        : AppSizes.chatInputActionIcon + AppSpacing.xs;

    return Padding(
      padding: EdgeInsets.only(left: AppSpacing.sm - AppSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: boxSize,
          height: boxSize,
          child: Center(
            child: assetPath != null
                ? SvgPicture.asset(
                    assetPath,
                    width: assetWidth,
                    height: assetHeight,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  )
                : Icon(
                    icon,
                    color: color,
                    size: AppSizes.chatInputActionIcon,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _quickEmojis.map((emoji) {
          return GestureDetector(
            onTap: () => _insertEmoji(emoji),
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          );
        }).toList(),
      ),
    );
  }
}

class _WaveformBarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const barSpacing = 4.0;
    final barCount = (size.width / barSpacing).floor();
    final mid = size.height / 2;

    for (var i = 0; i < barCount; i++) {
      final x = i * barSpacing + 1;
      final h =
          (((i * 7 + 3) % 11) / 11.0) * size.height * 0.8 + size.height * 0.15;
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
