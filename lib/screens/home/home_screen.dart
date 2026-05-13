import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../components/delulu_nav_bar.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../discovery/discovery_screen.dart';
import '../signals/signals_screen.dart';
import '../pings/pings_screen.dart';
import '../whisper/whispers_screen.dart';
import '../../services/socket_service.dart';
import '../aura/aura_screen.dart';
import '../discovery/location_picker_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _unreadMessages = 0;
  int _pendingRequests = 0;
  int _pendingGames = 0;
  bool _showLocationPrompt = false;
  final GlobalKey<DiscoveryScreenState> _discoveryKey = GlobalKey<DiscoveryScreenState>();
  final GlobalKey<SignalsScreenState> _signalsKey = GlobalKey<SignalsScreenState>();
  final GlobalKey<PingsScreenState> _pingsKey = GlobalKey<PingsScreenState>();
  final GlobalKey<WhispersScreenState> _whispersKey = GlobalKey<WhispersScreenState>();
  final GlobalKey<AuraScreenState> _auraKey = GlobalKey<AuraScreenState>();

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _initSocket();
    _checkLocation();
  }

  Future<void> _checkLocation() async {
    try {
      final res = await ApiService.getMe();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final user = body['user'];
        if (mounted) {
          setState(() {
            _showLocationPrompt = (user['latitude'] == null || user['longitude'] == null);
          });
        }
      }
    } catch (_) {}
  }

  void _initSocket() {
    SocketService().connect();
    // Listen for events that should trigger a refresh of the global notification counts
    SocketService().messageStatusStream.listen((_) => _fetchNotifications());
    SocketService().messageStream.listen((_) => _fetchNotifications());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    try {
      final res = await ApiService.getNotifications();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _unreadMessages = body['unread_messages'] ?? 0;
            _pendingRequests = body['pending_requests'] ?? 0;
            _pendingGames = body['pending_game_invites'] ?? 0;
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error fetching notifications: $e');
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
              DiscoveryScreen(key: _discoveryKey),
              SignalsScreen(key: _signalsKey),
              PingsScreen(key: _pingsKey),
              WhispersScreen(key: _whispersKey),
              AuraScreen(key: _auraKey),
            ],
          ),

          // Location Prompt Overlay
          if (_showLocationPrompt)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 20,
              right: 20,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) => Transform.translate(
                  offset: Offset(0, (1 - value) * -100),
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Location Missing',
                              style: GoogleFonts.beVietnamPro(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Add your zone to see Delulus nearby!',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
                          );
                          if (result == true) {
                            setState(() => _showLocationPrompt = false);
                            _discoveryKey.currentState?.refreshFeed();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'ADD',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Reusable Nav Bar
          DeluluNavBar(
            currentIndex: _currentIndex,
            whisperUnreadCount: _unreadMessages + _pendingGames,
            pingsUnreadCount: _pendingRequests,
            onTap: (index) {
              setState(() => _currentIndex = index);
              _fetchNotifications(); // Refresh notifications on any tab change
              
              // Trigger explicit refresh for each screen
              if (index == 0) {
                _discoveryKey.currentState?.refreshFeed();
              } else if (index == 1) {
                _signalsKey.currentState?.fetchData();
              } else if (index == 2) {
                _pingsKey.currentState?.fetchRequests();
              } else if (index == 3) {
                _whispersKey.currentState?.fetchConnections();
              } else if (index == 4) {
                _auraKey.currentState?.loadProfile();
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