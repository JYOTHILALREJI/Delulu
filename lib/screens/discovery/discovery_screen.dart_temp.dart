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
                    // Header Row (always visible)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name + verified icon (overflow fixed)
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
                                    Icon(
                                      Icons.verified,
                                      color: AppColors.secondaryContainer,
                                      size: 22,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Location row
                              if (distance != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
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
                        // Info / Expand-Collapse button
                        InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            setState(() {
                              _isCardExpanded = !_isCardExpanded;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.05),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Icon(
                              _isCardExpanded
                                  ? Icons.expand_more_rounded
                                  : Icons.expand_less_rounded,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Collapsible section: interests + bio
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.2)),
                                        ),
                                        child: Text(
                                          tag,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
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

                    // Action Buttons (always visible)
                    Row(
                      children: [
                        Expanded(
                          flex: profile['request_status'] == 'accepted' ? 1 : 1,
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
                                  color: profile['is_liked'] == true
                                      ? AppColors.primary.withValues(alpha: 0.2)
                                      : AppColors.primary,
                                  boxShadow: profile['is_liked'] == true
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Center(
                                  child: Icon(
                                    profile['is_liked'] == true
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                if (profile['request_status'] == 'accepted' ||
                                    profile['request_status'] == 'pending') return;
                                try {
                                  final res =
                                      await ApiService.sendConnectionRequest(profile['id']);
                                  if (res.statusCode == 201 && mounted) {
                                    setState(() {
                                      _profiles[_currentProfileIndex]['request_status'] =
                                          'pending';
                                    });
                                    _showCustomToast('Request Sent!');
                                  }
                                } catch (_) {}
                              },
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: profile['request_status'] == 'accepted' ||
                                          profile['request_status'] == 'pending'
                                      ? null
                                      : const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.secondary,
                                            AppColors.accent,
                                          ],
                                        ),
                                  color: profile['request_status'] == 'accepted' ||
                                          profile['request_status'] == 'pending'
                                      ? AppColors.onSurface.withValues(alpha: 0.1)
                                      : null,
                                  boxShadow: profile['request_status'] == 'accepted' ||
                                          profile['request_status'] == 'pending'
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: AppColors.accent.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      profile['request_status'] == 'accepted'
                                          ? Icons.bolt
                                          : profile['request_status'] == 'pending'
                                              ? Icons.hourglass_empty
                                              : Icons.bolt_outlined,
                                      color: profile['request_status'] == 'pending'
                                          ? Colors.white70
                                          : Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile['request_status'] == 'accepted'
                                          ? 'Connected'
                                          : profile['request_status'] == 'pending'
                                              ? 'Pending'
                                              : 'Connect',
                                      style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: profile['request_status'] == 'pending'
                                              ? Colors.white70
                                              : Colors.white),
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
                                        photosList = List<Map<String, dynamic>>.from(
                                            jsonDecode(photosData));
                                      } catch (_) {}
                                    } else if (photosData is List) {
                                      photosList =
                                          List<Map<String, dynamic>>.from(photosData);
                                    }
                                    final avatarUrl =
                                        photosList.isNotEmpty ? photosList[0]['url'] : null;

                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            channelId: profile['channel_id'],
                                            peerId: profile['id'],
                                            peerName:
                                                '${profile['display_name']}, ${profile['age']}',
                                            peerImageUrl: avatarUrl,
                                            isOnline: profile['is_online'] ?? false,
                                          ),
                                        ));
                                  } else {
                                    _showCustomToast('Chat channel not ready yet',
                                        isError: true);
                                  }
                                },
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primaryContainer,
                                        AppColors.tertiaryContainer,
                                      ],
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
                                      const Icon(Icons.mark_unread_chat_alt_outlined,
                                          color: Colors.white, size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Whisper',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white),
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
        // Hide button (down arrow)
        Positioned(
          top: -20,
          right: 20,
          child: GestureDetector(
            onTap: () => setState(() => _isInfoCardVisible = false),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.5),
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(Icons.expand_more, color: Colors.white70, size: 24),
            ),
          ),
        ),
      ],
    );
  }
