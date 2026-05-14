import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _revealController;
  late final Animation<double> _revealAnim;

  late final AnimationController _glowController;
  late final Animation<double> _glowRotation;
  late final Animation<double> _glowScale;

  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();
    _revealAnim = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutCubic,
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _glowRotation = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(_glowController);

    _glowScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 50),
    ]).animate(_glowController);

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _navigateNext();
  }

  bool _hasError = false;
  String _errorMessage = '';

  Future<void> _navigateNext() async {
    // Wait for initial animation
    await Future.delayed(const Duration(milliseconds: 2500));
    
    try {
      // Check backend health/connectivity first
      final healthRes = await ApiService.getVersion().timeout(const Duration(seconds: 10));
      if (healthRes.statusCode != 200) throw Exception('Backend unavailable');
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Unable to establish a secure connection with our servers.\nPlease check your internet and try again.';
        });
      }
      return;
    }

    final token = await ApiService.getToken();

    if (token != null) {
      try {
        final res = await ApiService.getMe();
        final body = await compute<String, dynamic>(jsonDecode, res.body);

        if (res.statusCode == 200 || res.statusCode == 201) {
          final isOnboarded = body['user']?['is_onboarded'] ?? false;
          final displayName = body['user']?['display_name'] ?? '';
          final isBlocked = body['user']?['is_blocked'] ?? false;
          
          await ApiService.saveUserData(isOnboarded, displayName);

          if (!mounted) return;

          if (isBlocked) {
            Navigator.of(context).pushReplacementNamed('/blocked');
            return;
          }

          if (isOnboarded) {
            Navigator.of(context).pushReplacementNamed('/home');
          } else {
            Navigator.of(context).pushReplacementNamed(
              '/onboarding',
              arguments: displayName,
            );
          }
        } else {
          await ApiService.clearToken();
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } catch (e) {
        // If we reached here, connectivity was okay initially but failed now
        // Fallback to local data or show error
        final userData = await ApiService.getUserData();
        final isOnboarded = userData['is_onboarded'] as bool;
        final displayName = userData['display_name'] as String;
        
        if (isOnboarded) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pushReplacementNamed(
            '/onboarding',
            arguments: displayName,
          );
        }
      }
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _exitApp() {
    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
  }

  @override
  void dispose() {
    _revealController.dispose();
    _glowController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 768;
    final glowSize = isTablet ? 600.0 : 400.0;
    final logoSize = isTablet ? 192.0 : 128.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [AppColors.obsidianCenter, AppColors.obsidianEdge],
          ),
        ),
        child: Stack(
          children: [
            _buildDreamyGlow(glowSize),
            _buildAmbientLeak(
              top: -size.height * 0.25,
              left: -size.width * 0.25,
              color: AppColors.primaryContainer,
              dimension: size.width * 0.75,
            ),
            _buildAmbientLeak(
              bottom: -size.height * 0.25,
              right: -size.width * 0.25,
              color: AppColors.tertiaryContainer,
              dimension: size.width * 0.75,
            ),
            if (!_hasError) ...[
              Center(
                child: AnimatedBuilder(
                  animation: _revealAnim,
                  builder: (_, child) {
                    return Opacity(
                      opacity: _revealAnim.value,
                      child: Transform.scale(
                        scale: 0.8 + 0.2 * _revealAnim.value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RepaintBoundary(child: _buildLogoContainer(logoSize)),
                      const SizedBox(height: 32),
                      Text(
                        'DELULU',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 40,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4.0,
                          color: AppColors.onPrimaryContainer,
                          shadows: const [
                            Shadow(
                              blurRadius: 16,
                              color: Colors.black54,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      RepaintBoundary(child: _buildObsidianDreamLabel()),
                      const SizedBox(height: 24),
                      Text(
                        'Curate Your Aura',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 14,
                          height: 1.43,
                          color: AppColors.onSurfaceVariant
                              .withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _dotsController,
                  builder: (_, __) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPulseDot(_dotsController.value, 0.0),
                        const SizedBox(width: 8),
                        _buildPulseDot(_dotsController.value, 0.15),
                        const SizedBox(width: 8),
                        _buildPulseDot(_dotsController.value, 0.30),
                      ],
                    );
                  },
                ),
              ),
            ] else
              _buildErrorUI(size),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorUI(Size size) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 64),
            ),
            const SizedBox(height: 32),
            Text(
              'Connection Lost',
              style: GoogleFonts.beVietnamPro(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _exitApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white24),
                ),
                elevation: 0,
              ),
              child: Text(
                'EXIT APPLICATION',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() => _hasError = false);
                _navigateNext();
              },
              child: Text(
                'TRY AGAIN',
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDreamyGlow(double size) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) {
        return Transform.rotate(
          angle: _glowRotation.value,
          child: Transform.scale(scale: _glowScale.value, child: child),
        );
      },
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.primaryContainer.withValues(alpha: 0.20),
                blurRadius: 80,
                spreadRadius: 40,
              ),
              BoxShadow(
                color:
                    AppColors.tertiaryContainer.withValues(alpha: 0.10),
                blurRadius: 60,
                spreadRadius: 20,
                offset: const Offset(30, -30),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientLeak({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required Color color,
    required double dimension,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: dimension,
        height: dimension,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 120,
              spreadRadius: 60,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoContainer(double logoSize) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: AppColors.tertiaryContainer.withValues(alpha: 0.4),
            blurRadius: 80,
            spreadRadius: 15,
          ),
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.25),
            blurRadius: 140,
            spreadRadius: 30,
          ),
          BoxShadow(
            color: AppColors.primaryFixedDim.withValues(alpha: 0.10),
            blurRadius: 200,
            spreadRadius: 50,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/delulu_logo.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildObsidianDreamLabel() {
    const lineColor = Color(0x4D514255);
    const lineWidth = 48.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: lineWidth, height: 1, color: lineColor),
        const SizedBox(width: 8),
        Text(
          'OBSIDIAN DREAM',
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 1.33,
            fontWeight: FontWeight.w600,
            letterSpacing: 3.6,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Container(width: lineWidth, height: 1, color: lineColor),
      ],
    );
  }

  Widget _buildPulseDot(double animValue, double delay) {
    final t = (animValue - delay).clamp(0.0, 1.0);
    final wave = (math.sin(t * 2 * math.pi - math.pi / 2) + 1) / 2;
    return Opacity(
      opacity: 0.4 + 0.6 * wave,
      child: Transform.scale(
        scale: 0.6 + 0.4 * wave,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}