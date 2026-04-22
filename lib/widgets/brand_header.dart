import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'brand_logo.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.8),
      ),
      child: Row(
        children: [
          const BrandLogo(size: 24),
          const SizedBox(width: 12),
          Text(
            'Delulu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [AppColors.pinkAccent, AppColors.purpleAccent],
                ).createShader(const Rect.fromLTWH(0, 0, 100, 20)),
            ),
          ),
        ],
      ),
    );
  }
}
