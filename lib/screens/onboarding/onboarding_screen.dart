import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class PhotoItem {
  final String path;
  bool isBlurred;

  PhotoItem(this.path, {this.isBlurred = false});
}

class OnboardingScreen extends StatefulWidget {
  final String? initialName;

  const OnboardingScreen({super.key, this.initialName});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Step 1: Basic Info
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _ageFocusNode = FocusNode();
  String _selectedGender = '';

  // Step 2: Seeking
  String _selectedSeeking = '';
  final _bioController = TextEditingController();
  final _bioFocusNode = FocusNode();

  // Step 3: Interests
  final _interestsController = TextEditingController();
  final _interestsFocusNode = FocusNode();
  final List<String> _interests = [];

  // Step 4: Photos
  final List<PhotoItem> _photoItems = [];
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _nameFetchedFromDb = false;

  final List<String> _genderOptions = ['Non-Binary', 'Woman', 'Man'];
  final List<String> _seekingOptions = ['Everyone', 'Women', 'Men'];

  // Scroll control
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 110;

  @override
  void initState() {
    super.initState();

    _nameFocusNode.addListener(() => _scrollToField(_nameFocusNode));
    _ageFocusNode.addListener(() => _scrollToField(_ageFocusNode));
    _bioFocusNode.addListener(() => _scrollToField(_bioFocusNode));
    _interestsFocusNode.addListener(() => _scrollToField(_interestsFocusNode));

    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _nameController.text = widget.initialName!;
      _nameFetchedFromDb = true;
    } else {
      _fetchDisplayName();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final renderBox = _headerKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          setState(() {
            _headerHeight = renderBox.size.height;
          });
        }
      }
    });
  }

  Future<void> _fetchDisplayName() async {
    try {
      final res = await ApiService.getMe();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final name = body['user']?['display_name'] ?? '';
        if (name.isNotEmpty && mounted) {
          setState(() {
            _nameController.text = name;
            _nameFetchedFromDb = true;
          });
        }
      }
    } catch (_) {}
  }

  void _scrollToField(FocusNode focusNode) {
    if (!focusNode.hasFocus) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final context = focusNode.context;
      if (context == null) return;

      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final position = renderBox.localToGlobal(Offset.zero);
      final fieldTop = position.dy;
      final scrollOffset = _scrollController.offset;
      final screenHeight = MediaQuery.of(context).size.height;
      final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

      if (keyboardHeight > 0) {
        final visibleHeight = screenHeight - keyboardHeight;
        final fieldBottom = fieldTop + renderBox.size.height;

        if (fieldBottom > visibleHeight - 20) {
          final targetScroll = scrollOffset + (fieldBottom - (visibleHeight - 20));
          _scrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _interestsController.dispose();
    _nameFocusNode.dispose();
    _ageFocusNode.dispose();
    _bioFocusNode.dispose();
    _interestsFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _nameController.text.trim().isNotEmpty &&
            _ageController.text.trim().isNotEmpty &&
            int.tryParse(_ageController.text) != null &&
            _selectedGender.isNotEmpty;
      case 1:
        return _selectedSeeking.isNotEmpty;
      case 2:
        return _interests.isNotEmpty;
      case 3:
        return _photoItems.length >= 3;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _addInterests(String input) {
    final tags = input
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();
    setState(() {
      for (final tag in tags) {
        if (!_interests.contains(tag) && _interests.length < 15) {
          _interests.add(tag);
        }
      }
    });
    _interestsController.clear();
  }

  void _removeInterest(String tag) {
    setState(() => _interests.remove(tag));
  }

  Future<void> _pickImage(int index) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          if (index < _photoItems.length) {
            _photoItems[index] = PhotoItem(pickedFile.path);
          } else {
            _photoItems.add(PhotoItem(pickedFile.path));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick image'),
            backgroundColor: AppColors.errorContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _toggleBlur(int index) {
    setState(() {
      _photoItems[index].isBlurred = !_photoItems[index].isBlurred;
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _photoItems.removeAt(index);
    });
  }

  Future<void> _handleSubmit() async {
    if (!_canProceed()) return;

    setState(() => _isLoading = true);

    try {
      // Convert photos to base64 for API submission
      List<String> base64Photos = [];
      for (final photo in _photoItems) {
        final bytes = await File(photo.path).readAsBytes();
        base64Photos.add(base64Encode(bytes));
      }

      final res = await ApiService.saveProfile({
        'display_name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text) ?? 0,
        'gender': _selectedGender,
        'interested_in': _selectedSeeking,
        'bio': _bioController.text.trim(),
        'interests': _interests,
        'photos': base64Photos,
        'photo_blur_status': _photoItems.map((p) => p.isBlurred).toList(),
      });

      if (res.statusCode == 200) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        final body = jsonDecode(res.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['error'] ?? 'Failed to save profile'),
            backgroundColor: AppColors.errorContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot connect to server'),
          backgroundColor: AppColors.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [AppColors.obsidianCenter, AppColors.obsidianEdge],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -120,
                right: -120,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryContainer.withValues(alpha: 0.08),
                        blurRadius: 120,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.tertiaryContainer.withValues(alpha: 0.06),
                        blurRadius: 100,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),
              _buildHeader(),
              Positioned(
                top: _headerHeight,
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRect(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 140),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      child: KeyedSubtree(
                        key: ValueKey(_currentStep),
                        child: _buildStepContent(),
                      ),
                    ),
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        key: _headerKey,
        decoration: BoxDecoration(
          color: AppColors.obsidianEdge,
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _prevStep,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Delulu',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: AppColors.primary,
                        shadows: const [
                          Shadow(
                            blurRadius: 8,
                            color: AppColors.primaryContainer,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      ),
                      child: Text(
                        '${_currentStep + 1}/$_totalSteps',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AnimatedProgressBar(
                  value: (_currentStep + 1) / _totalSteps,
                  minHeight: 3,
                  backgroundColor: AppColors.surfaceContainerHighest.withValues(alpha: 0.2),
                  valueColor: AppColors.primaryContainer,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepBasicInfo();
      case 1:
        return _buildStepSeeking();
      case 2:
        return _buildStepInterests();
      case 3:
        return _buildStepPhotos();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepBasicInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About You',
            style: GoogleFonts.beVietnamPro(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.29,
              letterSpacing: -0.28,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Let others know the basics.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 14,
              height: 1.5,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabel('Display Name'),
              if (_nameFetchedFromDb)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.cloud_done,
                    size: 14,
                    color: AppColors.secondaryFixedDim.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildFormField(
            controller: _nameController,
            hint: 'The Alchemist',
            focusNode: _nameFocusNode,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              return null;
            },
          ),
          const SizedBox(height: 28),
          _buildLabel('Age'),
          const SizedBox(height: 10),
          _buildFormField(
            controller: _ageController,
            hint: '28',
            focusNode: _ageFocusNode,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (int.tryParse(v) == null) return 'Invalid';
              final age = int.parse(v);
              if (age < 13 || age > 120) return '13-120';
              return null;
            },
          ),
          const SizedBox(height: 28),
          _buildLabel('Identity'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _genderOptions.map((option) {
              final isSelected = _selectedGender == option;
              return _buildSelectableChip(
                label: option,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedGender = option),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepSeeking() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What Are You Looking For?',
            style: GoogleFonts.beVietnamPro(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.29,
              letterSpacing: -0.28,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This helps us find better matches for you.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 14,
              height: 1.5,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          _buildLabel('Interested In'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _seekingOptions.map((option) {
              final isSelected = _selectedSeeking == option;
              return _buildSelectableChip(
                label: option,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedSeeking = option),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          _buildLabel('Bio (Optional)'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: TextField(
              controller: _bioController,
              focusNode: _bioFocusNode,
              maxLength: 200,
              maxLines: 4,
              style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                height: 1.5,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Tell others a bit about yourself...',
                hintStyle: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  color: AppColors.outlineVariant.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterStyle: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.outline.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepInterests() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Interests',
            style: GoogleFonts.beVietnamPro(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.29,
              letterSpacing: -0.28,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add at least 1 interest. These act as filters for your discovery reel.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 14,
              height: 1.5,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: TextField(
              controller: _interestsController,
              focusNode: _interestsFocusNode,
              onSubmitted: _addInterests,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Type and press Enter (e.g., Travel, Coffee)',
                hintStyle: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  color: AppColors.outlineVariant.withValues(alpha: 0.6),
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(Icons.add_circle_outline,
                      size: 20, color: AppColors.outline.withValues(alpha: 0.5)),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_interests.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_interests.length}/15 added',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.outline.withValues(alpha: 0.6),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _interests.clear()),
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interests.map((tag) {
                return _buildInterestChip(tag);
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.interests_outlined,
                    size: 48,
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No interests added yet',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 14,
                      color: AppColors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'Popular on Delulu',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.outline.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Travel', 'Coffee', 'Music', 'Art', 'Photography',
              'Hiking', 'Cooking', 'Reading', 'Gaming', 'Yoga',
              'Nightlife', 'Architecture', 'Jazz', 'Vinyl', 'Cinema',
            ].map((suggestion) {
              final isAdded = _interests.contains(suggestion.toUpperCase());
              return GestureDetector(
                onTap: () {
                  if (isAdded) {
                    _removeInterest(suggestion.toUpperCase());
                  } else if (_interests.length < 15) {
                    setState(() => _interests.add(suggestion.toUpperCase()));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAdded
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                    color: isAdded
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                  ),
                  child: Text(
                    suggestion,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isAdded
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepPhotos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Photos',
            style: GoogleFonts.beVietnamPro(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.29,
              letterSpacing: -0.28,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add at least 3 photos. Tap the lock icon to blur/unblur each photo.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 14,
              height: 1.5,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: MediaQuery.of(context).size.height - _headerHeight - 220,
            child: _buildPhotoGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Visual Identity (3-6)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.96,
                  color: AppColors.outline,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_off, size: 12, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Tap lock to blur',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return IntrinsicHeight(
                  child: Column(
                    children: [
                      // Top row: primary (big) + right column (2 small)
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _photoItems.isNotEmpty
                                  ? _buildPhotoCard(0, isPrimary: true)
                                  : _buildPhotoSlot(0, isPrimary: true),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _photoItems.length > 1
                                        ? _buildPhotoCard(1)
                                        : _buildPhotoSlot(1),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: _photoItems.length > 2
                                        ? _buildPhotoCard(2)
                                        : _buildPhotoSlot(2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Bottom row: 3 small slots
                      SizedBox(
                        height: constraints.maxHeight * 0.28,
                        child: Row(
                          children: [
                            Expanded(
                              child: _photoItems.length > 3
                                  ? _buildPhotoCard(3)
                                  : _buildPhotoSlot(3),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _photoItems.length > 4
                                  ? _buildPhotoCard(4)
                                  : _buildPhotoSlot(4),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _photoItems.length > 5
                                  ? _buildPhotoCard(5)
                                  : _buildPhotoSlot(5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.obsidianEdge.withValues(alpha: 0.0),
              AppColors.obsidianEdge,
              AppColors.obsidianEdge,
            ],
            stops: const [0.0, 0.2, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: _canProceed()
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.tertiaryContainer,
                          AppColors.primaryContainer
                        ],
                      )
                    : null,
                color: _canProceed()
                    ? null
                    : AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _canProceed()
                    ? [
                        BoxShadow(
                          color: AppColors.primaryContainer.withValues(alpha: 0.3),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _canProceed()
                      ? (_isLoading
                          ? null
                          : (_currentStep == _totalSteps - 1
                              ? _handleSubmit
                              : _nextStep))
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            _currentStep == _totalSteps - 1
                                ? 'Enter the Dream'
                                : 'Continue',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: _canProceed()
                                  ? Colors.white
                                  : AppColors.outline.withValues(alpha: 0.4),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user,
                    size: 13, color: AppColors.outline.withValues(alpha: 0.3)),
                const SizedBox(width: 6),
                Text(
                  'End-to-End Encryption Enabled',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.outline.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
          color: AppColors.outline,
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String hint,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.beVietnamPro(
        fontSize: 15,
        color: AppColors.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.beVietnamPro(
          fontSize: 15,
          color: AppColors.surfaceContainerHighest.withValues(alpha: 0.7),
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        errorStyle: GoogleFonts.beVietnamPro(fontSize: 12, color: AppColors.error),
      ),
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryContainer
                : AppColors.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1,
          ),
          color: isSelected
              ? AppColors.primaryContainer.withValues(alpha: 0.12)
              : Colors.transparent,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
              ),
            if (isSelected) const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$tag',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _removeInterest(tag),
            child: Icon(Icons.close,
                size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSlot(int index, {bool isPrimary = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickImage(index),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      color: AppColors.outlineVariant.withValues(alpha: 0.5),
                      size: isPrimary ? 32 : 24,
                    ),
                    if (isPrimary) ...[
                      const SizedBox(height: 8),
                      Text(
                        'PRIMARY',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: AppColors.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.lock_open,
                  size: 14,
                  color: AppColors.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard(int index, {bool isPrimary = false}) {
    final photo = _photoItems[index];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image (blurred or not)
            photo.isBlurred
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Image.file(
                      File(photo.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.surfaceContainerHigh,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.white54),
                          ),
                        );
                      },
                    ),
                  )
                : Image.file(
                    File(photo.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.surfaceContainerHigh,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.white54),
                        ),
                      );
                    },
                  ),
            // Overlay for blur indicator
            if (photo.isBlurred)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: Icon(Icons.blur_on, size: 32, color: Colors.white70),
                ),
              ),
            // Top right: lock toggle button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _toggleBlur(index),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    photo.isBlurred ? Icons.lock_outline : Icons.lock_open,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Top left: primary badge
            if (isPrimary)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PRIMARY',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            // Remove button
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _removePhoto(index),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color backgroundColor;
  final Color valueColor;
  final double minHeight;

  const _AnimatedProgressBar({
    required this.value,
    required this.backgroundColor,
    required this.valueColor,
    this.minHeight = 3,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(minHeight / 2),
          child: LinearProgressIndicator(
            value: animValue,
            minHeight: minHeight,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation(valueColor),
          ),
        );
      },
    );
  }
}