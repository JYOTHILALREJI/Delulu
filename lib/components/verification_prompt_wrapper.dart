import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../services/verification_service.dart';

class VerificationPromptWrapper extends StatefulWidget {
  final Widget child;
  const VerificationPromptWrapper({super.key, required this.child});

  @override
  State<VerificationPromptWrapper> createState() => _VerificationPromptWrapperState();
}

class _VerificationPromptWrapperState extends State<VerificationPromptWrapper> {
  Timer? _timer;
  bool _isPrompting = false;

  @override
  void initState() {
    super.initState();
    // Check every 5 minutes if we need to show the prompt
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _checkVerification());
    // Initial check after a short delay to allow app to load
    Future.delayed(const Duration(seconds: 10), _checkVerification);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    if (_isPrompting) return;

    // Don't show if we are on login/signup/onboarding/splash
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == null ||
        currentRoute == '/' ||
        currentRoute == '/login' ||
        currentRoute == '/signup' ||
        currentRoute == '/onboarding') {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPrompt = prefs.getInt('last_verification_prompt') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1 hour = 3600000 ms
      if (now - lastPrompt < 3600000) return;

      final res = await ApiService.getMe();
      if (res.statusCode == 200) {
        final userData = ApiService.getMeData(res);
        final isVerified = userData['is_verified'] == true;

        if (!isVerified) {
          _showPrompt();
          await prefs.setInt('last_verification_prompt', now);
        }
      }
    } catch (e) {
      print('Verification check error: $e');
    }
  }

  void _showPrompt() {
    if (!mounted || _isPrompting) return;
    _isPrompting = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Verify Your Account',
          style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Verification keeps Delulu safe and authentic. Verified accounts get 3x more connections!',
          style: GoogleFonts.beVietnamPro(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isPrompting = false;
            },
            child: Text(
              'Later',
              style: GoogleFonts.beVietnamPro(color: AppColors.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _isPrompting = false;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => VerificationCameraScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Verify Now',
              style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).then((_) => _isPrompting = false);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
