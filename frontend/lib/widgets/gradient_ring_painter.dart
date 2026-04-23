import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GradientRingPainter extends CustomPainter {
  final double progress;
  final double ringWidth;

  GradientRingPainter({
    this.progress = 1.0,
    this.ringWidth = 14.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - ringWidth * 4) / 2;

    // Outer glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.purpleAccent.withOpacity(0.15),
          AppColors.pinkAccent.withOpacity(0.05),
          Colors.transparent,
        ],
        stops: const [0.4, 0.6, 0.8],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.6));
    canvas.drawCircle(center, radius * 1.6, glowPaint);

    // Main ring
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = 2 * pi * progress;
    const startAngle = -pi / 2;

    // Shadow ring
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.translate(0, 3),
      startAngle,
      sweepAngle,
      false,
      shadowPaint,
    );

    // Gradient ring using sweep gradient
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: const [
        AppColors.pinkAccent,
        AppColors.purpleAccent,
        AppColors.purpleDeep,
        AppColors.pinkLight,
        AppColors.pinkAccent,
      ],
      stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
      transform: const GradientRotation(-pi / 4),
    );

    final ringPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, ringPaint);

    // Highlight top-left
    final highlightAngle = startAngle + sweepAngle * 0.15;
    final highlightCenter = Offset(
      center.dx + radius * cos(highlightAngle),
      center.dy + radius * sin(highlightAngle),
    );
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(highlightCenter, ringWidth * 0.6, highlightPaint);

    // Secondary highlight
    final highlightAngle2 = startAngle + sweepAngle * 0.65;
    final highlightCenter2 = Offset(
      center.dx + radius * cos(highlightAngle2),
      center.dy + radius * sin(highlightAngle2),
    );
    final highlightPaint2 = Paint()
      ..color = AppColors.pinkLight.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(highlightCenter2, ringWidth * 0.5, highlightPaint2);

    // Inner glow
    final innerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.purpleAccent.withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.9));
    canvas.drawCircle(center, radius * 0.9, innerGlowPaint);
  }

  @override
  bool shouldRepaint(covariant GradientRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}