import 'dart:convert';
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
    final primaryPhoto = photos.firstWhere((p) => p['is_primary'] == true, orElse: () => photos.isNotEmpty ? photos[0] : null);
    final avatarUrl = primaryPhoto?['url'];

    return Scaffold(
      backgroundColor: AppColors.obsidianEdge,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 100),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Aura',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      letterSpacing: -1,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_profile != null) {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                EditProfileScreen(profile: _profile!),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              const begin = Offset(0.0, 1.0);
                              const end = Offset.zero;
                              const curve = Curves.easeOutCubic;

                              var trait = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                              var offsetAnimation = animation.drive(trait);

                              return SlideTransition(
                                position: offsetAnimation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            transitionDuration: const Duration(milliseconds: 500),
                          ),
                        ).then((updated) {
                          if (updated == true) loadProfile();
                        });
                      }
                    },
                    icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 28),
                    tooltip: 'Edit Profile',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildProfileHeader(avatarUrl, displayName, age, bio),
            const SizedBox(height: 32),
            
            _buildSettingsGroup('Gatekeeping', [
              _buildToggleTile(
                icon: Icons.visibility,
                label: 'Online Status',
                value: _onlineEnabled,
                onChanged: (v) => _updateSetting('online_status_enabled', v),
              ),
              _buildToggleTile(
                icon: Icons.keyboard,
                label: 'Typing Indicator',
                value: _typingEnabled,
                onChanged: (v) => _updateSetting('typing_indicator_enabled', v),
              ),
              _buildToggleTile(
                icon: Icons.access_time,
                label: 'Last Seen',
                value: _lastSeenEnabled,
                onChanged: (v) => _updateSetting('last_seen_enabled', v),
              ),
              _buildToggleTile(
                icon: Icons.done_all,
                label: 'Read Receipts',
                value: _readReceiptEnabled,
                onChanged: (v) => _updateSetting('read_receipt_enabled', v),
              ),
              _buildToggleTile(
                icon: Icons.near_me,
                label: 'Share Location',
                subtitle: 'Share your location to meet a real Delulu!',
                value: _liveLocationEnabled,
                onChanged: _handleLocationToggle,
              ),
              if (_liveLocationEnabled && _profile?['latitude'] != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location, size: 14, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Visible Location: ${_profile?['location_name'] ?? 'Finding...'}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_profile?['latitude']}, ${_profile?['longitude']}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: AppColors.primary.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                          onPressed: () => _handleLocationToggle(true),
                          tooltip: 'Update Location',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
            ]),

            const SizedBox(height: 24),
            _buildSettingsGroup('Portfolio', [
              _buildNavTile(
                icon: Icons.auto_awesome_mosaic,
                label: 'Vision Board',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VisionBoardScreen()),
                ).then((_) => loadProfile()),
              ),
            ]),

            const SizedBox(height: 24),
            _buildSettingsGroup('Privacy & Security', [
              _buildNavTile(
                icon: Icons.block,
                label: 'Blocked Profiles',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BlockedProfilesScreen()),
                ),
              ),
              _buildNavTile(
                icon: Icons.verified_user,
                label: 'Verify Yourself',
                subtitle: 'Verify yourself to get more matches and connection from Delulus.',
                trailing: _isVerified ? 'VERIFIED' : 'PENDING',
                trailingStyle: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _isVerified ? Colors.greenAccent : AppColors.primary,
                ),
                onTap: _handleVerification,
              ),
            ]),

            const SizedBox(height: 32),
            _buildNavTile(
              icon: Icons.logout,
              label: 'Logout',
              color: AppColors.error,
              onTap: _showLogoutDialog,
            ),
            const SizedBox(height: 40),
            Text(
              'Delulu v$_appVersion',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.onSurfaceVariant.withOpacity(0.5),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String? url, String name, int age, String bio) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: url != null
                  ? (url.startsWith('data:image')
                      ? Image.memory(base64Decode(url.split(',').last), fit: BoxFit.cover)
                      : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover))
                  : Container(
                      color: AppColors.surfaceContainerHigh,
                      child: const Icon(Icons.person, color: AppColors.outlineVariant, size: 60),
                    ),
              ),
            ),
            if (_isVerified)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.verified, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '$name, $age',
          style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          bio,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.primary),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String label,
    String? subtitle,
    String? trailing,
    TextStyle? trailingStyle,
    Color? color,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? AppColors.primary),
      title: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w500, color: color)),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) Text(trailing, style: trailingStyle),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 20, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}