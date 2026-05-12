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
  Map<String, dynamic>? _currentInvite;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _inviteSub = SocketService().gameInviteStream.listen((data) {
      if (mounted) {
        _autoDismissTimer?.cancel();
        setState(() {
          _currentInvite = data;
        });
        // Auto-dismiss after 30 seconds
        _autoDismissTimer = Timer(const Duration(seconds: 30), () {
          if (mounted) setState(() => _currentInvite = null);
        });
      }
    });

    _missedSub = SocketService().gameMissedStream.listen((data) {
      if (mounted && _currentInvite != null && _currentInvite!['sessionId'] == data['sessionId']) {
        setState(() => _currentInvite = null);
      }
    });
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    _missedSub?.cancel();
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _handleResponse(bool accepted) {
    if (_currentInvite == null) return;
    
    final invite = _currentInvite!;
    SocketService().emitGameInviteResponse(
      invite['channelId'],
      invite['fromId'],
      invite['gameId'],
      invite['gameName'],
      invite['sessionId'],
      accepted,
    );

    if (accepted) {
      // Navigate to GameScreen
      // Since we are in the global builder, we might need a navigator key or use the context from child
      // But for now, let's just use the current context if possible
      // Navigate to GameScreen using global navigatorKey
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

    setState(() => _currentInvite = null);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(child: widget.child),
        if (_currentInvite != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: AnimatedSlide(
                offset: _currentInvite != null ? Offset.zero : const Offset(0, -1),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _currentInvite != null ? 1.0 : 0.0,
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
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10)),
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
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videogame_asset, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Game Invite!',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    Text(
                      'Play ${_currentInvite!['gameName']} with ${_currentInvite!['fromName'] ?? 'Partner'}?',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _handleResponse(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Not Now', style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleResponse(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Yes, I'm In", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
