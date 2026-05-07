import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import 'public_aura_screen.dart';
import '../../components/delulu_wavy_loader.dart';

class BlockedProfilesScreen extends StatefulWidget {
  const BlockedProfilesScreen({super.key});

  @override
  State<BlockedProfilesScreen> createState() => _BlockedProfilesScreenState();
}

class _BlockedProfilesScreenState extends State<BlockedProfilesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];
  final Map<String, ImageProvider> _avatarCache = {};

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final res = await ApiService.getBlockedUsers();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List<dynamic> users = body['blocked'] ?? [];
        
        // Pre-cache avatars
        for (var user in users) {
          final photos = user['photos'] as List? ?? [];
          final primaryPhoto = photos.firstWhere((p) => p['is_primary'] == true, orElse: () => photos.isNotEmpty ? photos[0] : null);
          final avatarUrl = primaryPhoto?['url'] as String?;
          
          if (avatarUrl != null && !_avatarCache.containsKey(avatarUrl)) {
            if (avatarUrl.startsWith('data:image')) {
              _avatarCache[avatarUrl] = MemoryImage(base64Decode(avatarUrl.split(',').last));
            } else {
              _avatarCache[avatarUrl] = CachedNetworkImageProvider(avatarUrl);
            }
          }
        }

        if (mounted) {
          setState(() {
            _blockedUsers = List<Map<String, dynamic>>.from(users);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianEdge,
      appBar: AppBar(
        backgroundColor: AppColors.obsidianEdge,
        elevation: 0,
        title: Text(
          'Blocked Profiles',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBlockedUsers,
        color: AppColors.primary,
        backgroundColor: AppColors.obsidianEdge,
        child: _isLoading
            ? const Center(child: DeluluWavyLoader())
            : _blockedUsers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator with short lists
                    itemCount: _blockedUsers.length,
                    itemBuilder: (context, index) {
                      final user = _blockedUsers[index];
                      final photos = user['photos'] as List? ?? [];
                      final primaryPhoto = photos.firstWhere((p) => p['is_primary'] == true, orElse: () => photos.isNotEmpty ? photos[0] : null);
                      final avatarUrl = primaryPhoto?['url'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: AppColors.surfaceContainerHigh,
                            backgroundImage: avatarUrl != null && _avatarCache.containsKey(avatarUrl)
                                ? _avatarCache[avatarUrl]
                                : null,
                            child: (avatarUrl == null || !_avatarCache.containsKey(avatarUrl))
                                ? const Icon(Icons.person, color: AppColors.outlineVariant)
                                : null,
                          ),
                          title: Text(
                            user['display_name'] ?? 'Unknown',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          subtitle: Text(
                            'Tap to view profile',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PublicAuraScreen(userId: user['id']),
                              ),
                            ).then((_) => _loadBlockedUsers());
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView( // Wrap in ListView to allow pull-to-refresh on empty state
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 80, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text(
              'No blocked profiles',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white60),
            ),
            const SizedBox(height: 8),
            Text(
              'Users you block will appear here.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white38),
            ),
          ],
        ),
      ],
    );
  }
}
