import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class DeluluWavyLoader extends StatefulWidget {
  final double fontSize;
  const DeluluWavyLoader({super.key, this.fontSize = 24});

  @override
  State<DeluluWavyLoader> createState() => _DeluluWavyLoaderState();
}

class _DeluluWavyLoaderState extends State<DeluluWavyLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const text = 'Delulu';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(text.length, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Calculate a wave effect based on index and controller value
            final delay = index * 0.4;
            final val = (_controller.value * 2 * math.pi) - delay;
            final offset = 10.0 * math.sin(val); 

            return Transform.translate(
              offset: Offset(0, offset),
              child: Text(
                text[index],
                style: GoogleFonts.outfit(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  foreground: Paint()
                    ..shader = LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.tertiary,
                        AppColors.primary,
                      ],
                      stops: [
                        (_controller.value - 0.3).clamp(0.0, 1.0),
                        _controller.value,
                        (_controller.value + 0.3).clamp(0.0, 1.0),
                      ],
                    ).createShader(Rect.fromLTWH(0, 0, 150, 40)),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
