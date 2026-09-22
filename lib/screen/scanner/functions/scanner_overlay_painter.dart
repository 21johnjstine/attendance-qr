import 'package:flutter/material.dart';

// ── 🎨 Overlay painter: dims outside the box, draws corner brackets ───────────
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final Color borderColor;

  ScannerOverlayPainter({required this.scanWindow, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(16)),
      );
    final dimPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );
    canvas.drawPath(
      dimPath,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );

    // Corner brackets
    const cornerLength = 28.0;
    const strokeWidth = 5.0;
    final cornerPaint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final r = scanWindow;

    // top-left
    canvas.drawPath(
      Path()
        ..moveTo(r.left, r.top + cornerLength)
        ..lineTo(r.left, r.top)
        ..lineTo(r.left + cornerLength, r.top),
      cornerPaint,
    );

    // top-right
    canvas.drawPath(
      Path()
        ..moveTo(r.right - cornerLength, r.top)
        ..lineTo(r.right, r.top)
        ..lineTo(r.right, r.top + cornerLength),
      cornerPaint,
    );

    // bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(r.left, r.bottom - cornerLength)
        ..lineTo(r.left, r.bottom)
        ..lineTo(r.left + cornerLength, r.bottom),
      cornerPaint,
    );

    // bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(r.right - cornerLength, r.bottom)
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.right, r.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.borderColor != borderColor;
  }
}
