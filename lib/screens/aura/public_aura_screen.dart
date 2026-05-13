import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../premium/subscription_screen.dart';
import '../../components/delulu_wavy_loader.dart';

class PublicAuraScreen extends StatefulWidget {
  final String userId;

  const PublicAuraScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PublicAuraScreen> createState() => _PublicAuraScreenState();
}

class _PublicAuraScreenState extends State<PublicAuraScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  bool _isMePremium = false;
  bool _isBioExpanded = false;
  int? _initialLikesCount;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiService.getPublicProfile(widget.userId);
      if (res.statusCode == 200) {
        final body = await compute(jsonDecode, res.body);
        _profile = body['profile'];
        _initialLikesCount = _profile?['likes_count'] ?? 0;
      }

      // Fetch current user's premium status
      final meRes = await ApiService.getMe();
      if (meRes.statusCode == 200) {
        final meBody = await compute(jsonDecode, meRes.body);
        _isMePremium = meBody['user']?['is_premium'] ?? false;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncLikesCount() async {
    if (_profile == null || _initialLikesCount == null) return;
    final currentLikes = _profile!['likes_count'] ?? 0;
    if (currentLikes != _initialLikesCount) {
      // Update initial count so we don't sync again unnecessarily
      _initialLikesCount = currentLikes;
      await ApiService.syncLikes(widget.userId, currentLikes);
    }
  }

  void _showCustomToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.obsidianEdge,
        title: Text('Block ${_profile!['display_name']}?', style: GoogleFonts.outfit(color: Colors.white)),
        content: const Text('They will no longer be able to message you, and you won\'t be able to message them.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _syncLikesCount(); // Sync before blocking if count changed
              final res = await ApiService.blockUser(widget.userId);
              if (res.statusCode == 200) {
                _showCustomToast('User blocked');
                if (mounted) {
                  setState(() {
                    _profile!['is_blocked'] = true;
                  });
                }
              }
            },
            child: const Text('BLOCK', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showUnblockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.obsidianEdge,
        title: Text('Unblock ${_profile!['display_name']}?', style: GoogleFonts.outfit(color: Colors.white)),
        content: const Text('They will be able to message you again.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _syncLikesCount(); // Sync before unblocking if count changed
              final res = await ApiService.unblockUser(widget.userId);
              if (res.statusCode == 200) {
                _showCustomToast('User unblocked');
                if (mounted) {
                  setState(() {
                    _profile!['is_blocked'] = false;
                  });
                }
              }
            },
            child: const Text('UNBLOCK', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.obsidianEdge,
        title: Text('Report ${_profile!['display_name']}', style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tell us why you are reporting this user:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(context);
              await _syncLikesCount(); // Sync before reporting if count changed
              final res = await ApiService.reportUser(widget.userId, reasonController.text.trim());
              if (res.statusCode == 200) {
                _showCustomToast('Reported successfully');
              }
            },
            child: const Text('REPORT', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showDisconnectConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.obsidianEdge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Disconnect from ${_profile!['display_name']}?',
          style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Text(
          'You will no longer be connected and your chat history will be removed. Are you sure?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'KEEP CONNECTION',
              style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _syncLikesCount(); // Sync before disconnecting if count changed
              final res = await ApiService.disconnectUser(widget.userId);
              if (res.statusCode == 200) {
                _showCustomToast('Disconnected successfully');
                if (mounted) {
                  setState(() {
                    _profile!['request_status'] = null;
                  });
                }
              }
            },
            child: Text(
              'DISCONNECT',
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
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2E1065), Colors.black],
            ),
          ),
          child: const Center(child: DeluluWavyLoader()),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2E1065), Colors.black],
            ),
          ),
          child: Center(
            child: Text('User not found', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ),
      );
    }

    final String displayName = _profile!['display_name'] ?? 'User';
    final int age = _profile!['age'] ?? 0;
    final String bio = _profile!['bio'] ?? 'Delulu Dreamer';
    final List<dynamic> photos = _profile!['photos'] ?? [];
    final List<dynamic> interests = _profile!['interests'] ?? [];

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          _syncLikesCount();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E1065), Colors.black],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'DELULU',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                _syncLikesCount();
                Navigator.pop(context, {
                  'is_liked': _profile?['is_liked'],
                  'request_status': _profile?['request_status'],
                });
              },
            ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: AppColors.obsidianEdge,
            elevation: 8,
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            constraints: const BoxConstraints(minWidth: 180),
            onSelected: (value) {
              if (value == 'block') {
                _showBlockConfirmation();
              } else if (value == 'unblock') {
                _showUnblockConfirmation();
              } else if (value == 'report') {
                _showReportDialog();
              }
            },
            itemBuilder: (context) {
              final bool isBlocked = _profile!['is_blocked'] == true;
              return [
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      const Icon(Icons.report_problem_outlined, size: 20, color: Colors.white70),
                      const SizedBox(width: 12),
                      Text('Report User', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: isBlocked ? 'unblock' : 'block',
                  child: Row(
                    children: [
                      Icon(
                        isBlocked ? Icons.lock_open_outlined : Icons.block_flipped,
                        size: 20,
                        color: isBlocked ? Colors.greenAccent : Colors.redAccent,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isBlocked ? 'Unblock User' : 'Block User',
                        style: GoogleFonts.inter(
                          color: isBlocked ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            RepaintBoundary(child: _buildPublicProfileTitle(displayName)),
            const SizedBox(height: 32),
            
            // Glass Card for Profile Details
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        _buildProfileHeader(displayName, age),
                        const SizedBox(height: 20),
                        
                        _buildStatsSection(
                          connections: _profile?['connect_count'] ?? 0,
                          likes: _profile?['likes_count'] ?? 0,
                          auraScore: _profile?['aura_score'] ?? 0,
                        ),
                        
                        const SizedBox(height: 20),
                        _buildBioSection(bio),
                        if (interests.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildInterestsSection(interests),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Interaction Buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: _profile!['is_liked'] == true ? 'Liked' : 'Like',
                    icon: _profile!['is_liked'] == true ? Icons.favorite : Icons.favorite_border,
                    color: _profile!['is_liked'] == true ? AppColors.tertiary : AppColors.primary,
                    isPrimary: _profile!['is_liked'] != true,
                    onTap: () async {
                      if (_profile!['is_liked'] == true) {
                        final res = await ApiService.deleteLike(widget.userId);
                        if (res.statusCode == 200) {
                          setState(() {
                            _profile!['is_liked'] = false;
                            _profile!['likes_count'] = math.max(0, (_profile!['likes_count'] ?? 1) - 1);
                          });
                        }
                      } else {
                        final res = await ApiService.likeUser(widget.userId);
                        if (res.statusCode == 200) {
                          setState(() {
                            _profile!['is_liked'] = true;
                            _profile!['likes_count'] = (_profile!['likes_count'] ?? 0) + 1;
                          });
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: _profile!['request_status'] == 'accepted' 
                      ? 'Connected' 
                      : _profile!['request_status'] == 'pending' 
                        ? 'Pending' 
                        : 'Connect',
                    icon: _profile!['request_status'] == 'accepted' 
                      ? Icons.link 
                      : _profile!['request_status'] == 'pending' 
                        ? Icons.hourglass_empty 
                        : Icons.bolt,
                    isPrimary: _profile!['request_status'] == null,
                    onTap: () async {
                      if (_profile!['request_status'] == 'accepted') {
                        _showDisconnectConfirmation();
                      } else if (_profile!['request_status'] == null) {
                        final res = await ApiService.sendConnectionRequest(widget.userId);
                        if (res.statusCode == 200) {
                          setState(() => _profile!['request_status'] = 'pending');
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            if (!_isMePremium) ...[
              _buildRizzPlusBanner(),
              const SizedBox(height: 40),
            ],

            // Gallery Section
            if (photos.isNotEmpty) RepaintBoundary(child: _buildGallerySection(photos)),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  ),
),
);
}

  Widget _buildPublicProfileTitle(String name) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        "The Aura",
        style: GoogleFonts.beVietnamPro(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -1,
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String name, int age) {
    final bool isBlocked = _profile?['is_blocked'] == true;
    final bool isPremiumUser = _profile?['is_premium_user'] == true;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                '$name, $age',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isPremiumUser) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium, size: 14, color: Colors.black),
              ),
            ],
            if (isBlocked) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Text(
                  'BLOCKED',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatsSection({required int connections, required int likes, required int auraScore}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Connects', connections.toString(), Icons.people_outline),
          _buildStatDivider(),
          _buildStatItem('Likes', likes.toString(), Icons.favorite_border),
          _buildStatDivider(),
          _buildStatItem('Matching', '$auraScore%', Icons.auto_awesome),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.beVietnamPro(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildBioSection(String bio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'BIO',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          alignment: Alignment.topCenter,
          curve: Curves.easeInOut,
          child: GestureDetector(
            onTap: () {
              if (bio.length > 80) {
                setState(() {
                  _isBioExpanded = !_isBioExpanded;
                });
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bio,
                  maxLines: _isBioExpanded ? null : 2,
                  overflow: _isBioExpanded ? null : TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.left,
                ),
                if (!_isBioExpanded && bio.length > 80)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Read more',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInterestsSection(List<dynamic> interests) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.tertiary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'INTERESTS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppColors.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: interests.map((interest) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.2), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tertiary.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tag, size: 12, color: AppColors.tertiary.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text(
                    interest.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGallerySection(List<dynamic> allPhotos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Text(
            'GALLERY',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: AppColors.primary.withOpacity(0.7),
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: allPhotos.length,
            itemBuilder: (context, index) {
              final photo = allPhotos[index];
              final photoUrl = photo['url'];
              final isPrivate = photo['is_private'] == true;
              final shouldBlur = isPrivate && !_isMePremium && _profile?['request_status'] != 'accepted';

              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      photoUrl.startsWith('data:image')
                          ? Image.memory(base64Decode(photoUrl.split(',').last), fit: BoxFit.cover)
                          : CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover),
                      if (shouldBlur)
                        Positioned.fill(
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                color: Colors.black.withOpacity(0.4),
                                child: const Center(
                                  child: Icon(Icons.lock_outline, color: Colors.white70, size: 30),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color ?? (isPrimary ? AppColors.primary : Colors.white.withOpacity(0.05)),
            border: isPrimary ? null : Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isPrimary ? Colors.black : Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isPrimary ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRizzPlusBanner() {
    return Container(
      width: double.infinity,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA500).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
            if (result == true) {
              _loadProfile();
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.black, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Rizz+',
                        style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Unlimited plays & see who likes you',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.black.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
