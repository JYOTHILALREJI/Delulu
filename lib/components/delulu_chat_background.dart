import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class DeluluChatBackground extends StatelessWidget {
  final Widget child;
  final ScrollController? scrollController;

  const DeluluChatBackground({
    super.key,
    required this.child,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return _buildStatic(context);
  }

  Widget _buildStatic(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Stack(
      children: [
        Container(color: const Color(0xFF2A2B2E)),
        // Fixed size background that doesn't jump on keyboard resize
        Positioned(
          top: 0,
          left: 0,
          width: screenSize.width,
          height: screenSize.height,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _DeluluPainter(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DeluluPainter extends CustomPainter {
  final Random _random = Random(123);

  _DeluluPainter();

  @override
  void paint(Canvas canvas, Size size) {
    
    // Delulu text hints
    for (int i = 0; i < 25; i++) {
      final fontSize = 12.0 + _random.nextDouble() * 28.0;
      final opacity = 0.03 + _random.nextDouble() * 0.07;
      final tp = TextPainter(
        text: TextSpan(
          text: 'Delulu',
          style: GoogleFonts.outfit(
            fontSize: fontSize,
            color: AppColors.primary.withOpacity(opacity),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      canvas.save();
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      canvas.translate(x, y);
      canvas.rotate(_random.nextDouble() * 6.28); // Full circle rotation
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // Heart symbols
    for (int i = 0; i < 40; i++) {
      final hSize = 10.0 + _random.nextDouble() * 25.0;
      final opacity = 0.03 + _random.nextDouble() * 0.07;
      final heartPaint = Paint()..color = AppColors.primary.withOpacity(opacity);
      
      canvas.save();
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      canvas.translate(x, y);
      canvas.rotate(_random.nextDouble() * 6.28);
      
      final path = Path();
      path.moveTo(0, hSize * 0.35);
      path.cubicTo(0, hSize * 0.1, -hSize * 0.5, hSize * 0.1, -hSize * 0.5, hSize * 0.35);
      path.cubicTo(-hSize * 0.5, hSize * 0.6, 0, hSize * 0.85, 0, hSize);
      path.cubicTo(0, hSize * 0.85, hSize * 0.5, hSize * 0.6, hSize * 0.5, hSize * 0.35);
      path.cubicTo(hSize * 0.5, hSize * 0.1, 0, hSize * 0.1, 0, hSize * 0.35);
      canvas.drawPath(path, heartPaint);
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DeluluPainter oldDelegate) => false;
}
