import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/socket_service.dart';
import '../screens/whisper/game_screen.dart';
import '../main.dart';

class GameInviteGlobalWrapper extends StatefulWidget {
  final Widget child;
  const GameInviteGlobalWrapper({super.key, required this.child});

  @override
  State<GameInviteGlobalWrapper> createState() => _GameInviteGlobalWrapperState();
}

class _GameInviteGlobalWrapperState extends State<GameInviteGlobalWrapper> {
  StreamSubscription? _inviteSub;
  StreamSubscription? _missedSub;
  StreamSubscription? _responseSub;
  Map<String, dynamic>? _currentInvite;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();

    _inviteSub = SocketService().gameInviteStream.listen((data) {
      if (!mounted) return;
      final fromId = data['fromId']?.toString() ?? '';
      // If the ChatScreen with this peer is currently open, let it handle the invite
      if (fromId == SocketService().activeChatPeerId) return;

      _autoDismissTimer?.cancel();
      setState(() => _currentInvite = data);

      _autoDismissTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => _currentInvite = null);
      });
    });

    // Auto-dismiss banner if the invite was missed/expired
    _missedSub = SocketService().gameMissedStream.listen((data) {
      if (mounted && _currentInvite != null &&
          _currentInvite!['sessionId'] == data['sessionId']) {
        setState(() => _currentInvite = null);
      }
    });

    // Auto-dismiss banner when the invite is already handled (e.g., via ChatScreen bottom sheet)
    _responseSub = SocketService().gameInviteResponseStream.listen((data) {
      if (mounted && _currentInvite != null &&
          data['sessionId'] == _currentInvite!['sessionId']) {
        setState(() => _currentInvite = null);
      }
    });
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    _missedSub?.cancel();
    _responseSub?.cancel();
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _handleResponse(bool accepted) {
    if (_currentInvite == null) return;
    final invite = _currentInvite!;
    setState(() => _currentInvite = null);
    _autoDismissTimer?.cancel();

    SocketService().emitGameInviteResponse(
      invite['channelId'],
      invite['fromId'],
      invite['gameId'],
      invite['gameName'],
      invite['sessionId'],
      accepted,
    );

    if (accepted) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            gameId: invite['gameId'],
            gameName: invite['gameName'],
            peerId: invite['fromId'],
            peerName: invite['fromName'] ?? 'Partner',
            isInviter: false,
            channelId: invite['channelId'],
            sessionId: invite['sessionId'],
          ),
        ),
      );
    }
    // If declined, the GameScreen on the inviter side auto-closes via _initResponseListener
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(child: widget.child),
        if (_currentInvite != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: AnimatedSlide(
                offset: Offset.zero,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: _buildInviteCard(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInviteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0033), Color(0xFF0D001A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text('🎲', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Game Challenge!',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                    Text(
                      '${_currentInvite!['fromName'] ?? 'Someone'} wants to play ${_currentInvite!['gameName']}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _handleResponse(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Not Now',
                      style: GoogleFonts.inter(color: Colors.white38, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleResponse(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Let's Play!",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
