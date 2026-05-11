import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../../../utils/interests_data.dart';
import '../uploadedImages/vision_board.dart';
import 'blocked_profiles_screen.dart';
import '../../services/verification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:math';
import '../../components/delulu_wavy_loader.dart';
import '../premium/subscription_screen.dart';
import '../discovery/location_picker_screen.dart';


class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _bioController;
  late String _selectedGender;
  late String _selectedSeeking;
  late List<String> _interests;
  late List<String> _suggestedInterests;
  
  // Settings
  late bool _onlineEnabled;
  late bool _typingEnabled;
  late bool _lastSeenEnabled;
  late bool _readReceiptEnabled;
  late bool _liveLocationEnabled;
  late bool _e2eEnabled;
  late bool _hideLocationEnabled;
  late bool _isVerified;
  bool _isPremium = false;
  String _appVersion = '';
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p['display_name'] ?? '');
    _ageController = TextEditingController(text: (p['age'] ?? '').toString());
    _bioController = TextEditingController(text: p['bio'] ?? '');
    _selectedGender = p['gender'] ?? '';
    _selectedSeeking = p['interested_in'] ?? '';
    
    // Handle interests (could be a List or a JSON string)
    if (p['interests'] is String) {
      try {
        _interests = List<String>.from(jsonDecode(p['interests']));
      } catch (_) {
        _interests = [];
      }
    } else if (p['interests'] is List) {
      _interests = List<String>.from(p['interests']);
    } else {
      _interests = [];
    }
    
    _suggestedInterests = InterestsData.getRandomInterests(10);
    
    _onlineEnabled = p['online_status_enabled'] ?? true;
    _typingEnabled = p['typing_indicator_enabled'] ?? true;
    _lastSeenEnabled = p['last_seen_enabled'] ?? true;
    _readReceiptEnabled = p['read_receipt_enabled'] ?? true;
    _liveLocationEnabled = p['live_location_enabled'] ?? false;
    _e2eEnabled = p['e2e_encryption_enabled'] ?? false;
    _hideLocationEnabled = p['hide_location_enabled'] ?? false;
    _isVerified = p['is_verified'] ?? false;
    
    _checkPremiumStatus();
    _loadAppVersion();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final res = await ApiService.getMe();
      if (res.statusCode == 200) {
        final userData = jsonDecode(res.body);
        final isPremium = userData['is_premium'] == true;
        
        setState(() {
          _isPremium = isPremium;
          // If premium expired, reset premium-only settings locally
          if (!isPremium) {
            _onlineEnabled = true;
            _typingEnabled = true;
            _lastSeenEnabled = true;
            _readReceiptEnabled = true;
            _e2eEnabled = false;
            _hideLocationEnabled = false;
          } else {
             // Ensure local state matches DB if premium
            _e2eEnabled = userData['e2e_encryption_enabled'] ?? false;
            _hideLocationEnabled = userData['hide_location_enabled'] ?? false;
            _onlineEnabled = userData['online_status_enabled'] ?? true;
            _typingEnabled = userData['typing_indicator_enabled'] ?? true;
            _lastSeenEnabled = userData['last_seen_enabled'] ?? true;
            _readReceiptEnabled = userData['read_receipt_enabled'] ?? true;
          }
        });

        // If premium expired, sync reset to backend
        if (!isPremium && (userData['e2e_encryption_enabled'] == true || userData['hide_location_enabled'] == true)) {
           await ApiService.saveProfile({
             'e2e_encryption_enabled': false,
             'hide_location_enabled': false,
             'online_status_enabled': true,
             'typing_indicator_enabled': true,
             'last_seen_enabled': true,
             'read_receipt_enabled': true,
           });
        }
      }
    } catch (_) {}
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
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        setState(() {
          _appVersion = packageInfo.version;
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.saveProfile({
        'display_name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text) ?? 0,
        'gender': _selectedGender,
        'interested_in': _selectedSeeking,
        'bio': _bioController.text.trim(),
        'interests': _interests,
      });

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile updated successfully!', style: TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
              backgroundColor: AppColors.toastBackground,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final body = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['error'] ?? 'Update failed', style: TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
              backgroundColor: AppColors.toastBackground,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    // Premium gatekeeping check
    final premiumKeys = [
      'online_status_enabled', 
      'typing_indicator_enabled', 
      'last_seen_enabled', 
      'read_receipt_enabled',
      'e2e_encryption_enabled',
      'hide_location_enabled'
    ];
    
    if (premiumKeys.contains(key) && !_isPremium) {
      _showPremiumPrompt();
      return;
    }

    // Optimistic UI
    setState(() {
      if (key == 'online_status_enabled') _onlineEnabled = value;
      if (key == 'typing_indicator_enabled') _typingEnabled = value;
      if (key == 'last_seen_enabled') _lastSeenEnabled = value;
      if (key == 'read_receipt_enabled') _readReceiptEnabled = value;
      if (key == 'live_location_enabled') _liveLocationEnabled = value;
      if (key == 'e2e_encryption_enabled') _e2eEnabled = value;
      if (key == 'hide_location_enabled') _hideLocationEnabled = value;
      if (key == 'is_verified') _isVerified = value;
    });

    try {
      await ApiService.saveProfile({key: value});
    } catch (e) {
      // Revert if failed
      setState(() {
        if (key == 'online_status_enabled') _onlineEnabled = !value;
        if (key == 'typing_indicator_enabled') _typingEnabled = !value;
        if (key == 'last_seen_enabled') _lastSeenEnabled = !value;
        if (key == 'read_receipt_enabled') _readReceiptEnabled = !value;
        if (key == 'e2e_encryption_enabled') _e2eEnabled = !value;
        if (key == 'hide_location_enabled') _hideLocationEnabled = !value;
        if (key == 'live_location_enabled') _liveLocationEnabled = !value;
      });
    }
  }

  void _showPremiumPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.star, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 12),
            Text(
              'Rizz+ Feature',
              style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ).then((_) => _checkPremiumStatus());
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

  Future<void> _handleLocationToggle(bool value) async {
    if (value) {
      final status = await Permission.location.request();
      if (status.isGranted) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          );
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
            widget.profile['latitude'] = fuzzyLat;
            widget.profile['longitude'] = fuzzyLng;
            widget.profile['location_name'] = locName;
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

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Update Password',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: isUpdating ? null : () async {
                final current = currentPasswordController.text;
                final next = newPasswordController.text;
                if (current.isEmpty || next.isEmpty) return;

                setDialogState(() => isUpdating = true);
                try {
                  final res = await ApiService.updatePassword(
                    currentPassword: current,
                    newPassword: next,
                  );
                  if (res.statusCode == 200) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Password updated!', style: TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
                          backgroundColor: AppColors.toastBackground,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  } else {
                    final body = jsonDecode(res.body);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(body['error'] ?? 'Update failed', style: TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
                          backgroundColor: AppColors.toastBackground,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connection error')),
                    );
                  }
                } finally {
                  setDialogState(() => isUpdating = false);
                }
              },
              child: isUpdating 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('UPDATE', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showInterestsPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.obsidianEdge,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(24),
            height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Interests',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${_interests.length}/10',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _interests.length >= 10 ? AppColors.error : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Select up to 10 things you love.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: TextField(
                    onSubmitted: (value) {
                      final tag = value.trim().toUpperCase();
                      if (tag.isNotEmpty && !_interests.contains(tag) && _interests.length < 10) {
                        setState(() => _interests.add(tag));
                        setModalState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Add custom interest...',
                      hintStyle: TextStyle(color: Colors.white24),
                      prefixIcon: Icon(Icons.add, color: AppColors.primary),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModalSectionTitle('YOUR SELECTIONS'),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Wrap(
                          key: ValueKey(_interests.length),
                          spacing: 8,
                          runSpacing: 8,
                          children: _interests.map((tag) => _buildRemovableChip(tag, () {
                            setState(() => _interests.remove(tag));
                            setModalState(() {});
                          })).toList(),
                        ),
                      ),
                      if (_interests.isEmpty)
                        Text('No interests added yet.', style: TextStyle(color: Colors.white24, fontSize: 12)),
                      const SizedBox(height: 32),
                      _buildModalSectionTitle('SUGGESTIONS'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestedInterests.map((tag) {
                          final isSelected = _interests.contains(tag.toUpperCase());
                          return _buildSelectableInterestChip(tag, isSelected, () {
                            if (isSelected) {
                              setState(() => _interests.remove(tag.toUpperCase()));
                            } else if (_interests.length < 10) {
                              setState(() => _interests.add(tag.toUpperCase()));
                            }
                            setModalState(() {});
                          });
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                      _buildModalSectionTitle('ALL INTERESTS'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: InterestsData.allInterests.map((tag) {
                          final isSelected = _interests.contains(tag.toUpperCase());
                          return _buildSelectableInterestChip(tag, isSelected, () {
                            if (isSelected) {
                              setState(() => _interests.remove(tag.toUpperCase()));
                            } else if (_interests.length < 10) {
                              setState(() => _interests.add(tag.toUpperCase()));
                            }
                            setModalState(() {});
                          });
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('DONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildModalSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: AppColors.primary.withOpacity(0.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppColors.obsidianEdge,
        appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Edit Profile',
          style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: DeluluWavyLoader(fontSize: 12)),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('SAVE', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('ACCOUNT'),
              _buildReadOnlyField('Email', widget.profile['email'] ?? ''),
              _buildSettingsNavTile(
                icon: Icons.lock_outline,
                label: 'Password',
                trailingText: '••••••••',
                onTap: _showChangePasswordDialog,
              ),
              _buildTextField('Display Name', _nameController, 'Your Name'),
              _buildTextField('Age', _ageController, 'Your Age', keyboardType: TextInputType.number),
              const SizedBox(height: 24),
              
              if (widget.profile['latitude'] == null) ...[
                _buildSectionHeader('LOCATION'),
                _buildSettingsNavTile(
                  icon: Icons.location_on_outlined,
                  label: 'Add Your Location',
                  subtitle: 'Required for discovery and match-making.',
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
                    );
                    if (result == true) {
                      // Reload profile to reflect new location status
                      _checkPremiumStatus(); // This refreshes userData
                    }
                  },
                ),
                const SizedBox(height: 32),
              ],

              _buildLabel('Gender'),
              const SizedBox(height: 12),
              _buildGenderSelector(),
              const SizedBox(height: 24),
              _buildLabel('Interested In'),
              const SizedBox(height: 12),
              _buildSeekingSelector(),
              const SizedBox(height: 32),

              _buildSectionHeader('ABOUT'),
              _buildLargeTextField('Bio', _bioController, 'Tell something about yourself...'),
              const SizedBox(height: 32),

              _buildSectionHeader('INTERESTS'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_interests.length}/10 Interests',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                  ),
                  TextButton.icon(
                    onPressed: _showInterestsPicker,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _interests.map((tag) => _buildInterestChip(tag)).toList(),
              ),
              const SizedBox(height: 48),

              _buildSectionHeader('GATEKEEPING'),
              _buildToggleTile(
                icon: Icons.visibility,
                label: 'Online Status',
                value: _onlineEnabled,
                onChanged: (v) => _updateSetting('online_status_enabled', v),
                isPremium: true,
              ),
              _buildToggleTile(
                icon: Icons.keyboard,
                label: 'Typing Indicator',
                value: _typingEnabled,
                onChanged: (v) => _updateSetting('typing_indicator_enabled', v),
                isPremium: true,
              ),
              _buildToggleTile(
                icon: Icons.access_time,
                label: 'Last Seen',
                value: _lastSeenEnabled,
                onChanged: (v) => _updateSetting('last_seen_enabled', v),
                isPremium: true,
              ),
              _buildToggleTile(
                icon: Icons.done_all,
                label: 'Read Receipts',
                value: _readReceiptEnabled,
                onChanged: (v) => _updateSetting('read_receipt_enabled', v),
                isPremium: true,
              ),
              _buildToggleTile(
                icon: Icons.security,
                label: 'E2E Encryption',
                subtitle: 'Secure your conversations from end-to-end.',
                value: _e2eEnabled,
                onChanged: (v) => _updateSetting('e2e_encryption_enabled', v),
                isPremium: true,
              ),
              _buildToggleTile(
                icon: Icons.location_off,
                label: 'Hide Location',
                subtitle: 'Invisible mode for your precise location.',
                value: _hideLocationEnabled,
                onChanged: (v) => _updateSetting('hide_location_enabled', v),
                isPremium: true,
              ),
              const SizedBox(height: 32),

              _buildSectionHeader('PORTFOLIO'),
              _buildSettingsNavTile(
                icon: Icons.auto_awesome_mosaic,
                label: 'Vision Board',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VisionBoardScreen()),
                ).then((_) => setState(() {})),
              ),
              const SizedBox(height: 32),

              _buildSectionHeader('PRIVACY & SECURITY'),
              _buildSettingsNavTile(
                icon: Icons.block,
                label: 'Blocked Profiles',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BlockedProfilesScreen()),
                ),
              ),
              _buildSettingsNavTile(
                icon: Icons.verified_user,
                label: 'Verify Yourself',
                subtitle: 'Verify yourself to get more matches and connection from Delulus.',
                trailingText: _isVerified ? 'VERIFIED' : 'PENDING',
                trailingStyle: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _isVerified ? Colors.greenAccent : AppColors.primary,
                ),
                onTap: _handleVerification,
              ),
              const SizedBox(height: 48),

              Center(
                child: Column(
                  children: [
                    _buildLogoutButton(),
                    const SizedBox(height: 32),
                    Text(
                      'Delulu v$_appVersion',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.9),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.beVietnamPro(fontSize: 15, color: Colors.white.withValues(alpha: 0.8)),
          ),
          const Divider(color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLargeTextField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsNavTile({
    required IconData icon,
    required String label,
    String? subtitle,
    String? trailingText,
    TextStyle? trailingStyle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant.withValues(alpha: 0.8))) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) Text(trailingText, style: trailingStyle),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ],
      ),
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
      title: Row(
        children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600, color: showLock ? Colors.white38 : Colors.white)),
          if (showLock) ...[
            const SizedBox(width: 8),
            const Icon(Icons.star, color: Color(0xFF8B5CF6), size: 14),
          ],
        ],
      ),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant.withValues(alpha: 0.8))) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        inactiveTrackColor: showLock ? Colors.white10 : null,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      onPressed: _showLogoutDialog,
      icon: const Icon(Icons.logout, size: 18),
      label: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildGenderSelector() {
    final options = ['Non-Binary', 'Woman', 'Man'];
    return Wrap(
      spacing: 8,
      children: options.map((o) => _buildSelectableChip(o, _selectedGender == o, () => setState(() => _selectedGender = o))).toList(),
    );
  }

  Widget _buildSeekingSelector() {
    final options = ['Everyone', 'Women', 'Men'];
    return Wrap(
      spacing: 8,
      children: options.map((o) => _buildSelectableChip(o, _selectedSeeking == o, () => setState(() => _selectedSeeking = o))).toList(),
    );
  }

  Widget _buildSelectableChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.white24),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.primary : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildInterestChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(
        '#$tag',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildRemovableChip(String tag, VoidCallback onRemove) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('#$tag', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close, size: 14, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableInterestChip(String tag, bool isSelected, VoidCallback onTap) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? AppColors.primary : Colors.white10),
            ),
            child: Text(
              tag,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isSelected ? AppColors.primary : Colors.white70,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
