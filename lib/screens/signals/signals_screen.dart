import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => SignalsScreenState();
}

class SignalsScreenState extends State<SignalsScreen> {
  List<Map<String, dynamic>> _likedProfiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchLiked();
  }

  Future<void> fetchLiked() async {
    try {
      final res = await ApiService.getLikedProfiles();
      final body = jsonDecode(res.body);
      if (mounted) {
        setState(() {
          _likedProfiles =
              List<Map<String, dynamic>>.from(body['profiles'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Groups profiles by date (ignoring time), returns a sorted list of maps
  /// with key 'date' and 'profiles'.
  List<Map<String, dynamic>> _groupByDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Group by date string (yyyy-MM-dd)
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final profile in _likedProfiles) {
      try {
        final likedAt = DateTime.parse(profile['liked_at']);
        final dateKey = '${likedAt.year}-${likedAt.month.toString().padLeft(2, '0')}-${likedAt.day.toString().padLeft(2, '0')}';
        grouped.putIfAbsent(dateKey, () => []).add(profile);
      } catch (_) {
        // If parsing fails, put in a catch-all group
        grouped.putIfAbsent('unknown', () => []).add(profile);
      }
    }

    // Convert to list and sort by date descending
    final List<Map<String, dynamic>> sortedGroups = grouped.entries.map((entry) {
      DateTime? date;
      if (entry.key == 'unknown') {
        date = null;
      } else {
        final parts = entry.key.split('-');
        date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
      return {
        'date': date,
        'profiles': entry.value,
      };
    }).toList();

    // Sort: unknown last, then most recent first
    sortedGroups.sort((a, b) {
      final aDate = a['date'] as DateTime?;
      final bDate = b['date'] as DateTime?;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate); // descending
    });

    return sortedGroups;
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      // Format like "Jun 23"
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryContainer),
      );
    }

    if (_likedProfiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, size: 48,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No Signals yet',
              style: GoogleFonts.beVietnamPro(
                fontSize: 16,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start liking profiles in Vibes!',
              style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                color: AppColors.outline.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    final grouped = _groupByDate();

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.bolt, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Signals',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchLiked,
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final group = grouped[index];
                  final date = group['date'] as DateTime?;
                  final profiles = group['profiles'] as List<Map<String, dynamic>>;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section header
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
                        child: Text(
                          _dateLabel(date),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: AppColors.primaryContainer,
                          ),
                        ),
                      ),
                      // Profiles in this group
                      ...profiles.map((profile) => _buildLikedCard(profile)),
                      const SizedBox(height: 4),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedCard(Map<String, dynamic> profile) {
    final photos = List<Map<String, dynamic>>.from(profile['photos'] ?? []);
    final imageUrl = photos.isNotEmpty ? photos[0]['url'] : null;
    final interests = List<String>.from(profile['interests'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile photo
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 70,
              height: 70,
              color: AppColors.surfaceContainerHigh,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? (imageUrl.startsWith('data:image')
                      ? Image.memory(
                          base64Decode(imageUrl.split(',').last),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultAvatar(),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _defaultAvatar(),
                        ))
                  : _defaultAvatar(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${profile['display_name']}, ${profile['age']}',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                if (profile['liked_at'] != null)
                  Text(
                    DateTime.parse(profile['liked_at']).hour.toString().padLeft(2, '0') +
                        ':' +
                        DateTime.parse(profile['liked_at']).minute.toString().padLeft(2, '0'),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.outline.withValues(alpha: 0.5),
                    ),
                  ),
                const SizedBox(height: 4),
                if (interests.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: interests.take(3).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AppColors.primary.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '#$tag',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.send_rounded,
                color: AppColors.primaryContainer, size: 22),
            onPressed: () {
              // Future: open chat / send connection
            },
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: AppColors.surfaceContainerHighest.withValues(alpha: 0.2),
      child: const Icon(Icons.person, color: AppColors.outlineVariant, size: 32),
    );
  }
}