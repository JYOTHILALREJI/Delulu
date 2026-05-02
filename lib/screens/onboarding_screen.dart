import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;
      if (googleAuth == null) return;
      final AuthResponse response =
          await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
      if (!context.mounted) return;
      if (response.user != null) {
        // Check if user already has a profile (returning user)
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('id', response.user!.id)
            .maybeSingle();
        if (!context.mounted) return;
        if (profile != null) {
          context.go('/discovery');
        } else {
          context.go('/profile-completion');
        }
      } else {
        _showError(context, 'Sign in failed. Please try again.');
      }
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111318), Color(0xFF1E002E)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const FlutterLogo(size: 80),
              const SizedBox(height: 20),
              const Text(
                'DELULU',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Color(0xFFECB2FF),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Obsidian Dream',
                style: TextStyle(fontSize: 12, letterSpacing: 2),
              ),
              const SizedBox(height: 60),
              const Text(
                'Curate Your Aura',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE2E2E8),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Privacy is the gateway to deeper connection.\nReveal yourself slowly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD4C0D7)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _signInWithGoogle(context),
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Continue with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBD00FF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  // Email/password fallback – implement if needed
                },
                child: const Text('Use email instead'),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}