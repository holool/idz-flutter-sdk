import 'package:flutter/material.dart';

/// Painter for selfie capture egg/oval overlay
class FaceOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Oval dimensions: ~60% width, ~40% height, centered slightly above middle
    final ovalWidth = size.width * 0.6;
    final ovalHeight = size.height * 0.4;
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: ovalWidth,
      height: ovalHeight,
    );

    // Draw dark background with oval cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw oval border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
