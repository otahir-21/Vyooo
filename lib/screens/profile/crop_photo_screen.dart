import 'dart:io';

import 'package:flutter/material.dart';

/// Circular crop preview for profile picture. Shows image with pan/zoom,
/// darkened overlay with circular cutout, and 3x3 grid. Save returns [imagePath].
class CropPhotoScreen extends StatefulWidget {
  const CropPhotoScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<CropPhotoScreen> createState() => _CropPhotoScreenState();
}

class _CropPhotoScreenState extends State<CropPhotoScreen> {
  final TransformationController _transform = TransformationController();
  static const double _cropRadius = 160;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height / 2);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
        ),
        title: const Text(
          'Crop photo',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(widget.imagePath),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            transformationController: _transform,
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white54, size: 80),
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              size: size,
              painter: _CropOverlayPainter(center: center, radius: _cropRadius),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              size: const Size(_cropRadius * 2, _cropRadius * 2),
              painter: _GridPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark overlay with circular cutout.
class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    fill.fillType = PathFillType.evenOdd;
    canvas.drawPath(
      fill,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    // Optional: thin circle stroke
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.radius != radius;
}

/// 3x3 grid inside the crop circle.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 3;
    final h = size.height / 3;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(w * i, 0), Offset(w * i, size.height), paint);
      canvas.drawLine(Offset(0, h * i), Offset(size.width, h * i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
