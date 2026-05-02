import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF111318);
  static const Color onBackground = Color(0xFFE2E2E8);
  static const Color primary = Color(0xFFECB2FF);
  static const Color primaryContainer = Color(0xFFBD00FF);
  static const Color secondary = Color(0xFF00EEFC);
  static const Color tertiary = Color(0xFFE30682);
  static const Color surfaceVariant = Color(0xFF333539);
  static const Color outline = Color(0xFF9D8BA0);
  static const Color error = Color(0xFFFFB4AB);
}

class AppStrings {
  static const String appName = 'Delulu';
  static const String tagline = 'Obsidian Dream';
  static const String defaultErrorMessage = 'Something went wrong. Please try again.';
}

class AppConstants {
  static const int maxPhotos = 6;
  static const int minPhotos = 3;
  static const int maxBioLength = 200;
  static const int maxNameLength = 30;
  static const int minAge = 18;
  static const int maxAge = 100;
  static const double defaultSearchRadius = 50.0; // km
}