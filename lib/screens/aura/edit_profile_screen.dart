import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../../../utils/interests_data.dart';

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Connection error', style: TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.toastBackground,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
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
              _buildNavTile(
                label: 'Password',
                trailing: '••••••••',
                onTap: _showChangePasswordDialog,
              ),
              const SizedBox(height: 32),
              
              _buildSectionHeader('BASICS'),
              _buildTextField('Display Name', _nameController, 'Your Name'),
              _buildTextField('Age', _ageController, 'Your Age', keyboardType: TextInputType.number),
              const SizedBox(height: 24),
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
          fontSize: 11,
          fontWeight: FontWeight.w800,
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
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: AppColors.onSurfaceVariant.withOpacity(0.6),
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
            style: GoogleFonts.beVietnamPro(fontSize: 15, color: Colors.white54),
          ),
          const Divider(color: Colors.white12),
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
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
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

  Widget _buildNavTile({required String label, required String trailing, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: _buildLabel(label),
      subtitle: Text(trailing, style: const TextStyle(color: Colors.white54)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
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
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.white12),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : Colors.white54,
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
