import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
      final body = jsonDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        await ApiService.saveToken(body['token']);
        await ApiService.saveUserData(false, _nameController.text.trim());
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/onboarding',
          arguments: _nameController.text.trim(),
        );
      } else {
        if (!mounted) return;
        _showError(body['error'] ?? 'Signup failed');
      }
    } catch (e) {
      if (!mounted) return;
      
      final errorStr = e.toString().toLowerCase();
      final isNetworkError = errorStr.contains('socketexception') || 
                             errorStr.contains('timeoutexception') || 
                             errorStr.contains('connection failed') ||
                             errorStr.contains('host lookup');

      _showError(isNetworkError 
          ? 'Cannot connect to server. Is the backend running?' 
          : 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.toastBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [AppColors.obsidianCenter, AppColors.obsidianEdge],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  left: -100,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.tertiaryContainer
                              .withValues(alpha: 0.06),
                          blurRadius: 100,
                          spreadRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.outlineVariant
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(Icons.arrow_back,
                                size: 20, color: AppColors.onSurface),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Create Account',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.29,
                          letterSpacing: -0.28,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Begin curating your aura.',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 36),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildLabel('Display Name'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _nameController,
                              hint: 'The Alchemist',
                              icon: Icons.person_outline,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildLabel('Email'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _emailController,
                              hint: 'you@example.com',
                              icon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!v.contains('@') || !v.contains('.')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildLabel('Password'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _passwordController,
                              hint: 'Min 6 characters',
                              icon: Icons.lock_outline,
                              obscure: _obscurePassword,
                              suffix: GestureDetector(
                                onTap: () => setState(
                                  () =>
                                      _obscurePassword = !_obscurePassword,
                                ),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.outline,
                                  size: 20,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.length < 6) {
                                  return 'Min 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: Checkbox(
                                    value: true,
                                    onChanged: (_) {},
                                    activeColor: AppColors.primaryContainer,
                                    checkColor: Colors.white,
                                    side: const BorderSide(
                                        color: AppColors.outlineVariant),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text('I agree to the ',
                                          style: GoogleFonts.beVietnamPro(
                                            fontSize: 12,
                                            color: AppColors.onSurfaceVariant,
                                          )),
                                      GestureDetector(
                                        onTap: () {},
                                        child: Text('Terms of Service',
                                            style: GoogleFonts.beVietnamPro(
                                              fontSize: 12,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            )),
                                      ),
                                      Text(' & ',
                                          style: GoogleFonts.beVietnamPro(
                                            fontSize: 12,
                                            color: AppColors.onSurfaceVariant,
                                          )),
                                      GestureDetector(
                                        onTap: () {},
                                        child: Text('Privacy Policy',
                                            style: GoogleFonts.beVietnamPro(
                                              fontSize: 12,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            )),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildPrimaryButton(
                              label: _isLoading ? null : 'Create Account',
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white),
                                      ),
                                    )
                                  : null,
                              onPressed:
                                  _isLoading ? null : _handleSignup,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildDivider(),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSocialButton(
                              label: 'Google',
                              icon: 'G',
                              onTap: () =>
                                  _showError('Google login coming soon'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSocialButton(
                              label: 'Apple',
                              iconWidget: const Icon(Icons.apple,
                                  size: 20, color: Colors.white),
                              onTap: () =>
                                  _showError('Apple login coming soon'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Already have an account? ',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              )),
                          GestureDetector(
                            onTap: () => Navigator.of(context)
                                .pushReplacementNamed('/login'),
                            child: Text('Sign In',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_outlined,
                                size: 14,
                                color: AppColors.outline
                                    .withValues(alpha: 0.4)),
                            const SizedBox(width: 6),
                            Text(
                              'End-to-End Encryption Available',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color:
                                    AppColors.outline.withValues(alpha: 0.4),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
          color: AppColors.outline,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.beVietnamPro(
          fontSize: 15,
          color: AppColors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.beVietnamPro(
            fontSize: 15,
            color: AppColors.outlineVariant,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 20, color: AppColors.outline),
          ),
          suffixIcon: suffix != null
              ? Padding(padding: const EdgeInsets.all(12), child: suffix)
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          errorStyle:
              GoogleFonts.beVietnamPro(fontSize: 12, color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String? label,
    Widget? child,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.tertiaryContainer, AppColors.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: child ??
                Text(
                  label!,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
            child:
                Divider(color: AppColors.outlineVariant, thickness: 0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR CONTINUE WITH',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.4,
              color: AppColors.outline.withValues(alpha: 0.6),
            ),
          ),
        ),
        const Expanded(
            child:
                Divider(color: AppColors.outlineVariant, thickness: 0.5)),
      ],
    );
  }

  Widget _buildSocialButton({
    required String label,
    String? icon,
    Widget? iconWidget,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget ??
                  Text(icon ?? '',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      )),
              const SizedBox(width: 10),
              Text(label,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}