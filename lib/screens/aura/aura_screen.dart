import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../uploadedImages/vision_board.dart';
import '../../services/verification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math';
import 'edit_profile_screen.dart';
import 'blocked_profiles_screen.dart';
import 'settings_screen.dart';
import '../premium/subscription_screen.dart';
import '../../components/delulu_wavy_loader.dart';

class AuraScreen extends StatefulWidget {
  const AuraScreen({super.key});

  @override
  State<AuraScreen> createState() => AuraScreenState();
}

class AuraScreenState extends State<AuraScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  
  // Settings
  bool _onlineEnabled = true;
  bool _typingEnabled = true;
  bool _lastSeenEnabled = true;
  bool _readReceiptEnabled = true;
  bool _liveLocationEnabled = false;
  bool _isVerified = false;
  String _appVersion = '';
  bool _isBioExpanded = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final res = await ApiService.getVersion();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _appVersion = body['version'] ?? '1.0.0';
        });
      } else {
        final packageInfo = await PackageInfo.fromPlatform();
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  Future<void> loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getMe();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final userData = body['user'];
        setState(() {
          _profile = userData;
          _isVerified = userData['is_verified'] ?? false;
          _onlineEnabled = userData['online_status_enabled'] ?? true;
          _typingEnabled = userData['typing_indicator_enabled'] ?? true;
          _lastSeenEnabled = userData['last_seen_enabled'] ?? true;
          _readReceiptEnabled = userData['read_receipt_enabled'] ?? true;
          _liveLocationEnabled = userData['live_location_enabled'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    if (_profile == null) return;
    
    // Optimistic UI
    setState(() {
      if (key == 'online_status_enabled') _onlineEnabled = value;
      if (key == 'typing_indicator_enabled') _typingEnabled = value;
      if (key == 'last_seen_enabled') _lastSeenEnabled = value;
      if (key == 'read_receipt_enabled') _readReceiptEnabled = value;
      if (key == 'live_location_enabled') _liveLocationEnabled = value;
      if (key == 'is_verified') _isVerified = value;
    });

    try {
      await ApiService.saveProfile({key: value});
    } catch (e) {
      // Revert if failed
      loadProfile();
    }
  }

  Future<void> _handleLocationToggle(bool value) async {
    if (value) {
      // Request permission
      final status = await Permission.location.request();
      if (status.isGranted) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          );
          // Fuzzing logic: offset by ~5-8km (0.045 to 0.072 degrees)
          final random = Random();
          final latOffset = (random.nextDouble() * 0.027 + 0.045) * (random.nextBool() ? 1 : -1);
          final lngOffset = (random.nextDouble() * 0.027 + 0.045) * (random.nextBool() ? 1 : -1);
          
          final fuzzyLat = double.parse((position.latitude + latOffset).toStringAsFixed(3));
          final fuzzyLng = double.parse((position.longitude + lngOffset).toStringAsFixed(3));
          
          String locName = 'Unknown Location';
          try {
            final placemarks = await placemarkFromCoordinates(fuzzyLat, fuzzyLng);
            if (placemarks.isNotEmpty) {
              final p = placemarks.first;
              locName = '${p.subLocality ?? p.locality ?? ''}, ${p.administrativeArea ?? ''}'.trim();
              if (locName.startsWith(',')) locName = locName.substring(1).trim();
            }
          } catch (_) {}

          await ApiService.saveProfile({
            'live_location_enabled': true,
            'latitude': fuzzyLat,
            'longitude': fuzzyLng,
            'location_name': locName,
          });
          setState(() {
            _liveLocationEnabled = true;
            _profile?['latitude'] = fuzzyLat;
            _profile?['longitude'] = fuzzyLng;
            _profile?['location_name'] = locName;
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to get location')),
            );
          }
          setState(() => _liveLocationEnabled = false);
        }
      } else {
        setState(() => _liveLocationEnabled = false);
      }
    } else {
      _updateSetting('live_location_enabled', false);
    }
  }

  Future<void> _handleVerification() async {
    if (_isVerified) return;

    final status = await Permission.camera.request();
    if (status.isGranted) {
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const VerificationCameraScreen()),
      );

      if (success == true) {
        await _updateSetting('is_verified', true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile Verified Successfully!')),
          );
        }
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Leaving so soon?',
          style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to logout? You\'ll be missed! 🥺',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'STAY',
              style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.clearToken();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            child: Text(
              'LOGOUT',
              style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.obsidianEdge,
        body: Center(child: DeluluWavyLoader()),
      );
    }

    final String displayName = _profile?['display_name'] ?? 'User';
    final int age = _profile?['age'] ?? 0;
    final String bio = _profile?['bio'] ?? 'Delulu Dreamer';
    
    // Find primary photo
    final List<dynamic> photos = _profile?['photos'] != null 
        ? (_profile!['photos'] is String ? jsonDecode(_profile!['photos']) : _profile!['photos'])
        : [];
    final primaryPhoto = photos.isNotEmpty 
        ? photos.firstWhere((p) => p['is_primary'] == true, orElse: () => photos[0])
        : null;
    final avatarUrl = primaryPhoto?['url'];

    return Scaffold(
      backgroundColor: AppColors.obsidianEdge,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: avatarUrl != null
                ? (avatarUrl.startsWith('data:image')
                    ? Image.memory(base64Decode(avatarUrl.split(',').last), fit: BoxFit.cover)
                    : CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover))
                : Container(color: AppColors.obsidianEdge),
            ),
            
            // Gradient Overlay to ensure text readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),

            // Main Content
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildAuraTitle(),
                            const Spacer(),
                              
                              // Glass Card for Profile Details
                              ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(32),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildProfileHeader(displayName, age),
                                        const SizedBox(height: 20),
                                        _buildStatsSection(
                                          connections: _profile?['connect_count'] ?? 0,
                                          likes: _profile?['likes_count'] ?? 0,
                                          auraScore: _profile?['aura_score'] ?? 0,
                                        ),
                                        const SizedBox(height: 20),
                                        _buildBioSection(bio),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildRizzPlusBanner(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuraTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Your Aura',
          style: GoogleFonts.beVietnamPro(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            if (_profile != null) {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondary) =>
                      SettingsScreen(profile: _profile!),
                  transitionsBuilder: (context, animation, secondary, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.fastLinearToSlowEaseIn,
                      )),
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 500),
                ),
              ).then((_) => loadProfile());
            }
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection({required int connections, required int likes, required int auraScore}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Connections', connections.toString(), Icons.people_outline),
          _buildStatDivider(),
          _buildStatItem('Likes', likes.toString(), Icons.favorite_border),
          _buildStatDivider(),
          _buildStatItem('Aura Score', '$auraScore%', Icons.auto_awesome),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.beVietnamPro(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildProfileHeader(String name, int age) {
    return Column(
      children: [
        Text(
          '$name, $age',
          style: GoogleFonts.beVietnamPro(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBioSection(String bio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'BIO',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            if (bio.length > 80) {
              setState(() {
                _isBioExpanded = !_isBioExpanded;
              });
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bio,
                maxLines: _isBioExpanded ? null : 2,
                overflow: _isBioExpanded ? null : TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.6,
                ),
                textAlign: TextAlign.left,
              ),
              if (!_isBioExpanded && bio.length > 80)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Read more',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRizzPlusBanner() {
    if (_profile?['is_premium'] == true) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA500).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
            if (result == true) {
              loadProfile();
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.black, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Rizz+',
                        style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Unlimited plays & see who likes you',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.black.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black),
              ],
            ),
          ),
        ),
      ),
    );
  }

}