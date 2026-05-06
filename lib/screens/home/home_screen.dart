import 'package:flutter/material.dart';
import '../../components/delulu_nav_bar.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../discovery/discovery_screen.dart';
import '../signals/signals_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<SignalsScreenState> _signalsKey = GlobalKey<SignalsScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Tab Content
          IndexedStack(
            index: _currentIndex,
            children: [
              const DiscoveryScreen(),
              SignalsScreen(key: _signalsKey),
              const _PingsTab(),
              const _WhispersTab(),
              const _AuraTab(),
            ],
          ),

          // Reusable Nav Bar
          DeluluNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
              if (index == 1) {
                // Refresh signals when tab is clicked
                _signalsKey.currentState?.fetchLiked();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── Placeholder Tabs ──

class _PingsTab extends StatelessWidget {
  const _PingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Pings (Notifications)',
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