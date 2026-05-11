import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/socket_service.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String gameName;
  final String peerId;
  final String peerName;
  final bool isInviter;
  final int channelId;
  final String? sessionId;
  final bool viewOnly;

  const GameScreen({
    super.key,
    required this.gameId,
    required this.gameName,
    required this.peerId,
    required this.peerName,
    required this.isInviter,
    required this.channelId,
    this.sessionId,
    this.viewOnly = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _isWaiting = true;
  StreamSubscription? _responseSub;
  StreamSubscription? _inviteSentSub;
  String? _currentSessionId;
  int _gameDuration = 0;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.sessionId;
    
    // Check if sessionId is already in socket service (race condition fix)
    final lastSent = SocketService().lastInviteSent;
    if (lastSent != null && 
        lastSent['channelId'].toString() == widget.channelId.toString() &&
        lastSent['peerId'].toString() == widget.peerId.toString()) {
      _currentSessionId = lastSent['sessionId'];
    }

    if (widget.viewOnly) {
      _isWaiting = false;
    } else {
      _isWaiting = widget.isInviter;
      if (widget.isInviter) {
        _initInviteSentListener();
        _initResponseListener();
      } else {
        _startGameDurationTimer();
      }
    }
  }

  void _initInviteSentListener() {
    _inviteSentSub = SocketService().gameInviteSentStream.listen((data) {
      if (mounted && 
          data['channelId'].toString() == widget.channelId.toString() && 
          data['peerId'].toString() == widget.peerId.toString()) {
        setState(() {
          _currentSessionId = data['sessionId'];
        });
      }
    });
  }

  void _startGameDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _gameDuration++);
    });
  }

  void _initResponseListener() {
    _responseSub = SocketService().gameInviteResponseStream.listen((data) {
      if (mounted && data['channelId'] == widget.channelId && data['fromId'] == widget.peerId) {
        if (data['accepted'] == true) {
          setState(() => _isWaiting = false);
          _startGameDurationTimer();
        } else {
          _showRejectionAndExit();
        }
      }
    });
  }

  void _showRejectionAndExit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.peerName} is not in the mood right now.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _responseSub?.cancel();
    _inviteSentSub?.cancel();
    _durationTimer?.cancel();
    _reportSessionEnd();
    super.dispose();
  }

  Future<void> _reportSessionEnd() async {
    if (_currentSessionId != null && _currentSessionId!.isNotEmpty && !_isWaiting && !widget.viewOnly) {
      SocketService().emitGameSessionUpdate(_currentSessionId!, _gameDuration);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A004E), Colors.black],
          ),
        ),
        child: SafeArea(
          child: _isWaiting ? _buildWaitingUI() : _buildGameUI(),
        ),
      ),
    );
  }

  Widget _buildWaitingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Text(
          'Waiting for ${widget.peerName}',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Invitation sent for ${widget.gameName}',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: ElevatedButton(
            onPressed: () {
              SocketService().emitGameCancel(
                widget.channelId, 
                widget.peerId, 
                _currentSessionId ?? ''
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white10,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('CANCEL', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildGameUI() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                widget.gameName.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 48), // Balance
            ],
          ),
        ),
        const Spacer(),
        _buildPlayerAvatars(),
        const SizedBox(height: 40),
        Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.viewOnly ? 'View Mode' : 'Game Started!',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.viewOnly 
                  ? 'Reviewing the game session with ${widget.peerName}.'
                  : 'Get ready to play with ${widget.peerName}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: widget.viewOnly ? null : () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.viewOnly ? Colors.white10 : AppColors.primary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  widget.viewOnly ? 'HISTORY VIEW' : 'ACTIONABLE BUTTON',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: widget.viewOnly ? Colors.white24 : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildPlayerAvatars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAvatar('YOU', AppColors.primary),
        const SizedBox(width: 40),
        Text(
          'VS',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white24,
          ),
        ),
        const SizedBox(width: 40),
        _buildAvatar(widget.peerName, AppColors.tertiary),
      ],
    );
  }

  Widget _buildAvatar(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 20),
            ],
          ),
          child: const Center(
            child: Icon(Icons.person, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label.split(',').first,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
