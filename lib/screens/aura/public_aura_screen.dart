import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiService.getPublicProfile(widget.userId);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        _profile = body['profile'];
      }

      // Fetch current user's premium status
      final meRes = await ApiService.getMe();
      if (meRes.statusCode == 200) {
        final meBody = jsonDecode(meRes.body);
        _isMePremium = meBody['user']?['is_premium'] ?? false;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.obsidianEdge,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: AppColors.obsidianEdge,
        body: Center(
          child: Text('User not found', style: GoogleFonts.inter(color: Colors.white)),
        ),
      );
    }

    final String name = _profile!['display_name'] ?? 'User';
    final int age = _profile!['age'] ?? 0;
    final String bio = _profile!['bio'] ?? 'Delulu Dreamer';
    final int connects = _profile!['connect_count'] ?? 0;
    final int matching = _profile!['aura_score'] ?? 0;
    final List<dynamic> photos = _profile!['photos'] ?? [];
    
    final primaryPhoto = photos.firstWhere((p) => p['is_primary'] == true, orElse: () => photos.isNotEmpty ? photos[0] : null);
    final avatarUrl = primaryPhoto?['url'];

    return Scaffold(
      backgroundColor: AppColors.obsidianEdge,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
        child: Column(
          children: [
            _buildAuraHeader(avatarUrl, name, age, bio, connects, matching, photos),
            
            // Interaction Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: _profile!['is_liked'] == true ? 'Liked' : 'Like',
                      icon: _profile!['is_liked'] == true ? Icons.favorite : Icons.favorite_border,
                      color: _profile!['is_liked'] == true ? AppColors.tertiary : Colors.white.withOpacity(0.1),
                      onTap: () async {
                        if (_profile!['is_liked'] == true) return;
                        final res = await ApiService.likeUser(widget.userId);
                        if (res.statusCode == 200) {
                          setState(() => _profile!['is_liked'] = true);
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
                        if (_profile!['request_status'] != null) return;
                        final res = await ApiService.sendConnectionRequest(widget.userId);
                        if (res.statusCode == 200) {
                          setState(() => _profile!['request_status'] = 'pending');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildAuraHeader(String? avatarUrl, String name, int age, String bio, int connects, int matching, List<dynamic> allPhotos) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryContainer.withOpacity(0.2),
            AppColors.obsidianEdge,
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 100),
          Text(
            "$name's AURA",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 40),
          
          // Profile Icon & Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Row(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2.5),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 25),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(55),
                    child: avatarUrl != null
                        ? (avatarUrl.startsWith('data:image')
                            ? Image.memory(base64Decode(avatarUrl.split(',').last), fit: BoxFit.cover)
                            : CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover))
                        : Container(
                            color: AppColors.surfaceContainerHigh,
                            child: const Icon(Icons.person, color: AppColors.outlineVariant, size: 55),
                          ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(connects.toString(), 'CONNECTS'),
                      _buildStatColumn('$matching%', 'MATCHING'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Name & Age
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$name, $age',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_profile!['is_blocked'] == true) ...[
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
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    bio,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.onSurfaceVariant.withOpacity(0.9),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Photo Row (Image Section)
          if (allPhotos.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
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
            ),
            SizedBox(
              height: 180,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.primary,
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
}
