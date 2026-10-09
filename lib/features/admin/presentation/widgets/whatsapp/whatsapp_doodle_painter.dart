import 'package:flutter/material.dart';

/// Custom painter for authentic WhatsApp vector doodle chat wallpaper
class WhatsAppDoodlePainter extends CustomPainter {
  final Color color;
  const WhatsAppDoodlePainter({this.color = const Color(0x0A000000)});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.6)
      ..style = PaintingStyle.fill;

    const double stepX = 140.0;
    const double stepY = 140.0;

    for (double y = 20; y < size.height + 40; y += stepY) {
      for (double x = 20; x < size.width + 40; x += stepX) {
        final double ox = (y / stepY).floor() % 2 == 1 ? x + 70 : x;
        _drawDoodleCluster(canvas, ox, y, strokePaint, fillPaint);
      }
    }
  }

  void _drawDoodleCluster(Canvas canvas, double cx, double cy, Paint stroke, Paint fill) {
    // 1. Speech bubble
    final bubbleRect = RRect.fromRectAndRadius(Rect.fromLTWH(cx - 30, cy - 25, 22, 15), const Radius.circular(4));
    canvas.drawRRect(bubbleRect, stroke);
    final bubbleTail = Path()
      ..moveTo(cx - 30, cy - 14)
      ..lineTo(cx - 35, cy - 10)
      ..lineTo(cx - 27, cy - 10);
    canvas.drawPath(bubbleTail, stroke);

    // 2. Small Heart
    final heartPath = Path()
      ..moveTo(cx + 15, cy - 20)
      ..cubicTo(cx + 15, cy - 24, cx + 9, cy - 26, cx + 9, cy - 20)
      ..cubicTo(cx + 9, cy - 15, cx + 15, cy - 11, cx + 15, cy - 9)
      ..cubicTo(cx + 15, cy - 11, cx + 21, cy - 15, cx + 21, cy - 20)
      ..cubicTo(cx + 21, cy - 26, cx + 15, cy - 24, cx + 15, cy - 20);
    canvas.drawPath(heartPath, stroke);

    // 3. Coffee Mug
    final cupRect = RRect.fromRectAndRadius(Rect.fromLTWH(cx - 24, cy + 12, 14, 13), const Radius.circular(2));
    canvas.drawRRect(cupRect, stroke);
    canvas.drawArc(Rect.fromLTWH(cx - 10, cy + 14, 7, 7), -1.5, 3.0, false, stroke);

    // 4. Smiley Face
    canvas.drawCircle(Offset(cx + 20, cy + 16), 8, stroke);
    canvas.drawCircle(Offset(cx + 17, cy + 14), 1, fill);
    canvas.drawCircle(Offset(cx + 23, cy + 14), 1, fill);
    canvas.drawArc(Rect.fromLTWH(cx + 16, cy + 15, 8, 5), 0.2, 2.7, false, stroke);

    // 5. Star / Sparkle
    final starPath = Path()
      ..moveTo(cx - 2, cy - 5)
      ..lineTo(cx - 2, cy + 5)
      ..moveTo(cx - 7, cy)
      ..lineTo(cx + 3, cy);
    canvas.drawPath(starPath, stroke);

    // 6. Clock
    canvas.drawCircle(Offset(cx + 35, cy - 2), 7, stroke);
    final clockHands = Path()
      ..moveTo(cx + 35, cy - 6)
      ..lineTo(cx + 35, cy - 2)
      ..lineTo(cx + 38, cy - 2);
    canvas.drawPath(clockHands, stroke);

    // 7. Paper plane / Send arrow
    final plane = Path()
      ..moveTo(cx - 42, cy + 28)
      ..lineTo(cx - 30, cy + 22)
      ..lineTo(cx - 38, cy + 35)
      ..close();
    canvas.drawPath(plane, stroke);

    // 8. Music Note
    final music = Path()
      ..moveTo(cx + 42, cy + 26)
      ..lineTo(cx + 42, cy + 18)
      ..lineTo(cx + 49, cy + 16)
      ..lineTo(cx + 49, cy + 24);
    canvas.drawPath(music, stroke);
    canvas.drawCircle(Offset(cx + 40, cy + 26), 2, fill);
    canvas.drawCircle(Offset(cx + 47, cy + 24), 2, fill);
  }

  @override
  bool shouldRepaint(covariant WhatsAppDoodlePainter oldDelegate) => oldDelegate.color != color;
}
