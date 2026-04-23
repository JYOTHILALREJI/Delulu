import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_header.dart';
import '../widgets/animations.dart';
import 'package:flutter/services.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  String _selectedGender = 'Woman';
  String _selectedSeeking = 'Everyone';
  final List<String> _selectedInterests = ['#Philosophy', '#Art'];
  final List<String> _suggestedInterests = [
    '#Philosophy', '#Art', '#Music', '#Travel', '#Coffee',
    '#Architecture', '#Vinyl', '#Jazz', '#Poetry', '#Film',
  ];
  final TextEditingController _customInterestController = TextEditingController();

  final List<XFile?> _images = List.generate(6, (_) => null);
  final List<bool> _isPrivate = List.generate(6, (_) => false);
  final ImagePicker _picker = ImagePicker();

  void _nextStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      widget.onComplete();
    }
  }

  void _previousStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _pickImage(int index) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _images[index] = image;
      });
    }
  }

  void _showImagePreview(int index) {
    if (_images[index] == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  Center(
                    child: Image.file(
                      File(_images[index]!.path),
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    left: 20,
                    child: IconButton(
                      icon: Icon(
                        _isPrivate[index] ? Icons.lock : Icons.lock_open,
                        color: _isPrivate[index] ? AppColors.pinkAccent : Colors.white,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPrivate[index] = !_isPrivate[index];
                        });
                        setModalState(() {});
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: SafeArea(
            child: Column(
              children: [
                const BrandHeader(),
                _buildProgressBar(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (int page) {
                      setState(() {
                        _currentStep = page;
                      });
                    },
                    children: [
                      _buildStep1(),
                      _buildStep2(),
                      _buildStep3(),
                    ],
                  ),
                ),
                _buildBottomControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(3, (index) {
          bool isCompleted = index <= _currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              height: 4,
              margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: isCompleted
                    ? const LinearGradient(colors: [AppColors.pinkAccent, AppColors.purpleAccent])
                    : null,
                color: isCompleted ? null : AppColors.whiteAlpha10,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: StaggerReveal(
        staggerDelay: const Duration(milliseconds: 70),
        itemDuration: const Duration(milliseconds: 600),
        beginOffset: const Offset(0, 0.15),
        children: [
          _buildStepTitle('The Vibe', 'Vibe One'),
          const SizedBox(height: 32),
          _buildLabel('Display Name'),
          _buildTextField(_nameController, 'How should we call you?'),
          const SizedBox(height: 24),
          _buildLabel('Age'),
          _buildTextField(_ageController, 'Your age', keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          _buildLabel('Bio'),
          _buildTextField(_bioController, 'Tell your story...', maxLines: 4),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: StaggerReveal(
        staggerDelay: const Duration(milliseconds: 60),
        itemDuration: const Duration(milliseconds: 600),
        beginOffset: const Offset(0, 0.15),
        children: [
          _buildStepTitle('Identity', 'Core Self'),
          const SizedBox(height: 32),
          _buildLabel('I am a'),
          _buildGenderChips(),
          const SizedBox(height: 24),
          _buildLabel('Seeking'),
          _buildSeekingChips(),
          const SizedBox(height: 32),
          _buildStepTitle('Interests', 'Aura Match'),
          const SizedBox(height: 20),
          _buildInterestsWrap(),
          const SizedBox(height: 20),
          _buildCustomInterestField(),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraReveal(
            delay: const Duration(milliseconds: 100),
            child: _buildStepTitle('Gallery', 'The Vision'),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _buildGalleryGrid(),
          ),
          const SizedBox(height: 12),
          AuraReveal(
            delay: const Duration(milliseconds: 900),
            beginOffset: const Offset(0, 0.1),
            child: Text(
              'Add up to 6 images to showcase your world. First image is your main profile picture.',
              style: TextStyle(color: AppColors.textDim, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTitle(String main, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sub.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.purpleAccent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          main,
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.whiteAlpha60,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteAlpha05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.whiteAlpha10),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }

  Widget _buildGenderChips() {
    final List<String> options = ['Woman', 'Man', 'Non-Binary', 'Other'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        bool isSelected = _selectedGender == option;
        return _buildChip(option, isSelected, () => setState(() => _selectedGender = option));
      }).toList(),
    );
  }

  Widget _buildSeekingChips() {
    final List<String> options = ['Women', 'Men', 'Everyone'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        bool isSelected = _selectedSeeking == option;
        return _buildChip(option, isSelected, () => setState(() => _selectedSeeking = option));
      }).toList(),
    );
  }

  Widget _buildInterestsWrap() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _suggestedInterests.map((interest) {
        bool isSelected = _selectedInterests.contains(interest);
        return _buildChip(interest, isSelected, () {
          setState(() {
            if (isSelected) {
              _selectedInterests.remove(interest);
            } else {
              _selectedInterests.add(interest);
            }
          });
        });
      }).toList(),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return Pressable(
      pressScale: 0.93,
      onTap: onTap,
      child: MorphContainer(
        isActive: isSelected,
        activeColor: AppColors.purpleAccent.withOpacity(0.2),
        inactiveColor: AppColors.whiteAlpha05,
        activeBorderColor: AppColors.purpleAccent,
        inactiveBorderColor: AppColors.whiteAlpha10,
        activeBorderRadius: BorderRadius.circular(20),
        inactiveBorderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.check, size: 14, color: AppColors.purpleAccent),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.white : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomInterestField() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(_customInterestController, 'Add custom interest...'),
        ),
        const SizedBox(width: 12),
        Pressable(
          onTap: () {
            if (_customInterestController.text.isNotEmpty) {
              String val = _customInterestController.text.trim();
              if (!val.startsWith('#')) val = '#$val';
              if (!_suggestedInterests.contains(val)) {
                setState(() {
                  _suggestedInterests.add(val);
                });
              }
              if (!_selectedInterests.contains(val)) {
                setState(() {
                  _selectedInterests.add(val);
                });
              }
              _customInterestController.clear();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      final double spacing = 12.0;
      final double smallWidth = (constraints.maxWidth - (spacing * 2)) / 3;
      final double smallHeight = smallWidth * 1.15;
      final double largeWidth = (smallWidth * 2) + spacing;
      final double largeHeight = (smallHeight * 2) + spacing;

      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: largeWidth,
                  height: largeHeight,
                  child: AuraReveal(
                    delay: const Duration(milliseconds: 200),
                    beginScale: 0.92,
                    child: _buildImageSlot(0, isLarge: true),
                  ),
                ),
                SizedBox(width: spacing),
                SizedBox(
                  width: smallWidth,
                  height: largeHeight,
                  child: Column(
                    children: [
                      SizedBox(
                        height: smallHeight,
                        child: AuraReveal(
                          delay: const Duration(milliseconds: 320),
                          beginScale: 0.92,
                          child: _buildImageSlot(1),
                        ),
                      ),
                      SizedBox(height: spacing),
                      SizedBox(
                        height: smallHeight,
                        child: AuraReveal(
                          delay: const Duration(milliseconds: 440),
                          beginScale: 0.92,
                          child: _buildImageSlot(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: smallWidth,
                  height: smallHeight,
                  child: AuraReveal(
                    delay: const Duration(milliseconds: 560),
                    beginScale: 0.92,
                    child: _buildImageSlot(3),
                  ),
                ),
                SizedBox(
                  width: smallWidth,
                  height: smallHeight,
                  child: AuraReveal(
                    delay: const Duration(milliseconds: 680),
                    beginScale: 0.92,
                    child: _buildImageSlot(4),
                  ),
                ),
                SizedBox(
                  width: smallWidth,
                  height: smallHeight,
                  child: AuraReveal(
                    delay: const Duration(milliseconds: 800),
                    beginScale: 0.92,
                    child: _buildImageSlot(5),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildImageSlot(int index, {bool isLarge = false}) {
    XFile? image = _images[index];
    bool isPrivate = _isPrivate[index];

    Widget content = Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: image == null ? AppColors.whiteAlpha05 : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            image: image != null
                ? DecorationImage(
                    image: FileImage(File(image.path)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: image == null
              ? const Center(
                  child: Icon(Icons.add, color: AppColors.whiteAlpha40, size: 28))
              : null,
        ),
        if (image == null)
          Positioned(
            top: 12,
            right: 12,
            child: Icon(Icons.lock, size: 14, color: AppColors.whiteAlpha10),
          ),
        if (image != null)
          Positioned(
            top: 8,
            right: 8,
            child: Pressable(
              pressScale: 0.85,
              onTap: () => setState(() => _isPrivate[index] = !_isPrivate[index]),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPrivate ? Icons.lock : Icons.lock_open,
                  size: 14,
                  color: isPrivate ? AppColors.pinkAccent : Colors.white,
                ),
              ),
            ),
          ),
        if (image != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: Pressable(
              pressScale: 0.85,
              onTap: () => setState(() {
                _images[index] = null;
                _isPrivate[index] = false;
              }),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.rejectRed.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );

    return Pressable(
      onTap: () => image == null ? _pickImage(index) : _showImagePreview(index),
      child: image == null
          ? CustomPaint(
              painter: _DashedBorderPainter(
                color: AppColors.whiteAlpha20,
                strokeWidth: 1.5,
                dashWidth: 6,
                dashSpace: 4,
                radius: 16,
              ),
              child: content,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: content,
            ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentStep > 0)
            Pressable(
              onTap: _previousStep,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.whiteAlpha05,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.whiteAlpha10),
                ),
                child: const Icon(Icons.arrow_back, color: AppColors.white),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: Pressable(
              onTap: _nextStep,
              child: GlowPulse(
                glowColor: AppColors.purpleAccent,
                maxRadius: 120,
                maxOpacity: 0.15,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purpleAccent.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _currentStep == 2 ? 'ENTER THE DREAM' : 'CONTINUE',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);

    final dashedPath = Path();
    for (PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double length = min(dashWidth, metric.length - distance);
        dashedPath.addPath(metric.extractPath(distance, distance + length), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}