import 'dart:convert';
import 'package:flutter/material.dart';
import '../../components/delulu_nav_bar.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../discovery/discovery_screen.dart';
import '../signals/signals_screen.dart';
import '../pings/pings_screen.dart';
import '../whisper/whispers_screen.dart';
import '../../services/socket_service.dart';
import '../aura/aura_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _unreadCount = 0;
  final GlobalKey<SignalsScreenState> _signalsKey = GlobalKey<SignalsScreenState>();
  final GlobalKey<PingsScreenState> _pingsKey = GlobalKey<PingsScreenState>();
  final GlobalKey<WhispersScreenState> _whispersKey = GlobalKey<WhispersScreenState>();

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
    _initSocket();
  }

  void _initSocket() {
    SocketService().connect();
    // Listen for events that should trigger a refresh of the global unread count
    SocketService().unreadStream.listen((_) => _fetchUnreadCount());
    SocketService().messageStream.listen((_) => _fetchUnreadCount());
  }

  @override
  void dispose() {
    // We might want to keep the socket alive while the app is in foreground
    // but definitely dispose of any listeners if they were separate.
    // For now, let the singleton handle its lifecycle.
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await ApiService.getUnreadTotal();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final count = body['total_unread'] ?? 0;
        print('DEBUG: Fetched unread count: $count');
        if (mounted) {
          setState(() {
            _unreadCount = count;
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error fetching unread count: $e');
    }
  }

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
              PingsScreen(key: _pingsKey),
              WhispersScreen(key: _whispersKey),
              const AuraScreen(),
            ],
          ),

          // Reusable Nav Bar
          DeluluNavBar(
            currentIndex: _currentIndex,
            whisperUnreadCount: _unreadCount,
            onTap: (index) {
              setState(() => _currentIndex = index);
              _fetchUnreadCount(); // Refresh unread count on any tab change
              if (index == 1) {
                // Refresh signals when tab is clicked
                _signalsKey.currentState?.fetchLiked();
              } else if (index == 2) {
                // Refresh pings when tab is clicked
                _pingsKey.currentState?.fetchRequests();
              } else if (index == 3) {
                // Refresh whispers when tab is clicked
                _whispersKey.currentState?.fetchConnections();
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