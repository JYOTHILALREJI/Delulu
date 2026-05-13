import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../aura/public_aura_screen.dart';
import '../aura/aura_screen.dart';
import '../../components/delulu_wavy_loader.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> _leaderboard = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _fetchLeaderboard(),
      _fetchMe(),
    ]);
  }

  Future<void> _fetchMe() async {
    try {
      final res = await ApiService.getMe();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (mounted) {
          setState(() => _currentUserId = body['user']['id'].toString());
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final res = await ApiService.getLeaderboard();
      if (res.statusCode == 200) {
        final body = await compute<String, dynamic>(jsonDecode, res.body);
        if (mounted) {
          setState(() {
            _leaderboard = body['leaderboard'] ?? [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Popular Delulus',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: DeluluWavyLoader(fontSize: 20))
          : _leaderboard.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_outlined, size: 64, color: Colors.white10),
                      const SizedBox(height: 16),
                      Text(
                        'No rankings yet.\nBe the first to reach the top!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchLeaderboard,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _leaderboard.length,
                    itemBuilder: (context, index) {
                      final user = _leaderboard[index];
                      return _buildLeaderboardItem(user, index);
                    },
                  ),
                ),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> user, int index) {
    final photosData = user['photos'];
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
    final String? imageUrl = primaryPhoto?['url'];
    final bool isTop3 = index < 3;
    
    Color rankColor = Colors.white24;
    if (index == 0) rankColor = const Color(0xFFFFD700); // Gold
    else if (index == 1) rankColor = const Color(0xFFC0C0C0); // Silver
    else if (index == 2) rankColor = const Color(0xFFCD7F32); // Bronze

    final bool isMe = user['id']?.toString() == _currentUserId;

    return GestureDetector(
      onTap: () {
        if (isMe) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AuraScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PublicAuraScreen(userId: user['id'].toString())),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isTop3 
              ? rankColor.withOpacity(0.05) 
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTop3 ? rankColor.withOpacity(0.3) : Colors.white.withOpacity(0.05),
            width: isTop3 ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.outfit(
                    fontSize: isTop3 ? 24 : 18,
                    fontWeight: FontWeight.bold,
                    color: rankColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceContainerHighest,
                image: imageUrl != null
                    ? (imageUrl.startsWith('data:image')
                        ? DecorationImage(
                            image: MemoryImage(base64Decode(imageUrl.split(',').last)),
                            fit: BoxFit.cover,
                          )
                        : DecorationImage(
                            image: CachedNetworkImageProvider(imageUrl),
                            fit: BoxFit.cover,
                          ))
                    : null,
              ),
              child: imageUrl == null
                  ? const Icon(Icons.person, color: Colors.white24, size: 28)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${user['display_name'] ?? 'Unknown'}${isMe ? ' (You)' : ''}',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                            color: isMe ? AppColors.primary : AppColors.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user['is_verified'] == true) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: AppColors.secondaryContainer, size: 16),
                      ],
                      if (user['is_premium_user'] == true) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.workspace_premium, size: 10, color: Colors.black),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 14, color: AppColors.tertiary.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        '${user['likes_count'] ?? 0} likes',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.local_fire_department, size: 14, color: Colors.orange.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        '${user['streak_count'] ?? 0} streak',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isTop3)
              Icon(Icons.emoji_events, color: rankColor, size: 24),
          ],
        ),
      ),
    );
  }
}
