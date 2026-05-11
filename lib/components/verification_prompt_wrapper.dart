import 'dart:async';
import 'dart:ui';
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
    // Check more frequently
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _checkVerification());
    Future.delayed(const Duration(seconds: 5), _checkVerification);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    if (_isPrompting) return;

    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == null ||
        currentRoute == '/' ||
        currentRoute == '/login' ||
        currentRoute == '/signup' ||
        currentRoute == '/onboarding') {
      return;
    }

    try {
      final res = await ApiService.getMe();
      if (res.statusCode == 200) {
        final userData = ApiService.getMeData(res);
        final isVerified = userData['is_verified'] == true;

        if (!isVerified) {
          _showMandatoryPrompt();
        }
      }
    } catch (e) {
      print('Verification check error: $e');
    }
  }

  void _showMandatoryPrompt() {
    if (!mounted || _isPrompting) return;
    _isPrompting = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return WillPopScope(
          onWillPop: () async => false,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 48),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'VERIFY YOUR AURA',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Authenticity is everything on Delulu.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'To keep our community safe, all members must verify their identity using our ML-powered face detection.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _isPrompting = false;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const VerificationCameraScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          'START VERIFICATION',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
