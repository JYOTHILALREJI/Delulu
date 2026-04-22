import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/brand_logo.dart';
import 'package:flutter/services.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  const AuthScreen({
    super.key,
    required this.onSignIn,
    required this.onSignUp,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late AnimationController _flipController;
  late CurvedAnimation _flipCurve;
  bool _showFront = true;

  final _siEmail = TextEditingController();
  final _siPassword = TextEditingController();
  bool _siObscure = true;
  bool _siLoading = false;

  final _suName = TextEditingController();
  final _suEmail = TextEditingController();
  final _suPassword = TextEditingController();
  final _suConfirm = TextEditingController();
  bool _suObscure = true;
  bool _suConfirmObscure = true;
  bool _suLoading = false;

  bool get _showGoogle => !kIsWeb && Platform.isAndroid;
  bool get _showApple => !kIsWeb && Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flipCurve = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    _flipCurve.dispose();
    _siEmail.dispose();
    _siPassword.dispose();
    _suName.dispose();
    _suEmail.dispose();
    _suPassword.dispose();
    _suConfirm.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipController.isAnimating) return;
    if (_showFront) {
      _flipController.forward(from: 0);
    } else {
      _flipController.reverse(from: 1);
    }
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showFront = !_showFront);
    });
  }

  void _handleSignIn() {
    FocusScope.of(context).unfocus();
    setState(() => _siLoading = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _siLoading = false);
        widget.onSignIn();
      }
    });
  }

  void _handleSignUp() {
    if (_suName.text.trim().isEmpty ||
        _suEmail.text.trim().isEmpty ||
        _suPassword.text.isEmpty ||
        _suConfirm.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }
    if (_suPassword.text != _suConfirm.text) {
      _showError('Passwords do not match');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _suLoading = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _suLoading = false);
        widget.onSignUp();
      }
    });
  }

  void _handleSocialSignUp() {
    setState(() => _suLoading = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _suLoading = false);
        widget.onSignUp();
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.rejectRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 28),
                _buildHeader(),
                const SizedBox(height: 16),
                Expanded(
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // Ambient glow behind the card
                      Positioned(
                        top: 80,
                        child: _buildAmbientGlow(),
                      ),
                      // Scrollable card on top
                      Positioned.fill(
                        top: 0,
                        bottom: 0,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(
                            left: 24,
                            right: 24,
                            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                          ),
                          child: _buildFlipCard(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AuraReveal(
      delay: const Duration(milliseconds: 100),
      duration: const Duration(milliseconds: 800),
      child: Column(
        children: [
          const BrandLogo(size: 48),
          const SizedBox(height: 14),
          Text(
            'Delulu',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [AppColors.pinkAccent, AppColors.purpleAccent],
                ).createShader(const Rect.fromLTWH(0, 0, 120, 26)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlow() {
    return AnimatedBuilder(
      animation: _flipCurve,
      builder: (context, child) {
        final t = _flipCurve.value;
        final color = Color.lerp(
          AppColors.purpleAccent.withOpacity(0.08),
          AppColors.pinkAccent.withOpacity(0.08),
          t,
        );
        return Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color!, Colors.transparent],
              stops: const [0.0, 0.7],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlipCard() {
    return AnimatedBuilder(
      animation: _flipCurve,
      builder: (context, child) {
        final t = _flipCurve.value;
        final angle = t * pi;
        final scale = 1.0 - 0.04 * sin(t * pi);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle)
            ..scale(scale),
          child: _showFront
              ? _buildSignInSide()
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _buildSignUpSide(),
                ),
        );
      },
    );
  }

  Widget _buildSignInSide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.whiteAlpha05),
        boxShadow: [
          BoxShadow(
            color: AppColors.purpleAccent.withOpacity(0.06),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Welcome Back',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter the dream again.',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 26),
          const _FieldLabel('EMAIL'),
          const SizedBox(height: 8),
          _AuthField(
            controller: _siEmail,
            hint: 'your@email.com',
            prefix: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 18),
          const _FieldLabel('PASSWORD'),
          const SizedBox(height: 8),
          _AuthField(
            controller: _siPassword,
            hint: 'Enter your password',
            prefix: Icons.lock_outline_rounded,
            obscure: _siObscure,
            suffix: _toggleIcon(_siObscure, () => setState(() => _siObscure = !_siObscure)),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.purpleAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _PrimaryButton(
            label: 'SIGN IN',
            isLoading: _siLoading,
            onTap: _siLoading ? null : _handleSignIn,
          ),
          const SizedBox(height: 22),
          const _OrDivider(),
          const SizedBox(height: 22),
          _SocialButton(
            isGoogle: _showGoogle,
            isApple: _showApple,
            onTap: _siLoading ? null : _handleSignIn,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _flip,
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                children: [
                  TextSpan(text: "Don't have an account? "),
                  TextSpan(
                    text: 'Sign Up',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.pinkAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpSide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.whiteAlpha05),
        boxShadow: [
          BoxShadow(
            color: AppColors.pinkAccent.withOpacity(0.06),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Join the Dream',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your delulu world.',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 22),
          const _FieldLabel('DISPLAY NAME'),
          const SizedBox(height: 8),
          _AuthField(
            controller: _suName,
            hint: 'How should we call you?',
            prefix: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          const _FieldLabel('EMAIL'),
          const SizedBox(height: 8),
          _AuthField(
            controller: _suEmail,
            hint: 'your@email.com',
            prefix: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          const _FieldLabel('PASSWORD'),
          const SizedBox(height: 8),
          _AuthField(
            controller: _suPassword,
            hint: 'Create a password',
            prefix: Icons.lock_outline_rounded,
            obscure: _suObscure,
            suffix: _toggleIcon(_suObscure, () => setState(() => _suObscure = !_suObscure)),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('CONFIRM PASSWORD'),
          const SizedBox(height: 8),
          _AuthField(
            controller: _suConfirm,
            hint: 'Confirm your password',
            prefix: Icons.lock_outline_rounded,
            obscure: _suConfirmObscure,
            suffix: _toggleIcon(_suConfirmObscure, () => setState(() => _suConfirmObscure = !_suConfirmObscure)),
          ),
          const SizedBox(height: 22),
          _PrimaryButton(
            label: 'CREATE ACCOUNT',
            isLoading: _suLoading,
            isPink: true,
            onTap: _suLoading ? null : _handleSignUp,
          ),
          const SizedBox(height: 22),
          const _OrDivider(),
          const SizedBox(height: 22),
          _SocialButton(
            isGoogle: _showGoogle,
            isApple: _showApple,
            onTap: _suLoading ? null : _handleSocialSignUp,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _flip,
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                children: [
                  TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Sign In',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.purpleAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleIcon(bool obscured, VoidCallback onTap) {
    return IconButton(
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: AppColors.whiteAlpha40,
        size: 20,
      ),
      onPressed: onTap,
    );
  }
}

// ─── Reusable Components ────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.whiteAlpha60,
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefix;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;

  const _AuthField({
    required this.controller,
    required this.hint,
    required this.prefix,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteAlpha05,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.whiteAlpha10),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: const TextStyle(color: AppColors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 14),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          prefixIcon: Icon(prefix, color: AppColors.whiteAlpha40, size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
          suffixIcon: suffix,
          suffixIconConstraints: const BoxConstraints(minWidth: 42),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool isPink;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    this.isPink = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isPink ? AppColors.pinkAccent : AppColors.purpleAccent;
    return Pressable(
      onTap: onTap,
      child: GlowPulse(
        glowColor: accentColor,
        maxRadius: 140,
        maxOpacity: isLoading ? 0.0 : 0.12,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient:
                isPink ? AppColors.pinkButtonGradient : AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: AppColors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.whiteAlpha10)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR CONTINUE WITH',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: AppColors.textDim,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.whiteAlpha10)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final bool isGoogle;
  final bool isApple;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.isGoogle,
    required this.isApple,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showGoogle = isGoogle || (!isGoogle && !isApple);
    final showApple = isApple || (!isGoogle && !isApple);

    if (showGoogle && showApple) {
      return Row(
        children: [
          Expanded(
            child: _SocialChip(
              icon: const _GoogleIcon(),
              label: 'Google',
              onTap: onTap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SocialChip(
              icon: const Icon(Icons.apple, color: AppColors.white, size: 20),
              label: 'Apple',
              onTap: onTap,
            ),
          ),
        ],
      );
    }

    return _SocialChip(
      icon: showGoogle
          ? const _GoogleIcon()
          : const Icon(Icons.apple, color: AppColors.white, size: 20),
      label: showGoogle ? 'Continue with Google' : 'Continue with Apple',
      onTap: onTap,
    );
  }
}

class _SocialChip extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  const _SocialChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressScale: 0.96,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.whiteAlpha05,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.whiteAlpha10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.whiteAlpha80,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 20;
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(
      Path()
        ..moveTo(10 * s, 0)
        ..lineTo(17.5 * s, 3.5 * s)
        ..lineTo(12 * s, 10 * s)
        ..lineTo(10 * s, 10 * s)
        ..close(),
      paint,
    );

    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(
      Path()
        ..moveTo(10 * s, 20 * s)
        ..lineTo(17.5 * s, 16.5 * s)
        ..lineTo(12 * s, 10 * s)
        ..lineTo(10 * s, 10 * s)
        ..close(),
      paint,
    );

    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(
      Path()
        ..moveTo(0, 10 * s)
        ..lineTo(10 * s, 10 * s)
        ..lineTo(12 * s, 10 * s)
        ..lineTo(17.5 * s, 16.5 * s)
        ..lineTo(10 * s, 20 * s)
        ..close(),
      paint,
    );

    paint.color = const Color(0xFF34A853);
    canvas.drawPath(
      Path()
        ..moveTo(0, 10 * s)
        ..lineTo(10 * s, 0)
        ..lineTo(17.5 * s, 3.5 * s)
        ..lineTo(12 * s, 10 * s)
        ..lineTo(10 * s, 10 * s)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}