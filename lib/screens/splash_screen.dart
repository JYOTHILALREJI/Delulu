import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<String> tips = [
    'Your photos stay blurred until you connect.',
    'Attention Seeker: make their phone vibrate.',
    '60% common interests, 40% random matching.',
    'No one sees your face without permission.',
  ];
  int _tipIndex = 0;
  late Timer _tipTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _controller.forward();
    _tipTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {
        _tipIndex = (_tipIndex + 1) % tips.length;
      });
    });
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // Check if profile exists
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', session.user.id)
          .maybeSingle();
      if (!mounted) return;
      if (profile != null) {
        context.go('/discovery');
      } else {
        context.go('/profile-completion');
      }
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _tipTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            colors: [Color(0xFF1E002E), Color(0xFF0C0E12)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _controller,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(48),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.favorite, size: 80),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'DELULU',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: Color(0xFFECB2FF),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Obsidian Dream',
                style: TextStyle(fontSize: 12, letterSpacing: 3),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  tips[_tipIndex],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFD4C0D7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _tipIndex % 3 ? 12 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _tipIndex % 3
                          ? const Color(0xFFECB2FF)
                          : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}