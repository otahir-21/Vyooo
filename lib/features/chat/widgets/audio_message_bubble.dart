import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../models/message_model.dart';
import 'message_reply_quote.dart';

class AudioMessageBubble extends StatefulWidget {
  const AudioMessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    required this.time,
    this.senderName,
    this.seenText,
    this.replyToSenderName,
    this.replyToPreview,
  });

  final MessageModel message;
  final bool isSent;
  final String time;
  final String? senderName;
  final String? seenText;
  final String? replyToSenderName;
  final String? replyToPreview;

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _loaded = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final dur = await _player.setUrl(widget.message.mediaUrl ?? '');
      if (!mounted) return;
      setState(() {
        _duration =
            dur ?? Duration(milliseconds: widget.message.durationMs ?? 0);
        _loaded = true;
      });
      _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });
      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
          setState(() => _isPlaying = false);
        }
        setState(() => _isPlaying = state.playing);
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Align(
      alignment: widget.isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        margin: EdgeInsets.only(
          left: widget.isSent ? 60 : 10,
          right: widget.isSent ? 10 : 60,
          top: 2,
          bottom: 2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isSent
              ? AppColors.chatOutgoingBubble
              : AppColors.chatIncomingBubble,
          borderRadius: widget.isSent
              ? AppRadius.chatOutgoingBubbleRadius
              : AppRadius.pillRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  widget.senderName!,
                  style: TextStyle(
                    color: widget.isSent
                        ? Colors.white70
                        : AppColors.brandDeepMagenta,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (widget.replyToSenderName != null && widget.replyToPreview != null)
              MessageReplyQuote(
                senderName: widget.replyToSenderName!,
                preview: widget.replyToPreview!,
                isSentBubble: widget.isSent,
              ),
            Row(
              children: [
                GestureDetector(
                  onTap: _loaded && !_error ? _toggle : null,
                  child: Icon(
                    _error
                        ? Icons.error_outline
                        : _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: widget.isSent ? Colors.white : AppColors.chatTextPrimary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 18,
                        child: CustomPaint(
                          size: const Size(double.infinity, 18),
                          painter: _AudioWaveformPainter(
                            progress: progress.clamp(0.0, 1.0),
                            activeColor:
                                widget.isSent ? Colors.white : AppColors.chatTextPrimary,
                            inactiveColor: widget.isSent
                                ? Colors.white.withValues(alpha: 0.3)
                                : AppColors.chatTextSecondary
                                    .withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isPlaying
                            ? _formatDuration(_position)
                            : _formatDuration(_duration),
                        style: TextStyle(
                          color: widget.isSent
                              ? Colors.white.withValues(alpha: 0.6)
                              : AppColors.chatTextSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  widget.time,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                  ),
                ),
                if (widget.seenText != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    widget.seenText!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioWaveformPainter extends CustomPainter {
  _AudioWaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 2.0;
    const barSpacing = 3.5;
    final barCount = (size.width / barSpacing).floor();
    final mid = size.height / 2;
    final progressX = size.width * progress;

    for (var i = 0; i < barCount; i++) {
      final x = i * barSpacing + 1;
      final h = (((i * 7 + 3) % 11) / 11.0) * size.height * 0.85 + size.height * 0.15;
      final paint = Paint()
        ..color = x <= progressX ? activeColor : inactiveColor
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, mid - h / 2),
        Offset(x, mid + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AudioWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
