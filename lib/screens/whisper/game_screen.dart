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
  
  // Truth or Dare specific state
  Map<String, dynamic> _gameState = {
    'askerId': '', // who is answering the question
    'phase': 'selecting_category', // selecting_category, selecting_question, answering
    'category': '', // truth or dare
    'question': '',
    'myPoints': 0,
    'peerPoints': 0,
    'history': [], // [{senderName, text, type, messageType}]
    'suggestedQuestions': [],
  };
  
  int _responseTimerSeconds = 60;
  Timer? _responseTimer;
  String? _currentUserId;
  String? _currentUserName;

  // Messaging state
  final TextEditingController _msgController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _currentRecordingPath;

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
    _loadMessages();
    
    if (widget.viewOnly) {
      _isWaiting = false;
      _initGameListeners();
    } else {
      _isWaiting = widget.isInviter;
      if (widget.isInviter) {
        _initInviteSentListener();
        _initResponseListener();
        _checkInitialStatus();
      } else {
        _startGameDurationTimer();
        _initGameListeners();
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final res = await ApiService.getMessages(widget.channelId);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _messages = data.map((m) => Map<String, dynamic>.from(m)).toList();
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('Error loading messages: $e');
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
      if (mounted && data['sessionId'] == _currentSessionId) {
        setState(() {
          _gameState = Map<String, dynamic>.from(data['state']);
        });
      }
    });

    SocketService().newMessageStream.listen((msg) {
      if (mounted && msg['channel_id'] == widget.channelId) {
        setState(() {
          _messages.add(msg);
        });
        _scrollToBottom();
      }
    });

    _pointsSub = SocketService().gamePointsStream.listen((data) {
      if (mounted && data['sessionId'] == _currentSessionId) {
        setState(() {
          if (data['userId'].toString() == _currentUserId.toString()) {
            _gameState['myPoints'] = data['points'];
          } else {
            _gameState['peerPoints'] = data['points'];
          }
        });
      }
    });
  }

  // --- Actions ---
  void _onCategorySelected(String choice) {
    SocketService().emitSelectChoice(_currentSessionId!, choice, widget.peerId);
  }

  void _onQuestionSelected(String question) {
    SocketService().emitSendQuestion(_currentSessionId!, question, widget.peerId);
  }

  Future<void> _sendTextAnswer() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
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
            _initGameListeners();
          }
        }
      }
    } catch (e) {
      print('Error checking initial status: $e');
    }
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
      if (mounted && data['sessionId'] == _currentSessionId) {
        if (data['accepted'] == true) {
          setState(() => _isWaiting = false);
          _startGameDurationTimer();
          _initGameListeners();
        } else {
          Navigator.pop(context);
        }
      }
    });
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
    return Column(
      children: [
        _buildHeader(),
        _buildScoreBoard(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: _messages.length,
            itemBuilder: (context, index) => _buildChatMessage(_messages[index]),
          ),
        ),
        _buildActionArea(),
      ],
    );
  }

  Widget _buildChatMessage(Map<String, dynamic> msg) {
    final bool isMe = msg['sender_id'].toString() == _currentUserId;
    final String type = msg['message_type'];
    
    if (type == 'game_status') {
      try {
        final content = jsonDecode(msg['content']);
        if (content['text'] != null) {
          return Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
              child: Text(content['text'], style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
            ),
          );
        }
      } catch (_) {}
      return const SizedBox.shrink();
    }

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
          ? _buildVoiceBubble(msg['content']) 
          : Text(msg['content'], style: GoogleFonts.inter(color: Colors.white)),
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
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _confirmExit),
          Text(widget.gameName.toUpperCase(), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 3, color: AppColors.primary)),
          _buildTimerIcon(),
        ],
      ),
    );
  }

  Widget _buildTimerIcon() {
    if (_gameState['phase'] != 'answering') return const SizedBox(width: 48);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.redAccent, size: 14),
          const SizedBox(width: 4),
          Text('$_responseTimerSeconds', style: GoogleFonts.jetBrainsMono(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildScoreBoard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPlayerScore('YOU', _gameState['myPoints']),
          Container(height: 20, width: 1, color: Colors.white10),
          _buildPlayerScore(widget.peerName, _gameState['peerPoints']),
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
    final bool isMyTurn = currentTurn == _currentUserId;

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
        const SizedBox(height: 32),
        Text("Your Turn to Choose!", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildCategoryButton('TRUTH', Icons.help_outline, const Color(0xFF4CAF50), () => _onCategorySelected('truth'))),
            const SizedBox(width: 16),
            Expanded(child: _buildCategoryButton('DARE', Icons.flash_on, const Color(0xFFFF9800), () => _onCategorySelected('dare'))),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPicker() {
    final List suggested = _gameState['suggestedQuestions'] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text("Pick a Question for ${widget.peerName}", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        ...suggested.map((q) => GestureDetector(
          onTap: () => _onQuestionSelected(q),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: Text(q, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
          ),
        )),
        const SizedBox(height: 12),
        _buildCustomQuestionInput(),
      ],
    );
  }

  Widget _buildCustomQuestionInput() {
    final controller = TextEditingController();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(hintText: "Or type your own question...", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
            ),
          ),
          IconButton(icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 20), onPressed: () {
            if (controller.text.trim().isNotEmpty) _onQuestionSelected(controller.text.trim());
          }),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
          child: Text(_gameState['question'] ?? "Answer the question!", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
        ),
        const SizedBox(height: 24),
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
      if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 50);
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
