import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../whisper/chat_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  List<Map<String, dynamic>> _profiles = [];
  int _currentProfileIndex = 0;
  int _currentImageIndex = 0; // for page indicator
  bool _isLoading = true;
  bool _isCardExpanded = true; // collapse/expand toggle
  bool _isInfoCardVisible = true;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchFeed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchFeed() async {
    try {
      final res = await ApiService.getDiscoveryFeed();
      final body = jsonDecode(res.body);
      if (mounted) {
        final List<dynamic> data = body['profiles'] ?? [];
        setState(() {
          _profiles = data.map((e) {
            final profile = Map<String, dynamic>.from(e);
            if (profile['photos'] != null) {
              final photos = List<Map<String, dynamic>>.from(profile['photos']);
              photos.sort((a, b) {
                final aPrivate = a['is_private'] == true ? 1 : 0;
                final bPrivate = b['is_private'] == true ? 1 : 0;
                return aPrivate.compareTo(bPrivate);
              });
              profile['photos'] = photos;
            }
            return profile;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCustomToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primaryContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _nextProfile() {
    if (_currentProfileIndex < _profiles.length - 1) {
      setState(() {
        _currentProfileIndex++;
        _currentImageIndex = 0; // reset photo index
      });
      _pageController.jumpToPage(0);
    } else {
      _showCustomToast('You\'ve seen everyone! Check back later.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryContainer),
      );
    }

    if (_profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Delulus around right now.',
              style: GoogleFonts.beVietnamPro(
                fontSize: 16,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final profile = _profiles[_currentProfileIndex];
    final photos = List<Map<String, dynamic>>.from(profile['photos'] ?? []);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -500) {
          _nextProfile();
        }
      },
      child: Stack(
        children: [
          // Layer 1: Immersive Image Swiper
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: photos.length,
              onPageChanged: (index) {
                setState(() => _currentImageIndex = index);
              },
              itemBuilder: (context, index) {
                final photo = photos[index];
                final imageUrl = photo['url'];
                final isPrivate = photo['is_private'] == true;

                Widget imageWidget;
                if (imageUrl.startsWith('data:image')) {
                  final base64String = imageUrl.split(',').last;
                  imageWidget = Image.memory(
                    base64Decode(base64String),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.surfaceContainerHigh,
                      child: const Icon(Icons.broken_image, color: AppColors.outlineVariant, size: 48),
                    ),
                  );
                } else {
                  imageWidget = CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 300),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.surfaceContainerHigh,
                      child: const Icon(
                        Icons.broken_image,
                        color: AppColors.outlineVariant,
                        size: 48,
                      ),
                    ),
                  );
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    imageWidget,
                    if (isPrivate && profile['request_status'] != 'accepted')
                      Positioned.fill(
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
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
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.85),
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

          // Layer 2: Page indicators
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
                          : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  );
                }),
              ),
            ),

          // Layer 3: Glass Info Card
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            left: 20,
            right: 20,
            bottom: _isInfoCardVisible ? 80 : -600, // slide out
            child: _buildInfoCard(profile, photos.length),
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

          // Layer 4: Swipe hint
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.expand_less,
                  size: 16,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Swipe up for next person',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    letterSpacing: 2.4,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
                  ),
                ),
                Icon(
                  Icons.expand_less,
                  size: 16,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> profile, int photoCount) {
    final interests = List<String>.from(profile['interests'] ?? []);
    final distance = profile['distance'];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
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
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 1.5),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
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
                                        shadows: const [
                                          Shadow(blurRadius: 4, color: Colors.black54)
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (profile['is_verified'] == true)
                                    const Icon(
                                      Icons.verified,
                                      color: AppColors.secondaryContainer,
                                      size: 22,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (distance != null)
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Approx. $distance miles away',
                                      style: GoogleFonts.beVietnamPro(
                                        fontSize: 14,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            setState(() {
                              _isInfoCardVisible = false;
                            });
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.05),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: const Icon(
                              Icons.expand_more_rounded,
                              color: AppColors.primary,
                              size: 26,
                            ),
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
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(999),
                                          color: Colors.white.withValues(alpha: 0.05),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                        ),
                                        child: Text(
                                          '#$tag',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.96,
                                            color: AppColors.primary,
                                          ),
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
                                    color: AppColors.onSurface.withValues(alpha: 0.9),
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
                                if (profile['is_liked'] == true) return;
                                try {
                                  final res = await ApiService.likeUser(profile['id']);
                                  if (res.statusCode == 200 && mounted) {
                                    setState(() {
                                      _profiles[_currentProfileIndex]['is_liked'] = true;
                                    });
                                    _showCustomToast('Liked!');
                                  }
                                } catch (_) {}
                              },
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.white.withValues(alpha: 0.05),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      profile['is_liked'] == true ? Icons.favorite : Icons.favorite_border,
                                      color: profile['is_liked'] == true ? AppColors.tertiary : AppColors.onSurfaceVariant,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile['is_liked'] == true ? 'Liked' : 'Like',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: profile['is_liked'] == true ? FontWeight.w700 : FontWeight.w600,
                                        color: profile['is_liked'] == true ? AppColors.tertiary : AppColors.onSurface,
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
                          flex: profile['request_status'] == 'accepted' ? 1 : 2,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                if (profile['request_status'] != null) return;
                                try {
                                  final res = await ApiService.sendConnectionRequest(profile['id']);
                                  if (res.statusCode == 200 && mounted) {
                                    setState(() {
                                      _profiles[_currentProfileIndex]['request_status'] = 'pending';
                                    });
                                    _showCustomToast('Connection request sent!');
                                  }
                                } catch (_) {}
                              },
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: profile['request_status'] == 'accepted'
                                      ? const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [AppColors.primaryContainer, AppColors.tertiaryContainer],
                                        )
                                      : profile['request_status'] == 'pending'
                                          ? null
                                          : const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [AppColors.tertiaryContainer, AppColors.primaryContainer],
                                            ),
                                  color: profile['request_status'] == 'pending'
                                      ? AppColors.outlineVariant.withValues(alpha: 0.5)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      profile['request_status'] == 'accepted'
                                          ? Icons.link
                                          : profile['request_status'] == 'pending'
                                              ? Icons.hourglass_empty
                                              : Icons.bolt,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile['request_status'] == 'accepted'
                                          ? 'Connected'
                                          : profile['request_status'] == 'pending'
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
                        if (profile['request_status'] == 'accepted') ...[
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  if (profile['channel_id'] != null) {
                                    final photosData = profile['photos'];
                                    List<Map<String, dynamic>> photosList = [];
                                    if (photosData is String) {
                                      try {
                                        photosList = List<Map<String, dynamic>>.from(jsonDecode(photosData));
                                      } catch (_) {}
                                    } else if (photosData is List) {
                                      photosList = List<Map<String, dynamic>>.from(photosData);
                                    }
                                    final avatarUrl = photosList.isNotEmpty ? photosList[0]['url'] : null;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          channelId: profile['channel_id'],
                                          peerId: profile['id'],
                                          peerName: '${profile['display_name']}, ${profile['age']}',
                                          peerImageUrl: avatarUrl,
                                          isOnline: profile['is_online'] ?? false,
                                        ),
                                      ),
                                    );
                                  } else {
                                    _showCustomToast('Chat channel not ready yet', isError: true);
                                  }
                                },
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [AppColors.primaryContainer, AppColors.tertiaryContainer],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryContainer.withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.mark_unread_chat_alt_outlined, color: Colors.white, size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Whisper',
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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