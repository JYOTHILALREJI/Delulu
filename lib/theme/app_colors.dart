import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0D0B14);
  static const Color surface = Color(0xFF16132A);
  static const Color surfaceLight = Color(0xFF1E1A36);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color purpleDeep = Color(0xFF6D28D9);
  static const Color pinkAccent = Color(0xFFEC4899);
  static const Color pinkLight = Color(0xFFF9A8D4);
  static const Color pinkSoft = Color(0xFFFB7185);
  static const Color white = Color(0xFFFFFFFF);
  static const Color whiteAlpha80 = Color(0xCCFFFFFF);
  static const Color whiteAlpha60 = Color(0x99FFFFFF);
  static const Color whiteAlpha40 = Color(0x66FFFFFF);
  static const Color whiteAlpha20 = Color(0x33FFFFFF);
  static const Color whiteAlpha10 = Color(0x1AFFFFFF);
  static const Color whiteAlpha05 = Color(0x0DFFFFFF);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textDim = Color(0xFF6B7280);
  static const Color verifiedBlue = Color(0xFF3B82F6);
  static const Color rejectRed = Color(0xFFEF4444);
  static const Color greenGlow = Color(0xFF10B981);

  static const LinearGradient ringGradient = LinearGradient(
    begin: Alignment(-1.0, -0.5),
    end: Alignment(1.0, 0.5),
    colors: [pinkAccent, purpleAccent, purpleDeep, pinkAccent],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [purpleAccent, pinkAccent],
  );

  static const LinearGradient pinkButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [pinkSoft, pinkAccent],
  );
}