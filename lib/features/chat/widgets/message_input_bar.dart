import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';

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
    this.mediaLoading = false,
    this.onTypingChanged,
    this.onVoiceNoteSend,
  });

  final void Function(String text) onSend;
  final void Function(MediaAction action)? onMediaAction;
  final bool mediaLoading;
  final void Function(bool isTyping)? onTypingChanged;
  final void Function(File file, int durationMs)? onVoiceNoteSend;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _canSend = false;
  bool _wasTyping = false;
  bool _showEmojiRow = false;

  bool _isRecording = false;
  RecorderController? _recorderController;

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
  void dispose() {
    if (_wasTyping) widget.onTypingChanged?.call(false);
    _controller.dispose();
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
      await _recorderController!.record();
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('[MessageInputBar] record error: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_recorderController == null) return;
    try {
      final path = await _recorderController!.stop();
      final duration = _recorderController!.elapsedDuration.inMilliseconds;
      _recorderController!.dispose();
      _recorderController = null;
      setState(() => _isRecording = false);
      if (path != null && path.isNotEmpty) {
        widget.onVoiceNoteSend?.call(File(path), duration);
      }
    } catch (e) {
      debugPrint('[MessageInputBar] stop record error: $e');
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0518),
        border: Border(top: BorderSide(color: Color(0x22DE106B), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRecording) _buildRecordingRow(),
            if (!_isRecording) _buildInputRow(),
            if (_showEmojiRow && !_isRecording) _buildEmojiRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _cancelRecording,
          child: const Icon(
            Icons.delete_outline,
            color: AppColors.deleteRed,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
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
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandMagenta,
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

  Widget _buildInputRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.mediaLoading ? null : _showMediaSheet,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.add_circle_outline,
              color: widget.mediaLoading
                  ? Colors.white24
                  : Colors.white.withValues(alpha: 0.6),
              size: 26,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0A2E),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x22DE106B), width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showEmojiRow = !_showEmojiRow),
                  child: Icon(
                    Icons.emoji_emotions_outlined,
                    color: _showEmojiRow
                        ? AppColors.brandMagenta
                        : Colors.white.withValues(alpha: 0.4),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (_canSend)
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              width: 36,
              height: 36,
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
          )
        else if (widget.onVoiceNoteSend != null)
          GestureDetector(
            onTap: _startRecording,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandMagenta.withValues(alpha: 0.25),
              ),
              child: const Icon(Icons.mic, color: Colors.white70, size: 20),
            ),
          )
        else
          GestureDetector(
            onTap: null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandMagenta.withValues(alpha: 0.25),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white54,
                size: 18,
              ),
            ),
          ),
      ],
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
