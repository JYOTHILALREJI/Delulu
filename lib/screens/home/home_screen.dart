import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../components/delulu_nav_bar.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Tab Content
          IndexedStack(
            index: _currentIndex,
            children: const [
              _VibesTab(),
              _SignalsTab(),
              _WhispersTab(),
              _AuraTab(),
            ],
          ),

          // Reusable Nav Bar
          DeluluNavBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
          ),
        ],
      ),
    );
  }
}

// ── Placeholder Tabs ──

class _VibesTab extends StatelessWidget {
  const _VibesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [AppColors.obsidianCenter, AppColors.obsidianEdge],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: AppColors.primaryContainer,
              shadows: [
                Shadow(blurRadius: 20, color: AppColors.primaryContainer)
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Vibes',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                fontFamily: 'BeVietnamPro',
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Discovery reel coming next...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
                fontFamily: 'BeVietnamPro',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalsTab extends StatelessWidget {
  const _SignalsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Signals (Likes)',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
          fontFamily: 'BeVietnamPro',
        ),
      ),
    );
  }
}

class _WhispersTab extends StatelessWidget {
  const _WhispersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Whispers (Chats)',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
          fontFamily: 'BeVietnamPro',
        ),
      ),
    );
  }
}

class _AuraTab extends StatelessWidget {
  const _AuraTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Aura (Profile)',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
              fontFamily: 'BeVietnamPro',
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () async {
              await ApiService.clearToken();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Logout (dev)',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.error,
                  fontFamily: 'BeVietnamPro',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}