import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';

class ProfileRequestViewScreen extends StatefulWidget {
  final int requestId;
  final Map<String, dynamic> profile;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const ProfileRequestViewScreen({
    super.key,
    required this.requestId,
    required this.profile,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<ProfileRequestViewScreen> createState() => _ProfileRequestViewScreenState();
}

class _ProfileRequestViewScreenState extends State<ProfileRequestViewScreen> {
  int _currentImageIndex = 0;
  late PageController _pageController;
  bool _isCardExpanded = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final photos = List<Map<String, dynamic>>.from(profile['photos'] ?? []);
    final interests = List<String>.from(profile['interests'] ?? []);
    final bio = profile['bio'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.obsidianEdge,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${profile['display_name']}, ${profile['age']}',
          style: GoogleFonts.beVietnamPro(color: AppColors.onSurface),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Photo swiper (like discovery but doesn't fetch feed)
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
                              : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
                          if (isPrivate)
                            Positioned.fill(
                              child: ClipRect(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                                  child: Container(color: Colors.black.withValues(alpha: 0.2)),
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
                // Page indicators
                if (photos.length > 1)
                  Positioned(
                    bottom: 20,
                    left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(photos.length, (i) {
                        final isActive = i == _currentImageIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 10 : 6, height: isActive ? 10 : 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive ? AppColors.primary : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
          // Info card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (interests.isNotEmpty) ...[
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: interests.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text('#$tag', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (bio.isNotEmpty)
                  Text(bio, style: GoogleFonts.beVietnamPro(fontSize: 16, color: AppColors.onSurface.withValues(alpha: 0.9))),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          widget.onAccept();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.greenAccent,
                          side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 20),
                            const SizedBox(width: 8),
                            Text('Accept', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          widget.onReject();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cancel_outlined, size: 20),
                            const SizedBox(width: 8),
                            Text('Reject', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}