import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../whisper/chat_screen.dart';
import '../aura/public_aura_screen.dart';
import 'discovery_filter_drawer.dart';
import '../../components/delulu_wavy_loader.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => DiscoveryScreenState();
}

class DiscoveryScreenState extends State<DiscoveryScreen> {
  List<Map<String, dynamic>> _profiles = [];
  int _currentProfileIndex = 0;
  int _currentImageIndex = 0; // for page indicator
  bool _isLoading = true;
  bool _isCardExpanded = true; // collapse/expand toggle
  bool _isInfoCardVisible = true;

  // Filter states
  double _minAge = 18;
  double _maxAge = 100;
  double _distanceMiles = 100; // Default max

  bool _isFetchingMore = false;
  bool _hasMore = true;
  final int _batchSize = 10;

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

  Future<void> refreshFeed() async {
    setState(() {
      _profiles = [];
      _currentProfileIndex = 0;
      _hasMore = true;
    });
    await _fetchFeed(offset: 0);
  }

  Future<void> _fetchFeed({int offset = 0}) async {
    if (offset == 0) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isFetchingMore = true);
    }

    try {
      final res = await ApiService.getDiscoveryFeed(
        ageMin: _minAge.round(),
        ageMax: _maxAge.round(),
        distanceMiles: _distanceMiles < 100 ? _distanceMiles : null,
        limit: _batchSize,
        offset: offset,
      );
      final body = jsonDecode(res.body);
      if (mounted) {
        final List<dynamic> data = body['profiles'] ?? [];
        setState(() {
          final newProfiles = data.map((e) {
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

          if (offset == 0) {
            _profiles = newProfiles;
          } else {
            _profiles.addAll(newProfiles);
          }

          _hasMore = newProfiles.length == _batchSize;
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  void _loadMoreProfiles() {
    if (!_isFetchingMore && _hasMore) {
      _fetchFeed(offset: _profiles.length);
    } else if (!_hasMore) {
      bool filtersApplied = _minAge != 18 || _maxAge != 100 || _distanceMiles < 100;
      if (filtersApplied) {
        _showCustomToast('No more profiles found matching your filters.');
      } else {
        _showCustomToast('No more Delulus found at the moment, please try later.');
      }
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
              color: AppColors.onPrimary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.toastBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _nextProfile() {
    if (_currentProfileIndex < _profiles.length - 1) {
      final nextProfile = _profiles[_currentProfileIndex + 1];
      final photos = List<Map<String, dynamic>>.from(nextProfile['photos'] ?? []);
      int primaryIndex = photos.indexWhere((p) => p['is_primary'] == true);
      if (primaryIndex == -1) primaryIndex = 0;

      setState(() {
        _currentProfileIndex++;
        _currentImageIndex = primaryIndex;
      });
      _pageController.jumpToPage(primaryIndex);
      
      // Infinite scroll trigger: load more when 3 profiles from the end
      if (_currentProfileIndex >= _profiles.length - 3) {
        _loadMoreProfiles();
      }
    } else {
      _loadMoreProfiles(); // Try loading more if we reached the absolute end
    }
  }

  void _prevProfile() {
    if (_currentProfileIndex > 0) {
      final prevProfile = _profiles[_currentProfileIndex - 1];
      final photos = List<Map<String, dynamic>>.from(prevProfile['photos'] ?? []);
      int primaryIndex = photos.indexWhere((p) => p['is_primary'] == true);
      if (primaryIndex == -1) primaryIndex = 0;

      setState(() {
        _currentProfileIndex--;
        _currentImageIndex = primaryIndex;
      });
      _pageController.jumpToPage(primaryIndex);
    } else {
      _showCustomToast('Refreshing your feed...', isError: false);
      _fetchFeed();
    }
  }

  void _showFilterDrawer() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Filter',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => DiscoveryFilterDrawer(
        currentMinAge: _minAge,
        currentMaxAge: _maxAge,
        currentDistance: _distanceMiles,
        onApply: (min, max, dist) {
          setState(() {
            _minAge = min;
            _maxAge = max;
            _distanceMiles = dist;
            _currentProfileIndex = 0;
          });
          _fetchFeed();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: DeluluWavyLoader(),
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
              (_minAge != 18 || _maxAge != 100 || _distanceMiles < 100)
                  ? 'No profiles found matching your filters.'
                  : 'No Delulus around right now.',
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
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -500) {
            _nextProfile(); // Swipe Up
          } else if (details.primaryVelocity! > 500) {
            _prevProfile(); // Swipe Down
          }
        }
      },
      child: Stack(
        children: [
          // Layer 1: Immersive Image Swiper

          if (_isFetchingMore)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const DeluluWavyLoader(fontSize: 14),
                ),
              ),
            ),
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
                    placeholder: (context, url) => const Center(child: DeluluWavyLoader(fontSize: 16)),
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
            left: 12,
            right: 12,
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
                  'Swipe up/down to navigate',
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

          // Layer 5: Filter Button (Top Left)
          Positioned(
            top: 60,
            left: 20,
            child: GestureDetector(
              onTap: _showFilterDrawer,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.3),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '${profile['display_name']}, ${profile['age']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                    letterSpacing: -0.2,
                                    color: AppColors.onSurface,
                                    shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                                  ),
                                ),
                              ),
                              if (profile['is_verified'] == true) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, color: AppColors.secondaryContainer, size: 18),
                              ],
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Aura Button at the right corner
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PublicAuraScreen(userId: profile['id'].toString()),
                              ),
                            );
                            if (result != null && result is Map<String, dynamic> && mounted) {
                              setState(() {
                                _profiles[_currentProfileIndex]['is_liked'] = result['is_liked'];
                                _profiles[_currentProfileIndex]['request_status'] = result['request_status'];
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: AppColors.primary.withOpacity(0.1),
                              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Aura',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (distance != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Approx. $distance miles away',
                            style: GoogleFonts.beVietnamPro(fontSize: 12, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (interests.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ( _isCardExpanded ? interests : interests.take(6) ).map((tag) {
                                final isCommon = (profile['commonInterests'] as List?)?.contains(tag) ?? false;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: isCommon ? AppColors.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                    border: Border.all(color: isCommon ? AppColors.primary.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
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
                                          color: isCommon ? AppColors.primary : AppColors.onSurfaceVariant.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            if (!_isCardExpanded && interests.length > 6)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: InkWell(
                                  onTap: () => setState(() => _isCardExpanded = true),
                                  child: Text(
                                    '+${interests.length - 6} more interests',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary.withOpacity(0.7)),
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile['bio'] ?? '',
                                maxLines: _isCardExpanded ? null : 1,
                                overflow: _isCardExpanded ? null : TextOverflow.ellipsis,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: AppColors.onSurface.withValues(alpha: 0.9),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              if (!_isCardExpanded && (profile['bio']?.length ?? 0) > 40)
                                InkWell(
                                  onTap: () => setState(() => _isCardExpanded = true),
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Read more',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_isCardExpanded) const SizedBox(height: 16),
                        ],
                      ),
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
                                if (profile['is_liked'] == true) {
                                  try {
                                    final res = await ApiService.deleteLike(profile['id']);
                                    if (res.statusCode == 200 && mounted) {
                                      setState(() {
                                        _profiles[_currentProfileIndex]['is_liked'] = false;
                                      });
                                    }
                                  } catch (_) {}
                                } else {
                                  try {
                                    final res = await ApiService.likeUser(profile['id']);
                                    if (res.statusCode == 200 && mounted) {
                                      setState(() {
                                        _profiles[_currentProfileIndex]['is_liked'] = true;
                                      });
                                    }
                                  } catch (_) {}
                                }
                              },
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: profile['is_liked'] == true 
                                    ? AppColors.tertiary 
                                    : AppColors.primary,
                                  border: profile['is_liked'] == true 
                                    ? Border.all(color: Colors.white.withValues(alpha: 0.1))
                                    : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      profile['is_liked'] == true ? Icons.favorite : Icons.favorite_border,
                                      color: profile['is_liked'] == true ? Colors.white : Colors.black,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      profile['is_liked'] == true ? 'Liked' : 'Like',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: profile['is_liked'] == true ? Colors.white : Colors.black,
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
                                    final primaryPhoto = photosList.isNotEmpty 
                                        ? photosList.firstWhere((p) => p['is_primary'] == true, orElse: () => photosList[0])
                                        : null;
                                    final avatarUrl = primaryPhoto?['url'];

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
        // Hide/Collapse button at top center - Moved to bottom of Stack for higher Z-index
        Positioned(
          top: -20,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _isInfoCardVisible = false;
                  _isCardExpanded = false;
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.4),
                  border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 2),
                  ],
                ),
                child: const Icon(Icons.expand_more_rounded, color: Colors.black, size: 30),
              ),
            ),
          ),
        ),
      ],
    );
  }
}