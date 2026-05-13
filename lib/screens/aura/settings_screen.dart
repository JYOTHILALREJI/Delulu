import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../uploadedImages/vision_board.dart';
import '../../services/verification_service.dart';
import '../../services/socket_service.dart';
import 'edit_profile_screen.dart';
import 'blocked_profiles_screen.dart';
import '../premium/subscription_screen.dart';
import '../../components/delulu_wavy_loader.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const SettingsScreen({super.key, required this.profile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Map<String, dynamic> _profile;
  bool _isLoading = false;

  // Gatekeeping toggles
  late bool _onlineEnabled;
  late bool _typingEnabled;
  late bool _lastSeenEnabled;
  late bool _readReceiptEnabled;
  late bool _e2eEnabled;
  late bool _hideLocationEnabled;
  late bool _isVerified;
  bool _isPremium = false;

  // App version
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.profile);
    _onlineEnabled = _profile['online_status_enabled'] ?? true;
    _typingEnabled = _profile['typing_indicator_enabled'] ?? true;
    _lastSeenEnabled = _profile['last_seen_enabled'] ?? true;
    _readReceiptEnabled = _profile['read_receipt_enabled'] ?? true;
    _e2eEnabled = _profile['e2e_encryption_enabled'] ?? false;
    _hideLocationEnabled = _profile['hide_location_enabled'] ?? false;
    _isVerified = _profile['is_verified'] ?? false;
    _isPremium = _profile['is_premium'] ?? false;
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final res = await ApiService.getVersion();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _appVersion = body['version'] ?? '1.0.0');
      }
    } catch (_) {}
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final premiumKeys = [
      'online_status_enabled', 'typing_indicator_enabled',
      'last_seen_enabled', 'read_receipt_enabled',
      'e2e_encryption_enabled', 'hide_location_enabled',
    ];

    if (premiumKeys.contains(key) && !_isPremium) {
      _showPremiumPrompt();
      return;
    }

    setState(() {
      if (key == 'online_status_enabled') _onlineEnabled = value;
      if (key == 'typing_indicator_enabled') _typingEnabled = value;
      if (key == 'last_seen_enabled') _lastSeenEnabled = value;
      if (key == 'read_receipt_enabled') _readReceiptEnabled = value;
      if (key == 'e2e_encryption_enabled') _e2eEnabled = value;
      if (key == 'hide_location_enabled') _hideLocationEnabled = value;
      if (key == 'is_verified') _isVerified = value;
    });

    try {
      await ApiService.saveProfile({key: value});
      if (key == 'online_status_enabled' || key == 'typing_indicator_enabled') {
        SocketService().emitPresenceUpdate({key: value});
      }
    } catch (_) {
      // Revert on failure
      setState(() {
        if (key == 'online_status_enabled') _onlineEnabled = !value;
        if (key == 'typing_indicator_enabled') _typingEnabled = !value;
        if (key == 'last_seen_enabled') _lastSeenEnabled = !value;
        if (key == 'read_receipt_enabled') _readReceiptEnabled = !value;
        if (key == 'e2e_encryption_enabled') _e2eEnabled = !value;
        if (key == 'hide_location_enabled') _hideLocationEnabled = !value;
      });
    }
  }

  void _showPremiumPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          const Icon(Icons.star, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 12),
          Text('Rizz+ Feature',
              style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
        content: Text(
          'Gatekeeping settings are exclusive to Rizz+ members. Upgrade now to take full control of your privacy!',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('LATER', style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('GET RIZZ+', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

  Future<void> _handleGetAccountInfo() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getAccountData();
      if (res.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'delulu_account_data_${DateTime.now().millisecondsSinceEpoch}.json';
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Saved to: ${file.path}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.toastBackground,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      } else {
        throw Exception('Failed');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to download account data'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Leaving so soon?',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, color: Colors.white)),
        content: Text("Are you sure you want to logout? You'll be missed! 🥺",
            style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('STAY',
                style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.clearToken();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            child: Text('LOGOUT',
                style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 10),
          Text('Delete Account',
              style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, color: Colors.red)),
        ]),
        content: Text(
          'This is permanent and cannot be undone. All your data, matches, and messages will be erased forever.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL',
                style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showFinalDeleteConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('DELETE', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showFinalDeleteConfirm() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Last Chance',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, color: Colors.white)),
        content: Text(
          'Are you absolutely sure? There is NO going back. Type "DELETE" to confirm.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL',
                style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final res = await ApiService.deleteAccount();
                if (res.statusCode == 200) {
                  await ApiService.clearToken();
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to delete account. Try again.')),
                    );
                  }
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connection error. Try again.')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('YES, DELETE IT',
                style: GoogleFonts.inter(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianEdge,
      appBar: AppBar(
        backgroundColor: AppColors.obsidianEdge,
        elevation: 0,
        title: Text('Settings',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: DeluluWavyLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Edit Profile ──
                  _buildSectionLabel('PROFILE'),
                  _buildSettingsGroup([
                    _buildNavTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Edit Profile',
                      subtitle: 'Name, age, bio, gender, interests',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(profile: _profile),
                        ),
                      ).then((_) async {
                        final res = await ApiService.getMe();
                        if (res.statusCode == 200 && mounted) {
                          setState(() {
                            _profile = jsonDecode(res.body)['user'] ?? _profile;
                          });
                        }
                      }),
                    ),
                    _buildNavTile(
                      icon: Icons.auto_awesome_mosaic_outlined,
                      label: 'Vision Board',
                      subtitle: 'Manage your vision board photos',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VisionBoardScreen()),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // ── Gatekeeping ──
                  _buildSectionLabel('GATEKEEPING'),
                  _buildSettingsGroup([
                    _buildToggleTile(
                      icon: Icons.visibility_outlined,
                      label: 'Online Status',
                      value: _onlineEnabled,
                      onChanged: (v) => _updateSetting('online_status_enabled', v),
                      isPremium: true,
                    ),
                    _buildToggleTile(
                      icon: Icons.keyboard_outlined,
                      label: 'Typing Indicator',
                      value: _typingEnabled,
                      onChanged: (v) => _updateSetting('typing_indicator_enabled', v),
                      isPremium: true,
                    ),
                    _buildToggleTile(
                      icon: Icons.access_time_rounded,
                      label: 'Last Seen',
                      value: _lastSeenEnabled,
                      onChanged: (v) => _updateSetting('last_seen_enabled', v),
                      isPremium: true,
                    ),
                    _buildToggleTile(
                      icon: Icons.done_all_rounded,
                      label: 'Read Receipts',
                      value: _readReceiptEnabled,
                      onChanged: (v) => _updateSetting('read_receipt_enabled', v),
                      isPremium: true,
                    ),
                    _buildToggleTile(
                      icon: Icons.security_rounded,
                      label: 'E2E Encryption',
                      subtitle: 'Secure end-to-end conversations',
                      value: _e2eEnabled,
                      onChanged: (v) => _updateSetting('e2e_encryption_enabled', v),
                      isPremium: true,
                    ),
                    _buildToggleTile(
                      icon: Icons.location_off_outlined,
                      label: 'Hide Location',
                      subtitle: 'Invisible mode for your location',
                      value: _hideLocationEnabled,
                      onChanged: (v) => _updateSetting('hide_location_enabled', v),
                      isPremium: true,
                    ),
                    if (_profile['location_name'] != null)
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                        title: Text('Stored Location',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                        subtitle: Text(_profile['location_name'] ?? 'Unknown',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                        trailing: const Icon(Icons.lock_outline, size: 16, color: Colors.white38),
                      ),
                  ]),

                  const SizedBox(height: 28),

                  // ── Privacy & Verification ──
                  _buildSectionLabel('PRIVACY & VERIFICATION'),
                  _buildSettingsGroup([
                    _buildNavTile(
                      icon: Icons.block_rounded,
                      label: 'Blocked Profiles',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BlockedProfilesScreen()),
                      ),
                    ),
                    _buildNavTile(
                      icon: Icons.verified_user_outlined,
                      label: 'Verify Yourself',
                      subtitle: 'Get more matches with a verified badge',
                      trailing: _isVerified ? 'VERIFIED' : 'PENDING',
                      trailingStyle: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _isVerified ? Colors.greenAccent : AppColors.primary,
                      ),
                      onTap: _handleVerification,
                    ),
                  ]),

                  const SizedBox(height: 28),
                  
                  // ── Legal ──
                  _buildSectionLabel('LEGAL'),
                  _buildSettingsGroup([
                    _buildNavTile(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy Policy',
                      onTap: () => Navigator.pushNamed(context, '/privacy-policy'),
                    ),
                    _buildNavTile(
                      icon: Icons.description_outlined,
                      label: 'Terms & Conditions',
                      onTap: () => Navigator.pushNamed(context, '/terms-and-conditions'),
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // ── Account ──
                  _buildSectionLabel('ACCOUNT'),
                  _buildSettingsGroup([
                    _buildNavTile(
                      icon: Icons.download_outlined,
                      label: 'Get Account Info',
                      subtitle: 'Download your data as a JSON file',
                      onTap: _handleGetAccountInfo,
                    ),
                    _buildNavTile(
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      color: AppColors.error,
                      onTap: _showLogoutDialog,
                    ),
                    _buildNavTile(
                      icon: Icons.delete_forever_rounded,
                      label: 'Delete Account',
                      subtitle: 'Permanently remove all your data',
                      color: Colors.red,
                      onTap: _showDeleteAccountDialog,
                    ),
                  ]),

                  const SizedBox(height: 40),

                  // ── Footer ──
                  Center(
                    child: Text(
                      _appVersion.isNotEmpty ? 'Delulu v$_appVersion' : 'Delulu',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  // ── Helpers ──

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
    bool isPremium = false,
  }) {
    final bool showLock = isPremium && !_isPremium;
    return ListTile(
      leading: Icon(icon, color: showLock ? Colors.white24 : AppColors.primary),
      title: Row(children: [
        Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: showLock ? Colors.white38 : Colors.white)),
        if (showLock) ...[
          const SizedBox(width: 6),
          const Icon(Icons.star, color: Color(0xFF8B5CF6), size: 12),
        ],
      ]),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant))
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        inactiveTrackColor: showLock ? Colors.white10 : null,
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
      title: Text(label,
          style: GoogleFonts.beVietnamPro(
              fontSize: 14, fontWeight: FontWeight.w600, color: color ?? Colors.white)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant))
          : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (trailing != null) Text(trailing, style: trailingStyle),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right,
            size: 18, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4)),
      ]),
    );
  }
}
