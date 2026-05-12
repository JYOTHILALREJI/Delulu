import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import 'chat_screen.dart';
import '../../../services/socket_service.dart';
import '../../components/delulu_wavy_loader.dart';

class WhispersScreen extends StatefulWidget {
  const WhispersScreen({super.key});

  @override
  State<WhispersScreen> createState() => WhispersScreenState();
}

class WhispersScreenState extends State<WhispersScreen> {
  List<Map<String, dynamic>> _connections = [];
  bool _isLoading = true;
  final Set<String> _onlineUsers = {};
  final Map<int, bool> _typingChannels = {};
  final Map<String, ImageProvider> _avatarCache = {};
  StreamSubscription? _statusSub;
  StreamSubscription? _typingSub;

  @override
  void initState() {
    super.initState();
    fetchConnections();
    _initSocket();
  }

  void _initSocket() {
    // Refresh list when a new message arrives or unread status changes
    SocketService().messageStream.listen((_) => fetchConnections());
    SocketService().unreadStream.listen((_) => fetchConnections());
    SocketService().readReceiptStream.listen((_) => fetchConnections());
    
    // Listen for online status updates
    _statusSub = SocketService().statusStream.listen((data) {
      if (mounted) {
        setState(() {
          if (data['status'] == 'online') {
            _onlineUsers.add(data['userId']);
          } else {
            _onlineUsers.remove(data['userId']);
          }
        });
      }
    });

    // Listen for typing status updates
    _typingSub = SocketService().typingStream.listen((data) {
      if (mounted) {
        setState(() {
          _typingChannels[data['channelId']] = data['isTyping'];
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _typingSub?.cancel();
    super.dispose();
  }

  Future<void> fetchConnections() async {
    try {
      final res = await ApiService.getConnections();
      final body = jsonDecode(res.body);
      if (mounted) {
        final List<dynamic> conns = body['connections'] ?? [];
        
        // Pre-cache avatars
        for (var conn in conns) {
          final profile = conn['profile'] as Map<String, dynamic>;
          final photos = List<Map<String, dynamic>>.from(profile['photos'] ?? []);
          final primaryPhoto = photos.isNotEmpty 
              ? photos.firstWhere((p) => p['is_primary'] == true, orElse: () => photos[0])
              : null;
          final avatarUrl = primaryPhoto?['url'] as String?;
          
          if (avatarUrl != null && !_avatarCache.containsKey(avatarUrl)) {
            if (avatarUrl.startsWith('data:image')) {
              _avatarCache[avatarUrl] = MemoryImage(base64Decode(avatarUrl.split(',').last));
            } else {
              _avatarCache[avatarUrl] = CachedNetworkImageProvider(avatarUrl);
            }
          }
        }

        setState(() {
          _connections = List<Map<String, dynamic>>.from(conns);
          _isLoading = false;
          // Initial online status sync
          for (var conn in _connections) {
            final profile = conn['profile'];
            if (profile != null && profile['is_online'] == true) {
              _onlineUsers.add(profile['id'].toString());
            }
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    final dt = DateTime.parse(isoTime);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header - Always show
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.mark_unread_chat_alt_outlined, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Whispers',
                  style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: DeluluWavyLoader())
                : _connections.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: fetchConnections,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                          itemCount: _connections.length,
                          itemBuilder: (context, index) {
                            final conn = _connections[index];
                            final profile = conn['profile'] as Map<String, dynamic>;
                            final photos = List<Map<String, dynamic>>.from(profile['photos'] ?? []);
                            final primaryPhoto = photos.isNotEmpty 
                                ? photos.firstWhere((p) => p['is_primary'] == true, orElse: () => photos[0])
                                : null;
                            final avatarUrl = primaryPhoto?['url'];
                            final lastMsg = conn['last_message'] as String?;
                            final lastTime = conn['last_message_time'] as String?;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 1),
                                color: Colors.white.withValues(alpha: 0.02),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                leading: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        width: 50, height: 50,
                                        color: AppColors.surfaceContainerHigh,
                                        child: avatarUrl != null && avatarUrl.isNotEmpty
                                            ? Image(image: _avatarCache[avatarUrl]!, fit: BoxFit.cover)
                                            : const Icon(Icons.person, color: AppColors.outlineVariant),
                                      ),
                                    ),
                                    if (_onlineUsers.contains(profile['id'].toString()))
                                      Positioned(
                                        right: 2,
                                        bottom: 2,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.black, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  '${profile['display_name']}, ${profile['age']}',
                                  style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                                ),
                                subtitle: _typingChannels[conn['channel_id']] == true
                                    ? Text(
                                        'Typing...',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : (lastMsg != null
                                        ? Text(
                                            lastMsg,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                                fontSize: 13, color: AppColors.onSurfaceVariant.withValues(alpha: 0.7)),
                                          )
                                        : null),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (lastTime != null)
                                      Text(
                                        _formatTime(lastTime),
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline.withValues(alpha: 0.6)),
                                      ),
                                    if ((conn['unread_count'] ?? 0) > 0) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          conn['unread_count'].toString(),
                                          style: GoogleFonts.inter(
                                              fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      channelId: conn['channel_id'],
                                      peerId: profile['id'].toString(),
                                      peerName: '${profile['display_name']}, ${profile['age']}',
                                      peerImageUrl: avatarUrl,
                                      lastSeen: profile['last_seen'],
                                      isOnline: _onlineUsers.contains(profile['id'].toString()),
                                    ),
                                  )).then((_) => fetchConnections()); // refresh on return
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mark_unread_chat_alt_outlined, size: 48,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No Whispers yet',
            style: GoogleFonts.beVietnamPro(fontSize: 16, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Make connections to start chatting!',
            style: GoogleFonts.beVietnamPro(fontSize: 14, color: AppColors.outline.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}