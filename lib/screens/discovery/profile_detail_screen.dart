import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class ProfileDetailScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const ProfileDetailScreen({
    super.key,
    required this.profile,
  });

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  int _currentImageIndex = 0;
  late PageController _pageController;
  bool _isCardExpanded = true;
  bool _isInfoCardVisible = true;
  late Map<String, dynamic> _profile;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _profile = Map<String, dynamic>.from(widget.profile);
    
    // Parse JSON fields if they are strings
    _profile['photos'] = _parseJson(_profile['photos']);
    _profile['interests'] = _parseJson(_profile['interests']);
    _profile['commonInterests'] = _parseJson(_profile['commonInterests']);
  }

  dynamic _parseJson(dynamic val) {
    if (val == null) return [];
    if (val is String) {
      try {
        return jsonDecode(val);
      } catch (_) {
        return [];
      }
    }
    return val;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showCustomToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        backgroundColor: AppColors.toastBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = List<Map<String, dynamic>>.from(_profile['photos'] ?? []);

    return Scaffold(
      backgroundColor: AppColors.obsidianEdge,
      body: Stack(
        children: [
          // Photo Swiper
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _currentImageIndex = i),
              itemBuilder: (context, index) {
                final photo = photos[index];
                final imageUrl = photo['url'];
                final isPrivate = photo['is_private'] == true;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl.startsWith('data:image')
                        ? Image.memory(base64Decode(imageUrl.split(',').last), fit: BoxFit.cover)
                        : CachedNetworkImage(
                            imageUrl: imageUrl, 
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.surfaceContainerHigh,
                              child: const Icon(Icons.broken_image, color: AppColors.outlineVariant, size: 48),
                            ),
                          ),
                    if (isPrivate && _profile['request_status'] != 'accepted')
                      Positioned.fill(
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                            child: Container(color: Colors.black.withOpacity(0.2)),
                          ),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.85),
                          ],
                          stops: const [0.0, 0.4, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.3),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Photo Indicators
          if (photos.length > 1)
            Positioned(
              bottom: 90,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(photos.length, (i) {
                  final isActive = i == _currentImageIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 10 : 6,
                    height: isActive ? 10 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant.withOpacity(0.4),
                    ),
                  );
                }),
              ),
            ),

          // Bottom Info Card
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            left: 20,
            right: 20,
            bottom: _isInfoCardVisible ? 80 : -600,
            child: _buildInfoCard(_profile),
          ),

          // Show button when card is hidden
          if (!_isInfoCardVisible)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _isInfoCardVisible = true),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.2),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.expand_less, color: AppColors.primary, size: 32),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> profile) {
    final interests = List<String>.from(profile['interests'] ?? []);
    final commonInterests = List<String>.from(profile['commonInterests'] ?? []);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1.5),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${profile['display_name']}, ${profile['age']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.beVietnamPro(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w600,
                                        height: 1.29,
                                        letterSpacing: -0.28,
                                        color: AppColors.onSurface,
                                        shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (profile['is_verified'] == true)
                                    const Icon(Icons.verified, color: AppColors.secondaryContainer, size: 22),
                                ],
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => setState(() => _isInfoCardVisible = false),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Icon(Icons.expand_more_rounded, color: AppColors.primary, size: 26),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: _isCardExpanded
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (interests.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: interests.map((tag) {
                                      final isCommon = commonInterests.contains(tag);
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(999),
                                          color: isCommon ? AppColors.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                          border: Border.all(
                                              color: isCommon ? AppColors.primary.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                                          boxShadow: isCommon
                                              ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isCommon) ...[
                                              const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              '#$tag',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: isCommon ? FontWeight.w700 : FontWeight.w600,
                                                letterSpacing: 0.96,
                                                color: isCommon ? AppColors.primary : AppColors.onSurfaceVariant.withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                if (interests.isNotEmpty) const SizedBox(height: 16),
                                Text(
                                  profile['bio'] ?? '',
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: AppColors.onSurface.withOpacity(0.9),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                if (_profile['is_liked'] == true) return;
                                try {
                                  final res = await ApiService.likeUser(_profile['id'].toString());
                                  if (res.statusCode == 200 && mounted) {
                                    setState(() {
                                      _profile['is_liked'] = true;
                                    });
                                    _showCustomToast('Liked!');
                                  }
                                } catch (_) {}
                              },
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.white.withOpacity(0.05),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _profile['is_liked'] == true ? Icons.favorite : Icons.favorite_border,
                                      color: _profile['is_liked'] == true ? AppColors.tertiary : AppColors.onSurfaceVariant,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _profile['is_liked'] == true ? 'Liked' : 'Like',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: _profile['is_liked'] == true ? FontWeight.w700 : FontWeight.w600,
                                        color: _profile['is_liked'] == true ? AppColors.tertiary : AppColors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: _profile['request_status'] == 'accepted' ? 1 : 2,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                if (_profile['request_status'] != null) return;
                                try {
                                  final res = await ApiService.sendConnectionRequest(_profile['id'].toString());
                                  if (res.statusCode == 200 && mounted) {
                                    setState(() {
                                      _profile['request_status'] = 'pending';
                                    });
                                    _showCustomToast('Connection request sent!');
                                  }
                                } catch (_) {}
                              },
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: _profile['request_status'] == 'accepted'
                                      ? const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [AppColors.primaryContainer, AppColors.tertiaryContainer],
                                        )
                                      : _profile['request_status'] == 'pending'
                                          ? null
                                          : const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [AppColors.tertiaryContainer, AppColors.primaryContainer],
                                            ),
                                  color: _profile['request_status'] == 'pending'
                                      ? AppColors.outlineVariant.withOpacity(0.5)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _profile['request_status'] == 'accepted'
                                          ? Icons.link
                                          : _profile['request_status'] == 'pending'
                                              ? Icons.hourglass_empty
                                              : Icons.bolt,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _profile['request_status'] == 'accepted'
                                          ? 'Connected'
                                          : _profile['request_status'] == 'pending'
                                              ? 'Pending'
                                              : 'Connect',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
