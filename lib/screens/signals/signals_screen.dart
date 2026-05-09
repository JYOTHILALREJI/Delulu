import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../aura/public_aura_screen.dart';
import '../../components/delulu_wavy_loader.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => SignalsScreenState();
}

class SignalsScreenState extends State<SignalsScreen> {
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  int _selectedCategory = 0; // 0: Main Vibes (Outgoing), 1: The Vault (Incoming)

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final res = _selectedCategory == 0 
          ? await ApiService.getLikedProfiles()
          : await ApiService.getReceivedLikes();
          
      final body = jsonDecode(res.body);
      if (mounted) {
        setState(() {
          _profiles = List<Map<String, dynamic>>.from(body['profiles'] ?? []);
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
    fetchData();
  }

  Future<void> _deleteLike(String userId) async {
    await ApiService.deleteLike(userId);
    fetchData();
  }

  Future<void> _connect(String userId) async {
    final res = await ApiService.sendConnectionRequest(userId);
    if (res.statusCode == 200) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection request sent!')),
      );
      fetchData();
    }
  }

  List<Map<String, dynamic>> _getSortedProfiles() {
    if (_selectedCategory == 1) {
      // The Vault: Incoming likes sorted by date
      final list = List<Map<String, dynamic>>.from(_profiles);
      list.sort((a, b) {
        final aDate = DateTime.tryParse(a['liked_at'] ?? '') ?? DateTime(0);
        final bDate = DateTime.tryParse(b['liked_at'] ?? '') ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
      return list;
    }

    // Main Vibes: New Likes > Pending > Matched
    List<Map<String, dynamic>> newLikes = [];
    List<Map<String, dynamic>> pendingRequests = [];
    List<Map<String, dynamic>> matched = [];

    for (var p in _profiles) {
      if (p['request_status'] == 'accepted' || p['status'] == 'connected') {
        matched.add(p);
      } else if (p['request_status'] == 'pending') {
        pendingRequests.add(p);
      } else {
        newLikes.add(p);
      }
    }

    final dateSort = (Map<String, dynamic> a, Map<String, dynamic> b) {
      final aDate = DateTime.tryParse(a['liked_at'] ?? '') ?? DateTime(0);
      final bDate = DateTime.tryParse(b['liked_at'] ?? '') ?? DateTime(0);
      return bDate.compareTo(aDate);
    };

    newLikes.sort(dateSort);
    pendingRequests.sort(dateSort);
    matched.sort(dateSort);

    return [...newLikes, ...pendingRequests, ...matched];
  }

  String _getTimeLabel(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedProfiles = _getSortedProfiles();

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: AppColors.primary, size: 28),
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
                : (sortedProfiles.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        key: ValueKey('list_$_selectedCategory'),
                        onRefresh: fetchData,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: sortedProfiles.length,
                          itemBuilder: (context, index) {
                            return _buildProfileCard(sortedProfiles[index]);
                          },
                        ),
                      )),
            ),
          ),
        ],
      ),
    );
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
            _selectedCategory == 0 ? 'No active signals' : 'Vault is empty',
            style: GoogleFonts.beVietnamPro(
              fontSize: 16, color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategory == 0 
                ? 'Like profiles in Discovery to see them here!'
                : 'See who liked your profile here.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 14, color: AppColors.outline.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    final photos = List<Map<String, dynamic>>.from(profile['photos'] ?? []);
    final primaryPhoto = photos.isNotEmpty 
        ? photos.firstWhere((p) => p['is_primary'] == true, orElse: () => photos[0])
        : null;
    final imageUrl = primaryPhoto?['url'];
    final interests = List<String>.from(profile['interests'] ?? []);

    final bool isMatched = profile['request_status'] == 'accepted' || profile['status'] == 'connected';
    final bool isPending = profile['request_status'] == 'pending';

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isMatched ? Colors.greenAccent.withOpacity(0.2) : AppColors.primary.withValues(alpha: 0.15), 
              width: 1.2
            ),
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
                  fetchData(); 
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
                          Row(
                            children: [
                              Text(
                                '${profile['display_name']}, ${profile['age']}',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              if (isMatched) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
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
                                      color: (isMatched ? Colors.greenAccent : AppColors.primary).withValues(alpha: 0.1),
                                      border: Border.all(color: (isMatched ? Colors.greenAccent : AppColors.primary).withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isMatched ? Colors.greenAccent : AppColors.primary,
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
              if (_selectedCategory == 0) // Main Vibes
                Row(
                  children: [
                    if (!isMatched) ...[
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
                    ],
                    Expanded(
                      child: isMatched
                        ? Container(
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
                          )
                        : isPending
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Pending Request',
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
                            ),
                    ),
                  ],
                )
              else // The Vault (Incoming)
                 Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Liked your profile',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8), 
            ],
          ),
        ),
        Positioned(
          right: 24,
          top: 24,
          child: Text(
            _getTimeLabel(profile['liked_at']),
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