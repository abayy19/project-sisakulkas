import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/yolo.dart';

/// Menggambar kotak deteksi di atas foto. Koordinat dinormalisasi 0..1.
class BoxesPainter extends CustomPainter {
  final List<Detection> detections;
  final String? highlight;
  final Color Function(String label) colorOf;

  const BoxesPainter({
    required this.detections,
    required this.highlight,
    required this.colorOf,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lineWidth = math.max(2.0, size.width / 200);
    final fontSize = math.max(11.0, size.width / 36);
    for (final d in detections) {
      final dim = highlight != null && d.label != highlight;
      final color = colorOf(d.label).withAlpha(dim ? 60 : 255);
      final rect = Rect.fromLTRB(d.x1 * size.width, d.y1 * size.height,
          d.x2 * size.width, d.y2 * size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..color = color,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${d.label} ${(d.conf * 100).round()}%',
          style: TextStyle(
              color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final th = tp.height + 4;
      final tw = tp.width + 8;
      final top = rect.top - th >= 0 ? rect.top - th : rect.top;
      canvas.drawRect(Rect.fromLTWH(rect.left, top, tw, th), Paint()..color = color);
      tp.paint(canvas, Offset(rect.left + 4, top + 2));
    }
  }

  @override
  bool shouldRepaint(covariant BoxesPainter old) =>
      old.detections != detections || old.highlight != highlight;
}
