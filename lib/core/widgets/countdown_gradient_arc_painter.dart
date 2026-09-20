import 'dart:math';

import 'package:flutter/material.dart';

// Moved verbatim out of countdown_screen.dart (1081 lines of accepted debt)
// when audit A-009 added contact-name masking to that screen: the file-size
// ratchet refuses to let it grow, and the project rule is to extract rather
// than to trim comments until the change fits.
//
// Pure painting with a single call site. Nothing about the rendered output
// changed -- same geometry, same colours, same repaint condition -- so this is
// a relocation, not a visual change.

/// Gradient arc painter for the countdown circle
class CountdownGradientArcPainter extends CustomPainter {
  final double progress;
  final Color startColor;
  final Color endColor;
  final Color bgColor;
  final double strokeWidth;

  CountdownGradientArcPainter({
    required this.progress,
    required this.startColor,
    required this.endColor,
    required this.bgColor,
    this.strokeWidth = 14,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background ring
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Gradient arc
    if (progress > 0) {
      final sweepAngle = 2 * pi * progress;
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + sweepAngle,
        colors: [startColor, endColor],
      );
      final arcPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CountdownGradientArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.startColor != startColor;
  }
}
