import 'package:flutter/material.dart';

/// Painter for document capture card-shaped overlay
class CardOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // ID card dimensions: 85.6mm x 53.98mm (ratio ~1.586:1)
    final cardWidth = size.width * 0.85;
    final cardHeight = cardWidth / 1.586;
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: cardWidth,
        height: cardHeight,
      ),
      const Radius.circular(12),
    );

    // Draw dark background with cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cardRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw card border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(cardRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
