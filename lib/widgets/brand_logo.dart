import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SwirlPainter(),
      ),
    );
  }
}

class _SwirlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Create a swirly effect with multiple arcs
    for (int i = 0; i < 3; i++) {
      final startAngle = (i * 2 * pi / 3) + (pi / 6);
      final sweepAngle = 2 * pi / 3 * 0.8;
      
      final rect = Rect.fromCircle(center: center, radius: radius);
      
      paint.shader = SweepGradient(
        colors: [
          AppColors.pinkAccent,
          AppColors.purpleAccent,
        ],
        transform: GradientRotation(startAngle),
      ).createShader(rect);

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, startAngle, sweepAngle, false)
        ..close();

      canvas.drawPath(path, paint);
    }

    // White center hole to make it look like a ring swirl
    final holePaint = Paint()..color = AppColors.background;
    canvas.drawCircle(center, radius * 0.4, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
