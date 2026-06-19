import 'dart:math' as math;

import 'package:flutter/material.dart';

class CometPainter extends CustomPainter {
  const CometPainter({
    required this.beatCount,
    required this.progress,
    required this.color,
  });

  final int beatCount;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    final pathPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, pathPaint);

    final metric = path.computeMetrics(forceClosed: beatCount >= 3).first;
    final totalLen = metric.length;
    if (totalLen <= 0) return;

    final headDist = totalLen * progress;
    final headTangent = metric.getTangentForOffset(headDist);
    if (headTangent == null) return;
    canvas.drawCircle(headTangent.position, 5, Paint()..color = color);

    const tailPoints = 10;
    const tailLength = 0.12;
    for (var i = tailPoints; i > 0; i--) {
      var raw = progress - tailLength * i / tailPoints;
      if (raw < 0) raw += 1.0;
      final dist = (raw * totalLen).clamp(0.0, totalLen);
      final t = metric.getTangentForOffset(dist);
      if (t == null) continue;
      final fraction = i / tailPoints;
      final nearness = 1.0 - fraction;
      final dotRadius = 1.0 + 4.0 * nearness;
      canvas.drawCircle(
        t.position,
        dotRadius,
        Paint()..color = color.withValues(alpha: 0.08 + 0.55 * nearness),
      );
    }
  }

  Path _buildPath(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 6;
    final path = Path();

    if (beatCount == 1) {
      path.moveTo(center.dx, center.dy - radius);
      path.lineTo(center.dx, center.dy + radius);
    } else if (beatCount == 2) {
      const m = 6.0;
      path.moveTo(m, m);
      path.lineTo(m, size.height - m);
      path.lineTo(size.width - m, size.height - m);
    } else {
      for (var i = 0; i < beatCount; i++) {
        final angle = -math.pi / 2 - (2 * math.pi * i / beatCount);
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant CometPainter oldDelegate) {
    return beatCount != oldDelegate.beatCount ||
        progress != oldDelegate.progress ||
        color != oldDelegate.color;
  }
}

class ThreeQuarterArcPainter extends CustomPainter {
  const ThreeQuarterArcPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final offset = strokeWidth / 2;
    final rect =
        Offset(offset, offset) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    canvas.drawArc(rect, math.pi / 4, 3 * math.pi / 2, false, paint);
  }

  @override
  bool shouldRepaint(covariant ThreeQuarterArcPainter oldDelegate) {
    return color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
  }
}

class BeatShapePainter extends CustomPainter {
  const BeatShapePainter({required this.beatCount, required this.color});

  final int beatCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 3;

    if (beatCount == 1) {
      canvas.drawLine(
        Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius),
        paint,
      );
    } else if (beatCount == 2) {
      const margin = 3.0;
      canvas.drawLine(
        Offset(margin, size.height - margin),
        Offset(margin, margin),
        paint,
      );
      canvas.drawLine(
        Offset(margin, size.height - margin),
        Offset(size.width - margin, size.height - margin),
        paint,
      );
    } else {
      final path = Path();
      for (var i = 0; i < beatCount; i++) {
        final angle = -math.pi / 2 - (2 * math.pi * i / beatCount);
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BeatShapePainter oldDelegate) {
    return beatCount != oldDelegate.beatCount || color != oldDelegate.color;
  }
}
