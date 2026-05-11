import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../whisper/chat_screen.dart';
import '../aura/public_aura_screen.dart';
import 'discovery_filter_drawer.dart';
import 'leaderboard_screen.dart';
import '../premium/subscription_screen.dart';
import '../../components/delulu_wavy_loader.dart';
import 'location_picker_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => DiscoveryScreenState();
}

class DiscoveryScreenState extends State<DiscoveryScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _profiles = [];
  int _currentProfileIndex = 0;
  int _currentImageIndex = 0; // for page indicator
  bool _isLoading = true;
  bool _isCardExpanded = true; // collapse/expand toggle
  bool _isInfoCardVisible = true;
  bool _isPremium = false;
  bool _isLeaderboardLoading = false;
  bool _currentUserHasLocation = false;
  String? _myId;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _showRizzTooltip = false;
  final Set<String> _shakenProfileIds = {};
  Timer? _tooltipTimer;

  // Filter states
  double _minAge = 18;
  double _maxAge = 100;
  double _distanceMiles = 500; // Default max in Miles

  bool _isFetchingMore = false;
  bool _hasMore = true;
  final int _batchSize = 10;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _fetchFeed();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final res = await ApiService.getMe();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (mounted) {
          final user = body['user'];
          final lat = user?['latitude'];
          final lon = user?['longitude'];
          setState(() {
            _isPremium = user?['is_premium'] ?? false;
            _currentUserHasLocation = lat != null && lon != null;
            _myId = user?['id']?.toString();
            // Default distance is 20 miles for non-premium
            if (!_isPremium && _distanceMiles > 20) {
              _distanceMiles = 20;
            }
          });
        }
      }
    } catch (e) {
      print('Error checking premium: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _shakeController.dispose();
    _tooltipTimer?.cancel();
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
        distanceMiles: _distanceMiles < 500 ? _distanceMiles : null,
        limit: _batchSize,
        offset: offset,
      );
      final body = await compute<String, dynamic>(jsonDecode, res.body);
      if (mounted) {
        final List<dynamic> data = body['profiles'] ?? [];
        setState(() {
          final newProfiles = data.map((e) {
            final profile = Map<String, dynamic>.from(e);
            if (profile['photos'] != null) {
              final photos = List<Map<String, dynamic>>.from(profile['photos']);
              for (var photo in photos) {
                 if (photo['url'] != null && photo['url'].toString().startsWith('data:image')) {
                    photo['bytes'] = base64Decode(photo['url'].toString().split(',').last);
                 }
              }
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
            if (_profiles.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _checkAndEmphasizeRizzPlus();
              });
            }
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
    } else if (!_hasMore && _currentProfileIndex == _profiles.length - 1) {
      bool filtersApplied = _minAge != 18 || _maxAge != 100 || _distanceMiles < 500;
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
      _checkAndEmphasizeRizzPlus();
    } else {
      _loadMoreProfiles(); // Load next batch only at the absolute end
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
      _checkAndEmphasizeRizzPlus();
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
        isPremium: _isPremium,
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

  void _checkAndEmphasizeRizzPlus() {
    if (_isPremium) return;
    if (_profiles.isEmpty) return;
    
    final profile = _profiles[_currentProfileIndex];
    final photos = List<Map<String, dynamic>>.from(profile['photos'] ?? []);
    if (photos.isEmpty) return;
    
    final photo = photos[_currentImageIndex];
    final bool isPrivate = photo['is_private'] == true;
    final bool isAccepted = profile['request_status'] == 'accepted';
    
    if (isPrivate && !isAccepted) {
      // Shaking & Tooltip logic (once per profile)
      final String profileId = profile['id'].toString();
      if (!_shakenProfileIds.contains(profileId)) {
        _shakenProfileIds.add(profileId);
        _shakeController.forward(from: 0);
        setState(() {
          _showRizzTooltip = true;
        });
        _tooltipTimer?.cancel();
        _tooltipTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showRizzTooltip = false);
        });
      }
    }
  }

  List<Map<String, dynamic>> _parsePhotos(dynamic photosData) {
    if (photosData == null) return [];
    if (photosData is List) return List<Map<String, dynamic>>.from(photosData);
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: DeluluWavyLoader(),
      );
    }

    final profile = _profiles.isNotEmpty ? _profiles[_currentProfileIndex] : null;
    final photos = profile != null ? _parsePhotos(profile['photos']) : [];

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (_profiles.isEmpty) return;
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -500) {
            _nextProfile(); // Swipe Up
          } else if (details.primaryVelocity! > 500) {
            _prevProfile(); // Swipe Down
          }
        }
      },
      child: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Stack(
                key: ValueKey(_profiles.isEmpty ? 'empty' : _currentProfileIndex),
                children: [
                  // Layer 1: Content (Profiles or Empty Placeholder)
                  if (_profiles.isEmpty)
                    Positioned.fill(
                      child: Container(
                        color: AppColors.background,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_off_outlined,
                                size: 48,
                                color: AppColors.onSurfaceVariant.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                (_minAge != 18 || _maxAge != 100 || _distanceMiles != 500)
                                    ? 'No profiles found matching your filters.'
                                    : 'No Delulus around right now.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 14,
                                  color: AppColors.onSurfaceVariant.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else ...[
                    // Layer 1: Immersive Image Swiper
                    if (_isFetchingMore)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DeluluWavyLoader(fontSize: 20),
                                SizedBox(height: 16),
                                Text(
                                  'Fetching next batch...',
                                  style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: PageView.builder(
                          allowImplicitScrolling: true,
                          controller: _pageController,
                          itemCount: photos.length,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                            _checkAndEmphasizeRizzPlus();
                          },
                          itemBuilder: (context, index) {
                            final photo = photos[index];
                            final imageUrl = photo['url'];
                            final isPrivate = photo['is_private'] == true;

                            Widget imageWidget;
                            if (photo['bytes'] != null) {
                              imageWidget = Image.memory(
                                photo['bytes'],
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.topCenter,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: AppColors.surfaceContainerHigh,
                                  child: const Icon(Icons.broken_image, color: AppColors.outlineVariant, size: 48),
                                ),
                              );
                            } else if (imageUrl.startsWith('data:image')) {
                              imageWidget = Image.memory(
                                base64Decode(imageUrl.split(',').last),
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.topCenter,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.high,
                              );
                            } else {
                              imageWidget = CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.topCenter,
                                fadeInDuration: const Duration(milliseconds: 0),
                                filterQuality: FilterQuality.high,
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
                                Container(
                                  color: AppColors.background,
                                  child: imageWidget,
                                ),
                                if (isPrivate && (profile?['request_status'] ?? '') != 'accepted')
                                  Positioned.fill(
                                    child: ClipRect(
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                                        child: Container(
                                          color: Colors.black.withOpacity(0.2),
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
                    ),

                    // Layer 2: Page indicators
                    if (photos.length > 1)
                      Positioned(
                        bottom: 120, // Moved up
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

                    // Layer 3: Glass Info Card
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      left: 12,
                      right: 12,
                      bottom: _isInfoCardVisible ? 80 : -600, // slide out
                      child: RepaintBoundary(child: _buildInfoCard(profile!, photos.length)),
                    ),

                    // Show handle when card is hidden
                    if (!_isInfoCardVisible)
                      Positioned(
                        bottom: 85, // Above bottom navbar
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => setState(() => _isInfoCardVisible = true),
                            child: Container(
                              width: 60,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.2),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
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
                            color: AppColors.onSurfaceVariant.withOpacity(0.2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Swipe up/down to navigate',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              letterSpacing: 2.4,
                              color: AppColors.onSurfaceVariant.withOpacity(0.2),
                            ),
                          ),
                          Icon(
                            Icons.expand_less,
                            size: 16,
                            color: AppColors.onSurfaceVariant.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Layer 7: Rizz+ Upgrade Button (Top Center) - Always visible if not premium
                  if (!_isPremium)
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_shakeAnimation.value, 0),
                              child: child,
                            );
                          },
                          child: GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                              );
                              if (result == true) {
                                _checkPremiumStatus();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFA500).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bolt, color: Colors.black, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'RIZZ+',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Layer 8: Tooltip (appears below button) - Only if profiles exist
                  if (!_isPremium && _profiles.isNotEmpty)
                    Positioned(
                      top: 115,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: _showRizzTooltip ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 1500),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'Upgrade to view the clear image',
                              style: GoogleFonts.inter(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _showFilterDrawer,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DISCOVERY',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Around You',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: _isLeaderboardLoading ? null : () async {
              setState(() => _isLeaderboardLoading = true);
              // Small delay to show loader
              await Future.delayed(const Duration(milliseconds: 600));
              if (mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                );
                setState(() => _isLeaderboardLoading = false);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.05),
                  ],
                ),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  if (_isLeaderboardLoading)
                    const DeluluWavyLoader(fontSize: 10)
                  else
                    const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _isLeaderboardLoading ? 'LOADING...' : 'LEADERBOARD',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> profile, int photoCount) {
    final interests = List<String>.from(profile['interests'] ?? []);
    final distance = profile['distance_miles'];
    final bool isLiked = profile['is_liked'] == true;
    final String requestStatus = profile['request_status'] ?? 'none';

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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), // Reduced top padding for handle
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
                    // Handle Bar
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() => _isInfoCardVisible = false),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16, top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '${profile['display_name'] ?? 'Anonymous'}, ${profile['age'] ?? '??'}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (profile['is_premium'] == true)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFD700),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.bolt, size: 12, color: Colors.black),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (profile['hide_location_enabled'] != true) 
                                const Icon(Icons.location_on, size: 12, color: AppColors.primary),
                              if (profile['hide_location_enabled'] != true) 
                                const SizedBox(width: 4),
                              Text(
                                profile['hide_location_enabled'] == true 
                                  ? 'Location Hidden'
                                  : '${distance?.toStringAsFixed(1) ?? '??'} mi',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (interests.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: interests.take(5).map((interest) {
                          final isCommon = (profile['commonInterests'] as List<dynamic>?)?.contains(interest) ?? false;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isCommon ? AppColors.primary.withOpacity(0.15) : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCommon ? AppColors.primary.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                                width: isCommon ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              interest,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isCommon ? AppColors.primary : Colors.white.withOpacity(0.9),
                                fontWeight: isCommon ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        // View Aura Button (Fixed width if Whisper is present, else Expanded)
                        if (requestStatus != 'accepted') ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PublicAuraScreen(userId: profile['id'].toString()),
                                  ),
                                );
                              },
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Center(
                                  child: Text(
                                    'VIEW AURA',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Like Button
                          GestureDetector(
                            onTap: () async {
                              if (isLiked) return;
                              final res = await ApiService.likeUser(profile['id'].toString());
                              if (res.statusCode == 200) {
                                setState(() {
                                  _profiles[_currentProfileIndex]['is_liked'] = true;
                                });
                                _showCustomToast('Liked!');
                              }
                            },
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: isLiked ? AppColors.primary.withOpacity(0.3) : AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: isLiked ? [] : [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Connect Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                if (requestStatus != 'none') return;
                                final res = await ApiService.sendConnectionRequest(profile['id'].toString());
                                if (res.statusCode == 201) {
                                  setState(() {
                                    _profiles[_currentProfileIndex]['request_status'] = 'pending';
                                  });
                                  _showCustomToast('Request Sent!');
                                }
                              },
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: requestStatus == 'none' ? const LinearGradient(
                                    colors: [AppColors.secondary, AppColors.tertiary],
                                  ) : null,
                                  color: requestStatus != 'none' ? Colors.white.withOpacity(0.05) : null,
                                  borderRadius: BorderRadius.circular(20),
                                  border: requestStatus != 'none' ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
                                ),
                                child: Center(
                                  child: Text(
                                    requestStatus == 'pending' ? 'PENDING' : 'CONNECT',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // When accepted, show Whisper and View Aura
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PublicAuraScreen(userId: profile['id'].toString()),
                                  ),
                                );
                              },
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Center(
                                  child: Text(
                                    'VIEW AURA',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              if (profile['channel_id'] != null) {
                                final photos = _parsePhotos(profile['photos']);
                                final avatarUrl = photos.isNotEmpty ? photos[0]['url'] : null;
                                
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      channelId: profile['channel_id'],
                                      peerId: profile['id'].toString(),
                                      peerName: profile['display_name'] ?? 'Anonymous',
                                      peerImageUrl: avatarUrl,
                                      isOnline: profile['is_online'] ?? false,
                                    ),
                                  ),
                                );
                              } else {
                                _showCustomToast('Initializing chat...', isError: false);
                              }
                            },
                            child: Container(
                              width: 120,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'WHISPER',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
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
        // Top Right Chat Icon if Accepted
        if (requestStatus == 'accepted')
          Positioned(
            top: 20,
            right: 20,
            child: GestureDetector(
              onTap: () {
                if (profile['channel_id'] != null) {
                  final photos = _parsePhotos(profile['photos']);
                  final avatarUrl = photos.isNotEmpty ? photos[0]['url'] : null;
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        channelId: profile['channel_id'],
                        peerId: profile['id'].toString(),
                        peerName: profile['display_name'] ?? 'Anonymous',
                        peerImageUrl: avatarUrl,
                        isOnline: profile['is_online'] ?? false,
                      ),
                    ),
                  );
                }
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
      ],
    );
  }
}