import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../../../services/socket_service.dart';
import '../../premium/subscription_screen.dart';
import '../game_screen.dart';

class GameDrawer extends StatefulWidget {
  final int channelId;
  final String peerId;
  final String peerName;
  final VoidCallback? onReturnFromGame;
  
  const GameDrawer({
    super.key, 
    required this.channelId,
    required this.peerId,
    required this.peerName,
    this.onReturnFromGame,
  });

  @override
  State<GameDrawer> createState() => _GameDrawerState();
}

class _GameDrawerState extends State<GameDrawer> {
  List<dynamic> _games = [];
  int _messageCount = 0;
  bool _isLoading = true;
  bool _isPremium = false;
  bool _isInviting = false;
  StreamSubscription? _inviteResponseSub;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _inviteResponseSub?.cancel();
    super.dispose();
  }

  void _navigateToGame(String gameId, String gameName, String sessionId) {
    // Close the bottom sheet first
    Navigator.pop(context);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          gameId: gameId,
          gameName: gameName,
          peerId: widget.peerId,
          peerName: widget.peerName,
          isInviter: true,
          channelId: widget.channelId,
          sessionId: sessionId,
        ),
      ),
    ).then((_) {
      if (widget.onReturnFromGame != null) {
        widget.onReturnFromGame!();
      }
    });
  }

  void _showCustomToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fetchData() async {
    try {
      final gamesRes = await ApiService.getGames();
      final statusRes = await ApiService.getGameStatus(widget.channelId);
      final meRes = await ApiService.getMe();

      if (gamesRes.statusCode == 200 && statusRes.statusCode == 200) {
        final gamesData = jsonDecode(gamesRes.body);
        final statusData = jsonDecode(statusRes.body);
        
        bool isPremium = false;
        if (meRes.statusCode == 200) {
          isPremium = jsonDecode(meRes.body)['user']['is_premium'] ?? false;
        }

        if (mounted) {
          setState(() {
            _games = gamesData['games'] ?? [];
            _messageCount = statusData['messageCount'] ?? 0;
            _isPremium = isPremium;
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
    final topPadding = MediaQuery.of(context).padding.top;
    final appBarHeight = kToolbarHeight + topPadding;
    final sheetHeight = MediaQuery.of(context).size.height - appBarHeight;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF6A1B9A),
            Colors.black,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/icon-game.jpg',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Rizz Room',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          if (!_isLoading && !_isPremium && _games.any((g) => g['is_premium'] == true))
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                ).then((_) => _fetchData());
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)], // Premium purple/indigo
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Unlock Premium Games with RIZZ+',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? _buildShimmer()
                : _games.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _games.length,
                        itemBuilder: (context, index) {
                          final game = _games[index];
                          return _buildGameCard(game);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No games available yet.',
        style: GoogleFonts.inter(color: Colors.white38),
      ),
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    final int required = game['min_messages_required'] ?? 200;
    final double progress = (_messageCount / required).clamp(0.0, 1.0);
    final bool isUnlockedByMessages = _messageCount >= required;
    final bool isPremiumGame = game['is_premium'] == true;
    final bool isPremiumLocked = isPremiumGame && !_isPremium;
    final bool isPlayable = isUnlockedByMessages && !isPremiumLocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isPremiumGame 
                            ? const Color(0xFF8B5CF6).withOpacity(0.15)
                            : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: isPremiumGame 
                            ? Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3))
                            : null,
                      ),
                      child: Text(
                        game['icon'] ?? '🎲',
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    if (isPremiumGame)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: const Icon(Icons.star, color: Colors.white, size: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game['name'] ?? 'Unknown Game',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        game['description'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.onSurface.withOpacity(0.5),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isUnlockedByMessages && !isPremiumLocked) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Unlock Progress',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                      ),
                      Text(
                        '$_messageCount / $required',
                        style: GoogleFonts.inter(
                          fontSize: 12, 
                          color: isUnlockedByMessages ? AppColors.primary : Colors.white38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isUnlockedByMessages ? AppColors.primary : AppColors.primary.withOpacity(0.3),
                      ),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: () {
                if (isPremiumLocked) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                  ).then((_) => _fetchData());
                } else if (isPlayable && !_isInviting) {
                  SocketService().emitGameInvite(
                    widget.channelId,
                    widget.peerId,
                    game['id'],
                    game['name'] ?? 'Game',
                  );
                  _navigateToGame(game['id'], game['name'] ?? 'Game', ''); // Empty string for now
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: isPremiumLocked
                      ? const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                        )
                      : (isPlayable
                          ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryContainer])
                          : null),
                  color: (isPlayable || isPremiumLocked) ? null : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isPremiumLocked
                      ? [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    isPremiumLocked 
                        ? 'GET RIZZ+' 
                        : (_isInviting ? 'WAITING...' : (isPlayable ? 'PLAY NOW' : 'LOCKED')),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: (isPlayable || isPremiumLocked) && !_isInviting ? Colors.white : Colors.white24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isPlayable)
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: Center(
                child: Text(
                  'Daily plays: ${game['daily_free_plays']} free left',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
