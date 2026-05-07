import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../discovery/profile_detail_screen.dart';
import '../aura/public_aura_screen.dart';
import '../../components/delulu_wavy_loader.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => SignalsScreenState();
}

class SignalsScreenState extends State<SignalsScreen> {
  List<Map<String, dynamic>> _likedProfiles = [];
  bool _isLoading = true;
  int _selectedCategory = 0; // 0: Main Vibes, 1: The Vault

  @override
  void initState() {
    super.initState();
    fetchLiked();
  }

  Future<void> fetchLiked() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final res = _selectedCategory == 0 
          ? await ApiService.getLikedProfiles()
          : await ApiService.getLikedHistory();
          
      final body = jsonDecode(res.body);
      if (mounted) {
        setState(() {
          _likedProfiles = List<Map<String, dynamic>>.from(body['profiles'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleCategory(int index) {
    if (_selectedCategory == index) return;
    setState(() {
      _selectedCategory = index;
    });
    fetchLiked();
  }

  Future<void> _deleteLike(String userId) async {
    await ApiService.deleteLike(userId);
    fetchLiked();
  }

  Future<void> _connect(String userId) async {
    await ApiService.sendConnectionRequest(userId);
    // Move to history if connected? No, connection request pending means it stays in signals?
    // User said: 'once the liked profile has connected it will be removed from the signals and list it in the old signals tab'
    // Connected means a channel exists. Sending a request doesn't mean connected yet.
    // So it stays in 'Main Vibes' until accepted.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connection request sent!')),
    );
    fetchLiked();
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

  Widget _buildToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(child: _buildToggleButton('Main Vibes', 0)),
          Expanded(child: _buildToggleButton('The Vault', 1)),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, int index) {
    final isSelected = _selectedCategory == index;
    return GestureDetector(
      onTap: () => _toggleCategory(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSelected ? const LinearGradient(
            colors: [AppColors.primaryContainer, AppColors.tertiaryContainer],
          ) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate();

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.favorite, color: AppColors.primary, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Signals',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 24, fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          _buildToggle(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _isLoading
                ? const Center(key: ValueKey('loading'), child: DeluluWavyLoader())
                : (_likedProfiles.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        key: ValueKey('list_$_selectedCategory'),
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
                                Padding(
                                  padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
                                  child: Text(
                                    _dateLabel(date),
                                    style: GoogleFonts.inter(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2, color: AppColors.primaryContainer,
                                    ),
                                  ),
                                ),
                                ...profiles.map((profile) => _buildLikedCard(profile)),
                                const SizedBox(height: 4),
                              ],
                            );
                          },
                        ),
                      )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('empty'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_outline, size: 48,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == 0 ? 'No active signals' : 'No history yet',
            style: GoogleFonts.beVietnamPro(
              fontSize: 16, color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategory == 0 
                ? 'Like profiles in Discovery to see them here!'
                : 'Profiles you connect with will appear here.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 14, color: AppColors.outline.withValues(alpha: 0.6),
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

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PublicAuraScreen(userId: profile['id'].toString())),
                  );
                  fetchLiked(); // Refresh after coming back
                },
                child: Row(
                  children: [
                    // Profile photo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
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
                    const SizedBox(width: 16),
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
                          const SizedBox(height: 8),
                          // Scrollable Chips
                          if (interests.isNotEmpty)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: interests.map((tag) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
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
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _deleteLike(profile['id'].toString()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _selectedCategory == 0 
                      ? (profile['request_status'] == 'pending'
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Pending',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600, 
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryContainer, AppColors.tertiaryContainer],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ElevatedButton(
                              onPressed: () => _connect(profile['id'].toString()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text(
                                'Connect',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700, 
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ))
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                              const SizedBox(width: 6),
                              Text(
                                'Matched',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.greenAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8), // Padding for the time label
            ],
          ),
        ),
        if (profile['liked_at'] != null)
          Positioned(
            right: 24,
            top: 24,
            child: Text(
              DateTime.parse(profile['liked_at']).hour.toString().padLeft(2, '0') +
                  ':' +
                  DateTime.parse(profile['liked_at']).minute.toString().padLeft(2, '0'),
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: AppColors.outline.withValues(alpha: 0.4),
              ),
            ),
          ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: AppColors.surfaceContainerHighest.withValues(alpha: 0.2),
      child: const Icon(Icons.person, color: AppColors.outlineVariant, size: 32),
    );
  }
}