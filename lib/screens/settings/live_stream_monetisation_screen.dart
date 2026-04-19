import 'package:flutter/material.dart';
import '../../core/theme/app_gradients.dart';

class LiveStreamMonetisationScreen extends StatefulWidget {
  const LiveStreamMonetisationScreen({super.key});

  @override
  State<LiveStreamMonetisationScreen> createState() =>
      _LiveStreamMonetisationScreenState();
}

class _LiveStreamMonetisationScreenState
    extends State<LiveStreamMonetisationScreen> {
  double _sliderValue = 7.0; // Default position ~7

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.authGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  children: [
                    const SizedBox(height: 16),
                    // Title
                    const Text(
                      'Set your Price',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Subtitle
                    Text(
                      'Choose the amount you want to charge from\nthe subscribers. you can change this price later\nin Live stream monetisation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Live video pricing section
                    const Text(
                      'Live video pricing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Set your per-minute rate for non-subscribers.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Slider with value badge
                    _buildSlider(),
                    // Scale labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (i) {
                          final val = i * 2; // 0, 2, 4, 6, 8, 10
                          return Text(
                            '$val',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: const Color(0xFFF81945),
        inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
        thumbColor: Colors.white,
        overlayColor: const Color(0xFFF81945).withValues(alpha: 0.2),
        thumbShape: _CustomThumbShape(currentValue: _sliderValue.round()),
        trackHeight: 3,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      child: Slider(
        value: _sliderValue,
        min: 0,
        max: 10,
        onChanged: (v) => setState(() => _sliderValue = v),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Live stream Monetisation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'VyooO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom thumb that shows a badge above with the current value
class _CustomThumbShape extends SliderComponentShape {
  const _CustomThumbShape({required this.currentValue});

  final int currentValue;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(20, 20);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // White thumb circle
    final thumbPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 10, thumbPaint);

    // Badge pill above thumb
    const badgeHeight = 22.0;
    const badgeWidth = 34.0;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 28),
        width: badgeWidth,
        height: badgeHeight,
      ),
      const Radius.circular(6),
    );
    final badgePaint = Paint()..color = const Color(0xFFF81945);
    canvas.drawRRect(badgeRect, badgePaint);

    // Badge text
    final tp = TextPainter(
      text: TextSpan(
        text: 'c$currentValue',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - 28 - tp.height / 2),
    );
  }
}
