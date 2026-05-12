import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';
import '../../theme/app_colors.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  StreamSubscription? _stateSub;
  StreamSubscription? _pointsSub;
  StreamSubscription? _endSub;
  String? _currentSessionId;
  int _gameDuration = 0;
  Timer? _durationTimer;
  
  // Truth or Dare state — starts empty, populated from API after game starts
  Map<String, dynamic> _gameState = {};
  
  int _responseTimerSeconds = 60;
  Timer? _responseTimer;
  String? _currentUserId;
  String? _currentUserName;

  // Messaging state
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _customQuestionController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _currentRecordingPath;
  bool _isActionLoading = false;

  final List<String> _truthQuestions = [
    "Tell me about your most unforgettable crush.",
    "Describe your ideal partner using only your voice.",
    "What’s something you’ve always wanted to confess to someone?",
    "Tell the story of your most awkward date.",
    "What’s one thing that instantly makes you fall for someone?",
    "Describe your perfect kiss in detail.",
    "What’s your biggest relationship fear?",
    "Tell me the sweetest compliment you’ve ever received.",
    "What’s one thing you secretly find attractive?",
    "Explain your biggest green flag in a relationship.",
    "What’s your most embarrassing texting mistake?",
    "Tell me about a moment that made your heart race.",
    "What’s something romantic you’ve never tried but want to?",
    "Describe your dream date from start to finish.",
    "What’s one memory you wish you could relive?",
    "What’s your biggest turn-on emotionally?",
    "Tell me about your first heartbreak.",
    "What’s the cutest thing someone has done for you?",
    "What’s your guilty pleasure when nobody’s watching?",
    "Describe your “perfect night together.”",
    "What’s one thing you wish people understood about you?",
    "What’s the boldest thing you’ve ever done for love?",
    "Tell me your funniest relationship story.",
    "What’s something you notice first about a person?",
    "If you had to flirt with me right now, what would you say?"
  ];

  final List<String> _dareQuestions = [
    "Send a voice note saying your best pickup line.",
    "Describe me in the flirtiest way possible.",
    "Send a dramatic “I miss you” voice message.",
    "Tell a cheesy joke and try not to laugh.",
    "Say my name in the sweetest voice you can.",
    "Pretend we’re on our first date and introduce yourself.",
    "Record yourself singing one romantic line from any song.",
    "Send a text confession like we’re in a movie scene.",
    "Try to make me blush using only your voice.",
    "Send your most-used emoji and explain why.",
    "Tell me a fake love story about us in 30 seconds.",
    "Describe your perfect cuddle session.",
    "Give me a nickname and explain it dramatically.",
    "Pretend you’re jealous and send a playful voice note.",
    "Roast yourself in the funniest way possible.",
    "Send a voice note with your “radio host” flirting voice.",
    "Tell me your best “good morning” message.",
    "Describe your current mood like a romance narrator.",
    "Send a fake proposal speech.",
    "Explain why you’d survive in a dating reality show.",
    "Flirt using only three words.",
    "Pretend you’re confessing your love in the rain.",
    "Say something cute without using the words “cute” or “love.”",
    "Tell me the most random thought in your head right now.",
    "End this dare with your smoothest goodbye message."
  ];

  List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.sessionId;
    _fetchCurrentUser();

    // Initialize game listeners early to catch events
    _initGameListeners();

    if (widget.viewOnly) {
      // View-only: just load the history, no live socket listeners
      _isWaiting = false;
      _loadGameState();
    } else if (widget.isInviter) {
      _isWaiting = true;
      _initInviteSentListener();
      _initResponseListener();
      // Recover sessionId in case game_invite_sent was missed
      _fetchPendingSession();
    } else {
      // Receiver: not waiting, load state immediately
      _isWaiting = false;
      _startGameDurationTimer();
      _loadGameState();
      // Also listen for game end by inviter
      _endSub = SocketService().gameEndStream.listen((data) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  /// Recover the sessionId from the API for User A (inviter) in case
  /// the game_invite_sent socket event was missed before GameScreen mounted.
  Future<void> _fetchPendingSession() async {
    if (_currentSessionId != null && _currentSessionId!.isNotEmpty) return;
    try {
      final res = await ApiService.getGameStatus(widget.channelId);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final sid = body['sessionId']?.toString();
        if (sid != null && sid.isNotEmpty && mounted) {
          setState(() => _currentSessionId = sid);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadGameState() async {
    if (_currentSessionId == null) return;
    print('[GameScreen] Loading game state for session: $_currentSessionId');
    try {
      final res = await ApiService.getGameSession(_currentSessionId!);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final session = body['session'];
        if (mounted && session != null) {
          final newState = Map<String, dynamic>.from(session['state'] ?? {});
          print('[GameScreen] Loaded state: $newState');
          setState(() {
            _gameState = newState;
            if (_gameState['myPoints'] == null) _gameState['myPoints'] = 0;
            if (_gameState['peerPoints'] == null) _gameState['peerPoints'] = 0;
            
            // If we have a phase, we are definitely not waiting
            if (_gameState.containsKey('phase')) {
              _isWaiting = false;
            }
          });
        }
      } else {
        print('[GameScreen] Error response: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('[GameScreen] Error loading game state: $e');
    }
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (_currentSessionId == null) return;
    try {
      final res = await ApiService.getGameMessages(_currentSessionId!);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> data = body['messages'] ?? [];
        if (mounted) {
          setState(() {
            _messages = data.map((m) => Map<String, dynamic>.from(m)).toList();
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('[GameScreen] Error loading messages: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  void _initGameListeners() {
    _stateSub = SocketService().gameStateStream.listen((data) {
      if (!mounted) return;
      final sid = data['sessionId']?.toString();
      final state = data['state'];
      print('[GameScreen] Received gameState update for $sid: $state');
      
      if (sid == null) return;
      
      // Capture sessionId if we were waiting for it
      if (_currentSessionId == null || _currentSessionId!.isEmpty) {
        setState(() => _currentSessionId = sid);
      } else if (sid != _currentSessionId) {
        print('[GameScreen] SID mismatch: $sid != $_currentSessionId');
        return; 
      }

      if (state != null) {
        setState(() {
          try {
            _gameState = Map<String, dynamic>.from(state as Map);
            // If we got state with a phase, we are no longer waiting
            if (_gameState.containsKey('phase')) {
              _isWaiting = false;
            }
          } catch (e) {
            print('[GameScreen] Error parsing state: $e');
          }
        });
        if (_gameState['phase'] == 'answering') _startTimerSync();
      }
    });

    SocketService().newGameMessageStream.listen((msg) {
      if (!mounted) return;
      final sid = msg['session_id']?.toString();
      if (sid != null && sid == _currentSessionId) {
        setState(() => _messages.add(Map<String, dynamic>.from(msg)));
        _scrollToBottom();
      }
    });

    _pointsSub = SocketService().gamePointsStream.listen((data) {
      if (!mounted) return;
      final sid = data['sessionId']?.toString();
      if (sid != null && sid == _currentSessionId) {
        setState(() {
          _gameState['scores'] = data['scores'];
        });
      }
    });

    _endSub = SocketService().gameEndStream.listen((data) {
      if (!mounted) return;
      final sid = data['sessionId']?.toString();
      final endedBy = data['userName']?.toString() ?? 'Peer';
      if (sid != null && sid == _currentSessionId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$endedBy ended the game session.', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    });
  }

  // --- Actions ---
  void _onCategorySelected(String choice) {
    if (_currentSessionId == null || _isActionLoading) return;
    setState(() => _isActionLoading = true);
    SocketService().emitGameSelectChoice(_currentSessionId!, choice, widget.peerId);
    // Auto-reset loading after 5s if no response
    Future.delayed(const Duration(seconds: 5), () {
       if (mounted) setState(() => _isActionLoading = false);
    });
  }

  void _onQuestionSelected(String question) {
    if (_currentSessionId == null || _isActionLoading) return;
    setState(() => _isActionLoading = true);
    SocketService().emitGameSendQuestion(_currentSessionId!, question, widget.peerId);
    Future.delayed(const Duration(seconds: 5), () {
       if (mounted) setState(() => _isActionLoading = false);
    });
  }

  Future<void> _sendTextAnswer() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _currentSessionId == null) return;
    
    _msgController.clear();
    SocketService().emitSubmitAnswer(_currentSessionId!, text, widget.peerId, 'text');
  }

  Future<void> _sendVoiceAnswer(String path) async {
    try {
      final res = await ApiService.uploadAudio(File(path));
      if (res.statusCode == 200) {
        final url = jsonDecode(res.body)['url'];
        SocketService().emitSubmitAnswer(_currentSessionId!, url, widget.peerId, 'voice');
      }
    } catch (e) {
      print('Error uploading voice: $e');
    }
  }

  Future<void> _fetchCurrentUser() async {
    final res = await ApiService.getMe();
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (mounted) {
        setState(() {
          _currentUserId = body['user']['id'].toString();
          _currentUserName = body['user']['display_name'];
        });
      }
    }
  }

  Future<void> _checkInitialStatus() async {
    try {
      final res = await ApiService.getGameStatus(widget.channelId);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['status'] == 'active' || body['status'] == 'accepted') {
          if (mounted) {
            setState(() {
              _isWaiting = false;
              _currentSessionId = body['sessionId'] ?? body['id']?.toString();
            });
            _startGameDurationTimer();
            _loadGameState();
            _initGameListeners();
          }
        }
      }
    } catch (e) {
      print('Error checking initial status: $e');
    }
  }

  void _startTimerSync() {
    _responseTimer?.cancel();
    _responseTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final endsAt = _gameState['timerEndsAt'];
      if (endsAt == null) {
        _responseTimer?.cancel();
        return;
      }
      try {
        final endDateTime = DateTime.parse(endsAt.toString());
        final remaining = endDateTime.difference(DateTime.now()).inSeconds;
        setState(() => _responseTimerSeconds = remaining.clamp(0, 90));
        if (remaining <= 0) _responseTimer?.cancel();
      } catch (e) {
        print('[GameScreen] Timer sync error: $e');
        _responseTimer?.cancel();
      }
    });
  }

  void _initInviteSentListener() {
    _inviteSentSub = SocketService().gameInviteSentStream.listen((data) {
      if (mounted && data['channelId'].toString() == widget.channelId.toString()) {
        setState(() => _currentSessionId = data['sessionId']);
      }
    });
  }

  void _initResponseListener() {
    _responseSub = SocketService().gameInviteResponseStream.listen((data) {
      if (!mounted) return;
      // Accept if sessionId matches, or as fallback if we haven't gotten sessionId yet
      final sid = data['sessionId']?.toString();
      final matchSid = _currentSessionId != null && sid == _currentSessionId;
      final noSid = _currentSessionId == null || _currentSessionId!.isEmpty;
      if (!matchSid && !noSid) return;

      if (data['accepted'] == true) {
        setState(() {
          _isWaiting = false;
          if (sid != null) _currentSessionId = sid;
        });
        _startGameDurationTimer();
        _loadGameState();
      } else {
        // Invitation rejected
        _showRejectionDialog();
      }
    });
  }

  void _showRejectionDialog() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.peerName} is not available right now.', 
          style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  void _startGameDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _gameDuration++);
    });
  }

  Widget _buildWaitingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Text('Waiting for ${widget.peerName}', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Text('Invitation sent for ${widget.gameName}', style: GoogleFonts.inter(color: Colors.white70)),
        const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: ElevatedButton(
            onPressed: () {
              SocketService().emitGameCancel(widget.channelId, widget.peerId, _currentSessionId ?? '');
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: Text('CANCEL', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ),
        if (_currentSessionId != null) 
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextButton.icon(
              onPressed: () {
                debugPrint('[GameScreen] Manual state reload triggered');
                _loadGameState();
              },
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              label: Text('TAP IF STUCK', style: GoogleFonts.outfit(color: AppColors.primary)),
            ),
          ),
      ],
    );
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
            colors: [Color(0xFF1A0033), Colors.black],
          ),
        ),
        child: SafeArea(
          child: _isWaiting ? _buildWaitingUI() : _buildGameRoomUI(),
        ),
      ),
    );
  }

  Widget _buildGameRoomUI() {
    final bool stateLoaded = _gameState.containsKey('phase');
    final bool isKeyboardUp = MediaQuery.of(context).viewInsets.bottom > 0;

    return Column(
      children: [
        _buildHeader(),
        // Hide scoreboard when keyboard is up to save space
        if (!widget.viewOnly && !isKeyboardUp) _buildScoreBoard(),
        
        if (widget.viewOnly)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history, color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Text('Game history — view only',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        if (!stateLoaded && !widget.viewOnly)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
        else
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text('No messages in this session.',
                        style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildChatMessage(_messages[index]),
                  ),
          ),
        if (!widget.viewOnly && stateLoaded) 
          Padding(
            padding: EdgeInsets.only(
              bottom: isKeyboardUp ? 10 : (MediaQuery.of(context).padding.bottom + 10),
              left: 16,
              right: 16,
            ),
            child: _buildActionArea(),
          ),
      ],
    );
  }

  Widget _buildChatMessage(Map<String, dynamic> msg) {
    final String type = (msg['message_type'] ?? 'text') as String;
    final String content = (msg['content'] ?? '') as String;

    // System messages — centered pill
    if (type == 'system') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(content, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
        ),
      );
    }

    // Question bubble — full-width card
    if (type == 'question') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.quiz_outlined, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(content, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontStyle: FontStyle.italic))),
          ],
        ),
      );
    }

    // Text / Voice answer bubbles
    final bool isMe = msg['sender_id']?.toString() == _currentUserId;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: type == 'voice'
            ? _buildVoiceBubble(content)
            : Text(content, style: GoogleFonts.inter(color: Colors.white)),
      ),
    );
  }

  Widget _buildVoiceBubble(String url) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          onPressed: () => _audioPlayer.play(UrlSource(url)),
        ),
        const Text('Voice Message', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            // viewOnly: close immediately — no confirmation needed
            onPressed: widget.viewOnly ? () => Navigator.pop(context) : _confirmExit,
          ),
          Column(
            children: [
              Text(widget.gameName.toUpperCase(), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 3, color: AppColors.primary)),
              if (widget.viewOnly)
                Text('HISTORY', style: GoogleFonts.inter(fontSize: 9, color: Colors.white38, letterSpacing: 2)),
            ],
          ),
          widget.viewOnly ? const SizedBox(width: 48) : _buildTimerIcon(),
        ],
      ),
    );
  }

  Widget _buildTimerIcon() {
    final endsAt = _gameState['timerEndsAt'];
    if (endsAt == null) return const SizedBox(width: 48);

    int secs = 0;
    try {
      final endDateTime = DateTime.parse(endsAt.toString());
      secs = endDateTime.difference(DateTime.now()).inSeconds.clamp(0, 120);
    } catch (e) {
      print('[GameScreen] Timer parse error: $e');
      return const SizedBox(width: 48);
    }

    final color = secs < 10 ? Colors.redAccent : (secs < 30 ? Colors.orangeAccent : Colors.white70);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: color, size: 14),
          const SizedBox(width: 4),
          Text('$secs', style: GoogleFonts.jetBrainsMono(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildScoreBoard() {
    final scores = (_gameState['scores'] as Map?);
    final myScore  = (scores?[_currentUserId ?? ''] ?? 0) as num;
    final peerScore = (scores?[widget.peerId] ?? 0) as num;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPlayerScore('YOU', myScore.toInt()),
          Container(height: 20, width: 1, color: Colors.white10),
          _buildPlayerScore(widget.peerName, peerScore.toInt()),
        ],
      ),
    );
  }

  Widget _buildPlayerScore(String name, int score) {
    return Column(
      children: [
        Text(name.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Text('$score', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildActionArea() {
    final phase = _gameState['phase'] ?? 'selecting_category';
    final currentTurn = _gameState['currentTurn']?.toString();
    final bool isMyTurn = currentTurn != null && currentTurn == _currentUserId;

    if (!isMyTurn) {
      return _buildWaitingForPeer();
    }

    switch (phase) {
      case 'selecting_category':
        return _buildCategorySelection();
      case 'selecting_question':
        return _buildQuestionPicker();
      case 'answering':
        return _buildChatInput();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCategorySelection() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text("Your Turn to Choose!", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildCategoryButton('TRUTH', Icons.help_outline, const Color(0xFF4CAF50), () => _onCategorySelected('truth'))),
            const SizedBox(width: 12),
            Expanded(child: _buildCategoryButton('DARE', Icons.flash_on, const Color(0xFFFF9800), () => _onCategorySelected('dare'))),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: _isActionLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 85, // Reduced from 110
        decoration: BoxDecoration(
          color: color.withOpacity(0.08), 
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: color.withOpacity(0.2), width: 1.2)
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isActionLoading)
              const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
            else ...[
              Icon(icon, color: color, size: 24), // Reduced from 30
              const SizedBox(height: 6),
              Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.2)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPicker() {
    final List suggested = (_gameState['suggestedQuestions'] as List?) ?? [];
    final category = (_gameState['category'] ?? 'truth') as String;
    final local = category == 'dare' ? _dareQuestions : _truthQuestions;
    final display = suggested.isNotEmpty ? suggested : local.take(5).toList();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text("Pick a Question for ${widget.peerName}",
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          // Constrain the suggested questions list height
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.25),
            child: SingleChildScrollView(
              child: Column(
                children: display.map((q) => GestureDetector(
                  onTap: () => _onQuestionSelected(q.toString()),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06))),
                    child: Text(q.toString(), style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                  ),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildCustomQuestionInput(),
        ],
      ),
    );
  }

  Widget _buildCustomQuestionInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08), // Brighter background
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.2) // Brighter border
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _customQuestionController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: "Or type your own question...", 
                hintStyle: TextStyle(color: Colors.white38), // Brighter hint
                border: InputBorder.none
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 22), 
            onPressed: () {
              final text = _customQuestionController.text.trim();
              if (text.isNotEmpty) {
                _onQuestionSelected(text);
                _customQuestionController.clear();
              }
            }
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08), 
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: AppColors.primary.withOpacity(0.15))
          ),
          child: Text(_gameState['question'] ?? "Answer the question!", 
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), 
            textAlign: TextAlign.center),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _msgController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: "Type your response...", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onLongPress: _startRecording,
              onLongPressUp: _stopRecording,
              onTap: _sendTextAnswer,
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _isRecording ? Colors.redAccent : AppColors.primary),
                child: Icon(_isRecording ? Icons.mic : Icons.send, color: Colors.black),
              ),
            ),
          ],
        ),
        if (_isRecording) Padding(padding: const EdgeInsets.only(top: 8), child: Text("Recording...", style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/game_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() {
        _isRecording = true;
        _currentRecordingPath = path;
      });
      if ((await Vibration.hasVibrator()) == true) Vibration.vibrate(duration: 50);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });
    if (path != null) {
      _sendVoiceAnswer(path);
    }
  }

  Widget _buildWaitingForPeer() {
    String msg = "Waiting for ${widget.peerName}...";
    final phase = _gameState['phase'];
    if (phase == 'selecting_category') msg = "${widget.peerName} is choosing Truth or Dare...";
    if (phase == 'selecting_question') msg = "${widget.peerName} is picking a question for you...";
    if (phase == 'answering') msg = "${widget.peerName} is typing/recording...";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            const SizedBox(height: 24),
            Text(msg, style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.obsidianEdge,
        title: Text('End Game?', style: GoogleFonts.outfit(color: Colors.white)),
        content: Text('Are you sure you want to end this game session?', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.inter(color: Colors.white38))),
          TextButton(
            onPressed: () {
              SocketService().emitGameEnd(widget.channelId, widget.peerId, _currentSessionId!);
              Navigator.pop(context); 
              Navigator.pop(context); 
            },
            child: Text('END GAME', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _msgController.dispose();
    _customQuestionController.dispose();
    _responseSub?.cancel();
    _inviteSentSub?.cancel();
    _stateSub?.cancel();
    _pointsSub?.cancel();
    _endSub?.cancel();
    _durationTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
