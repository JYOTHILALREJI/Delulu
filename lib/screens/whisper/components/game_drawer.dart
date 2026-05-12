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
  final int initialMessageCount;
  /// Whether the peer is currently online. If false, invites are blocked.
  final bool isPeerOnline;

  const GameDrawer({
    super.key,
    required this.channelId,
    required this.peerId,
    required this.peerName,
    this.onReturnFromGame,
    this.initialMessageCount = 0,
    this.isPeerOnline = false,
  });

  @override
  State<GameDrawer> createState() => _GameDrawerState();
}

class _GameDrawerState extends State<GameDrawer> {
  List<dynamic> _games = [];
  int _messageCount = 0;
  bool _isLoading = false;
  bool _isPremium = false;
  bool _isInviting = false;
  // Tracks how many times user played each game today: { gameId: count }
  Map<String, int> _todayPlays = {};
  StreamSubscription? _inviteResponseSub;

  @override
  void initState() {
    super.initState();
    _messageCount = widget.initialMessageCount;
    _games = [_truthOrDareFallback()];
    _isLoading = false;
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
      final results = await Future.wait([
        ApiService.getGames(),
        ApiService.getGameStatus(widget.channelId),
        ApiService.getMe(),
      ]);

      final gamesRes = results[0];
      final statusRes = results[1];
      final meRes = results[2];

      List<dynamic> fetchedGames = [];
      int messageCount = _messageCount;
      bool isPremium = false;

      if (gamesRes.statusCode == 200) {
        fetchedGames = (jsonDecode(gamesRes.body)['games'] as List<dynamic>?) ?? [];
      }

      if (statusRes.statusCode == 200) {
        final data = jsonDecode(statusRes.body);
        final raw = data['messageCount'];
        messageCount = raw is int ? raw : (int.tryParse(raw?.toString() ?? '0') ?? 0);
      }

      if (meRes.statusCode == 200) {
        final data = jsonDecode(meRes.body);
        isPremium = data['user']?['is_premium'] == true;
      }

      // Show ALL active games from the API
      List<dynamic> filteredGames = List<dynamic>.from(fetchedGames);

      // Always ensure Truth or Dare is present (prepend if missing)
      if (filteredGames.every((g) => g['id']?.toString().toLowerCase() != 'truth_or_dare')) {
        filteredGames.insert(0, _truthOrDareFallback());
      }

      // Fetch today play counts for all games in parallel
      final Map<String, int> todayPlays = {};
      await Future.wait(filteredGames.map((g) async {
        final gameId = g['id']?.toString() ?? '';
        if (gameId.isEmpty) return;
        try {
          final res = await ApiService.getGamePlaysToday(gameId);
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            todayPlays[gameId] = data['count'] as int? ?? 0;
          }
        } catch (_) {}
      }));

      if (mounted) {
        setState(() {
          _games = filteredGames;
          _messageCount = messageCount;
          _isPremium = isPremium;
          _todayPlays = todayPlays;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[GameDrawer] _fetchData error: $e');
      if (mounted) {
        setState(() {
          if (_games.isEmpty) _games = [_truthOrDareFallback()];
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _truthOrDareFallback() => {
    'id': 'truth_or_dare',
    'name': 'Truth or Dare',
    'icon': '🎲',
    'image_url': 'assets/game_icons/t_or_d_logo.png',
    'description': 'Spicy questions and dares for couples',
    'category': 'fun',
    'min_messages_required': 20,
    'daily_free_plays': 3,
    'unlimited_with_subscription': true,
    'is_premium': false,
    'active': true,
  };


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
    final String gameId = game['id']?.toString() ?? '';
    final int required = (game['min_messages_required'] is int)
        ? game['min_messages_required'] as int
        : (int.tryParse(game['min_messages_required']?.toString() ?? '') ?? 20);
    final int dailyFree = (game['daily_free_plays'] is int)
        ? game['daily_free_plays'] as int
        : (int.tryParse(game['daily_free_plays']?.toString() ?? '') ?? 3);
    final bool unlimitedWithSub = game['unlimited_with_subscription'] == true;
    final int playsToday = _todayPlays[gameId] ?? 0;
    final double progress = required > 0 ? (_messageCount / required).clamp(0.0, 1.0) : 1.0;
    final bool isUnlockedByMessages = _messageCount >= required;
    final bool isPremiumGame = game['is_premium'] == true;
    final bool isPremiumLocked = isPremiumGame && !_isPremium;
    // Non-premium can play free games up to their daily limit
    final bool hasFreePlaysLeft = !isPremiumGame && playsToday < dailyFree;
    // Premium users get unlimited plays (if unlimited_with_subscription)
    final bool hasPremiumPlays = _isPremium && unlimitedWithSub;
    final bool canPlay = isUnlockedByMessages && !isPremiumLocked && (hasFreePlaysLeft || hasPremiumPlays) && widget.isPeerOnline;
    final bool dailyLimitReached = isUnlockedByMessages && !isPremiumGame && !hasFreePlaysLeft && !hasPremiumPlays;
    // Image URL from DB — asset path or network
    final String? imageUrl = game['image_url']?.toString();
    final bool isAssetImage = imageUrl != null && imageUrl.startsWith('assets/');

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
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: isPremiumGame
                            ? const Color(0xFF8B5CF6).withOpacity(0.15)
                            : AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: isPremiumGame
                            ? Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3))
                            : Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: isAssetImage
                                  ? Image.asset(imageUrl, fit: BoxFit.cover)
                                  : Image.network(imageUrl, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(game['icon'] ?? '🎲',
                                            style: const TextStyle(fontSize: 32)),
                                      )),
                            )
                          : Center(
                              child: Text(
                                game['icon'] ?? '🎲',
                                style: const TextStyle(fontSize: 32),
                              ),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: InkWell(
              onTap: () async {
                if (isPremiumLocked) {
                  // Premium-only game — go to subscription
                  Navigator.pop(context);
                  Future.microtask(() => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                  ));
                } else if (!isUnlockedByMessages) {
                  // Not enough messages— progress bar is shown, do nothing
                  return;
                } else if (!widget.isPeerOnline) {
                  // Peer offline
                  return;
                } else if (dailyLimitReached) {
                  // Daily free limit hit — offer subscription
                  Navigator.pop(context);
                  Future.microtask(() => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                  ));
                } else if (canPlay && !_isInviting) {
                  // Record the play then send invite
                  ApiService.recordGamePlay(gameId, widget.channelId);
                  setState(() {
                    _todayPlays[gameId] = (_todayPlays[gameId] ?? 0) + 1;
                  });
                  SocketService().emitGameInvite(
                    widget.channelId,
                    widget.peerId,
                    gameId,
                    game['name'] ?? 'Game',
                  );
                  _navigateToGame(gameId, game['name'] ?? 'Game', '');
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: isPremiumLocked || dailyLimitReached
                      ? const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)])
                      : canPlay
                          ? const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryContainer])
                          : null,
                  color: (!canPlay && !isPremiumLocked && !dailyLimitReached)
                      ? Colors.white.withOpacity(0.05)
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: (isPremiumLocked || dailyLimitReached)
                      ? [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : canPlay
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isPremiumLocked || dailyLimitReached)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.star, color: Colors.white, size: 16),
                        ),
                      if (_isInviting)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                      Text(
                        isPremiumLocked
                            ? 'GET RIZZ+'
                            : _isInviting
                                ? 'SENDING...'
                                : dailyLimitReached
                                    ? 'GET RIZZ+ FOR UNLIMITED'
                                    : !widget.isPeerOnline
                                        ? 'OFFLINE — CAN\'T PLAY NOW'
                                        : canPlay
                                            ? 'SEND INVITE  •  ${dailyFree - playsToday}/${dailyFree} left'
                                            : !isUnlockedByMessages
                                                ? 'LOCKED'
                                                : 'LOCKED',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          fontSize: 13,
                          color: (canPlay || isPremiumLocked || dailyLimitReached) && !_isInviting
                              ? Colors.white
                              : Colors.white24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isUnlockedByMessages && !dailyLimitReached && !isPremiumLocked)
            Padding(
              padding: const EdgeInsets.only(bottom: 14, left: 16, right: 16),
              child: Center(
                child: Text(
                  _isPremium
                      ? 'Unlimited plays with RIZZ+ ★'
                      : '$playsToday of $dailyFree free plays used today',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                ),
              ),
            ),
          if (dailyLimitReached)
            Padding(
              padding: const EdgeInsets.only(bottom: 14, left: 16, right: 16),
              child: Center(
                child: Text(
                  'Daily limit reached — get RIZZ+ for unlimited',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8B5CF6).withOpacity(0.8)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
