import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../../../services/socket_service.dart';
import '../../../components/delulu_chat_background.dart';
import 'package:vibration/vibration.dart';
import '../aura/public_aura_screen.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'components/game_drawer.dart';
import 'game_screen.dart';
import '../../utils/encryption_helper.dart';

Map<String, dynamic> _parseSingleMessage(Map<String, dynamic> msg) {
  if (msg['created_at'] != null) {
    try {
      final dt = DateTime.parse(msg['created_at']).toLocal();
      msg['_parsed_date'] = dt;
      msg['_formatted_time'] = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}
  }
  if (msg['message_type'] == 'game_status' && msg['content'] is String) {
    try {
      msg['_parsed_game_data'] = jsonDecode(msg['content']);
    } catch (_) {}
  }
  if (msg['content'] is String && EncryptionHelper.isEncrypted(msg['content'])) {
    msg['content'] = EncryptionHelper.decryptMessage(msg['content']);
  }
  return msg;
}

Map<String, dynamic> _processMessagesResponse(String responseBody) {
  final body = jsonDecode(responseBody) as Map<String, dynamic>;
  final messages = body['messages'] as List<dynamic>? ?? [];
  for (var i = 0; i < messages.length; i++) {
    messages[i] = _parseSingleMessage(messages[i] as Map<String, dynamic>);
  }
  return body;
}

class ChatScreen extends StatefulWidget {
  final int channelId;
  final String peerId;
  final String peerName;
  final String? peerImageUrl;
  final String? lastSeen;
  final bool isOnline;

  const ChatScreen({
    super.key,
    required this.channelId,
    required this.peerId,
    required this.peerName,
    this.peerImageUrl,
    this.lastSeen,
    this.isOnline = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;
  bool _isPeerOnline = false;
  bool _isPeerTyping = false;
  bool _isBlocked = false;
  bool _e2eEnabled = false;
  bool _typingIndicatorEnabled = true;
  Timer? _typingTimer;
  
  bool _isPremium = false;
  DateTime? _lastAttentionSeekerAt;
  bool _isAttentionCooldownActive = false;
  String _cooldownRemaining = "";
  Timer? _cooldownTimer;
  ImageProvider? _peerImageProvider;

  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isRecordingCancelled = false;
  bool _isRecordingLocked = false;
  String? _currentRecordingPath; // local recording path
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  Map<String, dynamic>? _replyingTo;
  final Map<int, GlobalKey> _messageKeys = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Duration _serverTimeOffset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _isPeerOnline = widget.isOnline;
    _initPeerImageProvider();
    _audioRecorder = AudioRecorder();
    
    // Load cached user ID and messages immediately for instant render
    _loadCachedData().then((_) {
      _fetchCurrentUser().then((_) => _loadMessages());
    });
    
    _fetchPeerProfile();
    _markRead();
    _initSocket();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedId = prefs.getString('current_user_id');
      if (cachedId != null) {
        _currentUserId = cachedId;
      }

      final cachedMsgs = prefs.getString('chat_messages_${widget.channelId}');
      if (cachedMsgs != null) {
        final body = await compute<String, dynamic>(_processMessagesResponse, cachedMsgs);
        if (mounted) {
          setState(() {
            _messages = List<Map<String, dynamic>>.from((body['messages'] ?? []).reversed);
            _isLoading = false;
          });
          _scrollToBottom(jump: true);
        }
      }
    } catch (_) {}
  }

  void _initPeerImageProvider() {
    if (widget.peerImageUrl != null && widget.peerImageUrl!.isNotEmpty) {
      if (widget.peerImageUrl!.startsWith('data:image')) {
        compute<String, Uint8List>(base64Decode, widget.peerImageUrl!.split(',').last).then((bytes) {
          if (mounted) setState(() => _peerImageProvider = MemoryImage(bytes));
        }).catchError((e) {
          debugPrint('Error decoding peer image: $e');
        });
      } else {
        _peerImageProvider = CachedNetworkImageProvider(widget.peerImageUrl!);
      }
    }
  }

  Future<void> _fetchPeerProfile() async {
    try {
      final res = await ApiService.getPublicProfile(widget.peerId);
      if (res.statusCode == 200) {
        final body = await compute<String, dynamic>(jsonDecode, res.body);
        if (mounted) {
          setState(() {
            _isBlocked = body['profile']?['is_blocked'] == true;
          });
        }
      }
    } catch (_) {}
  }

  void _initSocket() {
    // Listen for new messages
    SocketService().messageStream.listen((msg) {
      if (mounted && msg['channel_id'] == widget.channelId) {
        setState(() {
          final msgId = msg['id'] is int ? msg['id'] : (int.tryParse(msg['id']?.toString() ?? '') ?? 0);
          if (msgId > 0 && !_messages.any((m) => m['id'] == msgId)) {
            _messages.insert(0, _parseSingleMessage(Map<String, dynamic>.from(msg)));
            // Deduplicate immediately just in case
            final seen = <int>{};
            _messages.retainWhere((m) => seen.add(m['id'] as int));
          }
        });
        if (msg['sender_id'] != _currentUserId) {
          _markRead();
        }
      }
    });

    // Listen for read receipts - update in place, no full reload
    SocketService().readReceiptStream.listen((data) {
      if (mounted && data['channelId'] == widget.channelId) {
        setState(() {
          for (final m in _messages) {
            if (m['read_at'] == null && m['sender_id'].toString() == _currentUserId) {
              m['read_at'] = data['readAt'] ?? DateTime.now().toIso8601String();
            }
          }
        });
      }
    });

    // Listen for typing status
    SocketService().typingStream.listen((data) {
      if (mounted && data['channelId'] == widget.channelId) {
        setState(() {
          _isPeerTyping = data['isTyping'];
        });
      }
    });

    // Listen for online status
    SocketService().statusStream.listen((data) {
      if (mounted && data['userId'] == widget.peerId) {
        setState(() {
          _isPeerOnline = data['status'] == 'online';
        });
      }
    });

    // Listen for attention seeker
    SocketService().attentionStream.listen((data) {
      if (mounted) {
        _triggerVibration();
        _showCustomToast('${widget.peerName} is seeking your attention!', isError: true);
      }
    });

    // Listen for errors
    SocketService().errorStream.listen((data) {
      if (mounted) {
        if (data['type'] == 'attention_cooldown') {
          _showCustomToast(data['message'], isError: true);
        } else if (data['type'] == 'attention_premium_required') {
          _showCustomToast(data['message'], isError: true);
          setState(() => _isAttentionCooldownActive = true);
        } else {
          _showCustomToast(data['message'], isError: true);
        }
        _fetchCurrentUser(); // Refresh to get correct timestamp
      }
    });

    // Listen for game invitations
    SocketService().gameInviteStream.listen((data) {
      // Global wrapper handles this now
    });

    // Listen for game invitation responses (already handled in GameDrawer, but good for global state if needed)
    SocketService().gameInviteResponseStream.listen((data) {
      if (mounted && data['channelId'] == widget.channelId && data['fromId'] == widget.peerId) {
        if (data['accepted'] == true) {
          _navigateToGame(data['gameId'], data['gameName'] ?? 'Game', sessionId: data['sessionId']);
        }
      }
    });
  }

  void _navigateToGame(String gameId, String gameName, {String? sessionId, bool viewOnly = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          gameId: gameId,
          gameName: gameName,
          peerId: widget.peerId,
          peerName: widget.peerName,
          isInviter: false,
          channelId: widget.channelId,
          sessionId: sessionId,
          viewOnly: viewOnly,
        ),
      ),
    ).then((_) => _loadMessages());
  }

  void _showGameBottomSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GameDrawer(
        channelId: widget.channelId,
        peerId: widget.peerId,
        peerName: widget.peerName,
        onReturnFromGame: _loadMessages,
      ),
    );
  }

  void _triggerVibration() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      // 2s vibrate, 0.5s break, repeat 4 times for 10s total
      Vibration.vibrate(
        pattern: [500, 2000, 500, 2000, 500, 2000, 500, 2000],
        intensities: [0, 255, 0, 255, 0, 255, 0, 255],
      );
    }
  }

  void _showCustomToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatLastSeen(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  bool _wasEmpty = true;
  void _onTypingChanged() {
    if (!_typingIndicatorEnabled) return;
    
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    
    final isEmpty = _msgController.text.trim().isEmpty;
    if (isEmpty != _wasEmpty) {
      setState(() => _wasEmpty = isEmpty);
    }

    // Emit "typing" if text is not empty
    if (!isEmpty) {
      SocketService().emitTyping(widget.channelId, widget.peerId, true);
      
      _typingTimer = Timer(const Duration(seconds: 2), () {
        SocketService().emitTyping(widget.channelId, widget.peerId, false);
      });
    } else {
      SocketService().emitTyping(widget.channelId, widget.peerId, false);
    }
  }

  @override
  void dispose() {
    _msgController.removeListener(_onTypingChanged);
    _msgController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _cooldownTimer?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await ApiService.markAsRead(widget.channelId);
    } catch (_) {}
  }

  Future<void> _fetchCurrentUser() async {
    try {
      final res = await ApiService.getMe();
      if (res.statusCode == 200) {
        final body = await compute<String, dynamic>(jsonDecode, res.body);
        if (mounted) {
          setState(() {
            _currentUserId = body['user']['id'].toString();
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('current_user_id', _currentUserId!);
            });
            
            _isPremium = body['user']['is_premium'] == true;
            _e2eEnabled = body['user']['e2e_encryption_enabled'] ?? false;
            _typingIndicatorEnabled = body['user']['typing_indicator_enabled'] ?? true;
            
            // Calculate server time offset
            if (body['server_time'] != null) {
              final serverTime = DateTime.parse(body['server_time']);
              _serverTimeOffset = serverTime.difference(DateTime.now());
            }

            final lastAt = body['user']['last_attention_seeker_at'];
            if (lastAt != null) {
              _lastAttentionSeekerAt = DateTime.parse(lastAt);
              _startCooldownTimer();
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final res = await ApiService.getMessages(widget.channelId);
      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chat_messages_${widget.channelId}', res.body);
        
        final body = await compute<String, dynamic>(_processMessagesResponse, res.body);
        if (mounted) {
          setState(() {
            // Deduplicate and ensure DESC order (newest at index 0)
            final List<dynamic> raw = body['messages'] ?? [];
            final Map<int, Map<String, dynamic>> deduped = {};
            
            for (var m in raw) {
              final id = m['id'] is int ? m['id'] : (int.tryParse(m['id']?.toString() ?? '') ?? 0);
              if (id > 0) deduped[id] = Map<String, dynamic>.from(m);
            }
            
            _messages = deduped.values.toList();
            // Sort DESC (newest first)
            _messages.sort((a, b) {
              final da = DateTime.parse(a['created_at']);
              final db = DateTime.parse(b['created_at']);
              return db.compareTo(da);
            });
            
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (jump) {
          _scrollController.jumpTo(0.0);
        } else {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    FocusScope.of(context).unfocus();

    // Optimistically add message
    final tempMessage = _parseSingleMessage({
      'id': DateTime.now().millisecondsSinceEpoch,
      'sender_id': _currentUserId,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
      'pending': true,
      'reply_to_id': _replyingTo?['id'],
      'reply_to_content': _replyingTo?['content'],
      'reply_to_sender_id': _replyingTo?['sender_id'],
      'reply_to_message_type': _replyingTo?['message_type'],
    });

    final replyToId = _replyingTo?['id'];
    setState(() {
      _messages.insert(0, tempMessage);
      _replyingTo = null;
    });
    _scrollToBottom();

    try {
      final res = await ApiService.sendMessage(widget.channelId, text, replyToId: replyToId);
      if (res.statusCode == 200) {
        final body = await compute<String, dynamic>(jsonDecode, res.body);
        // Replace temp message with server one
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempMessage['id']);
          final serverId = body['message']['id'] is int ? body['message']['id'] : (int.tryParse(body['message']['id']?.toString() ?? '') ?? 0);
          
          if (index != -1) {
            // Check if socket already inserted this serverId
            final existingIndex = _messages.indexWhere((m) => m['id'] == serverId);
            if (existingIndex != -1 && existingIndex != index) {
              _messages.removeAt(index); // Just remove temp
            } else {
              _messages[index] = _parseSingleMessage({
                ...body['message'],
                'sender_id': body['message']['sender_id'],
              });
            }
          }
          
          // Final safety deduplication
          final seen = <int>{};
          _messages.retainWhere((m) => seen.add(m['id'] as int));
        });
      } else {
        // Mark as failed
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempMessage['id']);
          if (index != -1) {
            _messages[index]['failed'] = true;
          }
        });
      }
    } catch (_) {
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == tempMessage['id']);
        if (index != -1) {
          _messages[index]['failed'] = true;
        }
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);
        
        setState(() {
          _isRecording = true;
          _isRecordingCancelled = false;
          _recordingDuration = 0;
        });
        // Store path as a closure variable instead of state
        _currentRecordingPath = path;

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration++;
          });
        });
        
        _triggerVibrationShort();
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  void _triggerVibrationShort() async {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
      Vibration.vibrate(duration: 100);
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
      });
      
      if (_isRecordingCancelled) {
        _showCustomToast('Recording cancelled', isError: true);
        return;
      }

      if (path != null && _recordingDuration >= 1) {
        _sendVoiceMessage(path, _recordingDuration);
      } else {
        _showCustomToast('Recording too short', isError: true);
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _sendVoiceMessage(String path, int duration) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final base64Audio = 'data:audio/m4a;base64,${await compute(base64Encode, bytes)}';

      // Optimistically add message
      final tempMessage = _parseSingleMessage({
        'id': -(DateTime.now().millisecondsSinceEpoch),
        'sender_id': _currentUserId,
        'content': base64Audio,
        'message_type': 'voice',
        'duration': duration,
        'created_at': DateTime.now().toIso8601String(),
        'pending': true,
      });
      setState(() {
        _messages.insert(0, tempMessage);
      });
      _scrollToBottom();

      final res = await ApiService.sendMessage(
        widget.channelId, 
        base64Audio, 
        messageType: 'voice', 
        duration: duration
      );

      if (res.statusCode == 200) {
        final body = await compute<String, dynamic>(jsonDecode, res.body);
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempMessage['id']);
          final serverId = body['message']['id'] is int ? body['message']['id'] : (int.tryParse(body['message']['id']?.toString() ?? '') ?? 0);
          
          if (index != -1) {
            final existingIndex = _messages.indexWhere((m) => m['id'] == serverId);
            if (existingIndex != -1 && existingIndex != index) {
              _messages.removeAt(index);
            } else {
              _messages[index] = _parseSingleMessage({
                ...body['message'],
                'sender_id': body['message']['sender_id'],
              });
            }
          }
          
          final seen = <int>{};
          _messages.retainWhere((m) => seen.add(m['id'] as int));
        });
      } else {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempMessage['id']);
          if (index != -1) _messages[index]['failed'] = true;
        });
      }
    } catch (e) {
      print('Error sending voice message: $e');
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _checkCooldown();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkCooldown());
  }

  void _checkCooldown() {
    if (_lastAttentionSeekerAt == null || !mounted) return;

    final nowServer = DateTime.now().add(_serverTimeOffset);
    final lastUse = _lastAttentionSeekerAt!;
    final diff = nowServer.difference(lastUse);
    final cooldown = _isPremium ? const Duration(minutes: 10) : const Duration(days: 9999);

    if (diff < cooldown) {
      final remaining = cooldown - diff;
      String label;
      if (!_isPremium) {
        label = 'Rizz+ required';
      } else if (remaining.inDays > 0 && remaining.inDays < 365) {
        label = '${remaining.inDays}d ${remaining.inHours % 24}h';
      } else if (remaining.inHours > 0) {
        label = '${remaining.inHours}h ${remaining.inMinutes % 60}m';
      } else if (remaining.inMinutes > 0) {
        label = '${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
        _cooldownTimer?.cancel();
        _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkCooldown());
      } else {
        label = '${remaining.inSeconds}s';
      }
      if (label != _cooldownRemaining || !_isAttentionCooldownActive) {
        setState(() {
          _isAttentionCooldownActive = true;
          _cooldownRemaining = label;
        });
      }
    } else {
      if (_isAttentionCooldownActive) {
        setState(() {
          _isAttentionCooldownActive = false;
          _cooldownRemaining = '';
        });
      }
      _cooldownTimer?.cancel();
    }
  }

  void _handleAttentionSeeker() {
    if (_isAttentionCooldownActive) {
      if (!_isPremium) {
        _showCustomToast('Attention Seeker is a Premium feature after your first use. Upgrade to Rizz+!', isError: true);
      } else {
        _showCustomToast('Cooldown active: $_cooldownRemaining', isError: true);
      }
      return;
    }

    if (!_isPeerOnline) {
      _showCustomToast('${widget.peerName} is currently offline. You can only seek attention when they are online!', isError: true);
      return;
    }

    _triggerVibration();
    SocketService().emitAttentionSeeker(widget.peerId);
    
    setState(() {
      _lastAttentionSeekerAt = DateTime.now();
      _isAttentionCooldownActive = true;
    });
    _startCooldownTimer();
    _showCustomToast('Seeking attention...');
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.obsidianEdge,
        title: Text('Block ${widget.peerName}?', style: GoogleFonts.outfit(color: Colors.white)),
        content: Text('They will no longer be able to message you, and you won\'t be able to message them.', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: GoogleFonts.inter(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final res = await ApiService.blockUser(widget.peerId);
              if (res.statusCode == 200) {
                _showCustomToast('User blocked');
                if (mounted) Navigator.pop(context); 
              }
            },
            child: Text('BLOCK', style: GoogleFonts.inter(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showUnblockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.obsidianEdge,
        title: Text('Unblock ${widget.peerName}?', style: GoogleFonts.outfit(color: Colors.white)),
        content: Text('They will be able to message you again.', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: GoogleFonts.inter(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final res = await ApiService.unblockUser(widget.peerId);
              if (res.statusCode == 200) {
                _showCustomToast('User unblocked');
                if (mounted) {
                  setState(() {
                    _isBlocked = false;
                  });
                }
              }
            },
            child: Text('UNBLOCK', style: GoogleFonts.inter(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.obsidianEdge,
        title: Text('Report ${widget.peerName}', style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tell us why you are reporting this user:', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: GoogleFonts.inter(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(context);
              final res = await ApiService.reportUser(widget.peerId, reasonController.text.trim());
              if (res.statusCode == 200) {
                _showCustomToast('Reported successfully');
              }
            },
            child: Text('REPORT', style: GoogleFonts.inter(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF2A2B2E),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2B2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PublicAuraScreen(userId: widget.peerId)),
            );
          },
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.surfaceContainerHighest,
                    backgroundImage: _peerImageProvider,
                    child: _peerImageProvider == null
                        ? const Icon(Icons.person, color: AppColors.outlineVariant)
                        : null,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.peerName,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isBlocked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                            ),
                            child: Text(
                              'BLOCKED',
                              style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!_isBlocked) ...[
                      if (_isPeerTyping)
                        Text(
                          'typing...',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else if (_isPeerOnline)
                        Text(
                          'Online',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else if (widget.lastSeen != null)
                        Text(
                          'Last seen ${_formatLastSeen(widget.lastSeen!)}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant.withOpacity(0.6),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: _showGameBottomSheet,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/icon-game.jpg',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined, color: AppColors.onSurface),
            onPressed: () => _showCustomToast('Call feature coming soon!', isError: false),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.onSurface),
            color: AppColors.obsidianEdge,
            elevation: 8,
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            constraints: const BoxConstraints(minWidth: 180),
            onSelected: (value) {
              if (value == 'view_profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PublicAuraScreen(userId: widget.peerId)),
                );
              } else if (value == 'block') {
                _showBlockConfirmation();
              } else if (value == 'unblock') {
                _showUnblockConfirmation();
              } else if (value == 'report') {
                _showReportDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'view_profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 20, color: Colors.white70),
                    const SizedBox(width: 12),
                    Text('View Profile', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Icons.report_problem_outlined, size: 20, color: Colors.white70),
                    const SizedBox(width: 12),
                    Text('Report User', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: _isBlocked ? 'unblock' : 'block',
                child: Row(
                  children: [
                    Icon(
                      _isBlocked ? Icons.lock_open_outlined : Icons.block_flipped,
                      size: 20,
                      color: _isBlocked ? Colors.greenAccent : Colors.redAccent,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isBlocked ? 'Unblock User' : 'Block User',
                      style: GoogleFonts.inter(
                        color: _isBlocked ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: DeluluChatBackground(
        scrollController: _scrollController,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
                      : RepaintBoundary(
                          child: ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          itemCount: _messages.length,
                          cacheExtent: 800,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final id = msg['id'] is int ? msg['id'] : (int.tryParse(msg['id']?.toString() ?? '') ?? 0);
                            if (!_messageKeys.containsKey(id)) {
                              _messageKeys[id] = GlobalKey();
                            }

                            final isMe = msg['sender_id'].toString() == _currentUserId.toString();
                            final isFailed = msg['failed'] == true;
                            final type = msg['message_type'] ?? 'text';

                            bool isGrouped = false;
                            if (index > 0) {
                              final youngerMsg = _messages[index - 1];
                              if (youngerMsg['sender_id'].toString() == msg['sender_id'].toString()) {
                                final currDate = msg['_parsed_date'] as DateTime?;
                                final youngerDate = youngerMsg['_parsed_date'] as DateTime?;
                                if (currDate != null && youngerDate != null) {
                                  if (youngerDate.difference(currDate).inMinutes.abs() < 5) {
                                    isGrouped = true;
                                  }
                                }
                              }
                            }

                            bool showDateDivider = false;
                            if (index == _messages.length - 1) {
                              showDateDivider = true;
                            } else {
                              final olderMsg = _messages[index + 1];
                              final olderDate = olderMsg['_parsed_date'] as DateTime?;
                              final currDate = msg['_parsed_date'] as DateTime?;
                              if (olderDate != null && currDate != null) {
                                if (olderDate.year != currDate.year || olderDate.month != currDate.month || olderDate.day != currDate.day) {
                                  showDateDivider = true;
                                }
                              }
                            }

                            Widget content;
                            if (type == 'game_status') {
                              content = Center(
                                key: _messageKeys[id],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: _buildGameStatusCard(msg),
                                ),
                              );
                            } else {
                              content = _ChatBubble(
                                key: _messageKeys[id],
                                msg: msg,
                                isMe: isMe,
                                isFailed: isFailed,
                                isGrouped: isGrouped,
                                screenWidth: MediaQuery.of(context).size.width,
                                onReply: (m) => setState(() => _replyingTo = m),
                                onScrollToMessage: _scrollToMessage,
                              );
                            }

                            if (showDateDivider) {
                              return Column(
                                children: [
                                  _buildDateDivider(msg['created_at']),
                                  content,
                                ],
                              );
                            }
                            return content;
                          },
                        ),
                      ),
                ),
                if (_replyingTo != null) _buildReplyPreview(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onLongPress: _handleAttentionSeeker,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isAttentionCooldownActive
                                ? [Colors.grey.shade800, Colors.grey.shade900]
                                : [AppColors.primary, AppColors.tertiary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isAttentionCooldownActive ? Colors.black : AppColors.primary)
                                  .withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isAttentionCooldownActive ? Icons.timer_outlined : Icons.vibration,
                                color: Colors.white,
                                size: _isAttentionCooldownActive ? 16 : 24,
                              ),
                              if (_isAttentionCooldownActive)
                                Text(
                                  _cooldownRemaining.split(' ').first,
                                  style: GoogleFonts.inter(fontSize: 8, color: Colors.white70),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2B2E),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                    ),
                    child: Row(
                      children: [
                        if (_isRecording)
                          Expanded(
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isRecordingLocked ? Icons.lock : Icons.mic,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${(_recordingDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordingDuration % 60).toString().padLeft(2, '0')}',
                                    style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  if (!_isRecordingLocked)
                                    Text(
                                      _isRecordingCancelled ? 'Release to cancel' : 'Slide to cancel',
                                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                                    ),
                                  if (_isRecordingLocked)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => _isRecordingCancelled = true);
                                        _stopRecording();
                                      },
                                      child: Text(
                                        'CANCEL',
                                        style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: _msgController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        (() {
                          if (_msgController.text.trim().isNotEmpty || _isRecordingLocked) {
                            return GestureDetector(
                              onTap: _isRecordingLocked ? _stopRecording : _sendMessage,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, AppColors.tertiary],
                                  ),
                                ),
                                child: const Icon(Icons.send, color: Colors.white),
                              ),
                            );
                          } else {
                            return GestureDetector(
                              onTap: () => _showCustomToast('Hold to record', isError: false),
                              onLongPress: _startRecording,
                              onLongPressMoveUpdate: (details) {
                                if (_isRecording && !_isRecordingLocked) {
                                  if (details.offsetFromOrigin.dx < -80) {
                                    if (!_isRecordingCancelled) {
                                      setState(() => _isRecordingCancelled = true);
                                      _triggerVibrationShort();
                                    }
                                  } else {
                                    if (_isRecordingCancelled) {
                                      setState(() => _isRecordingCancelled = false);
                                    }
                                  }
                                  
                                  if (details.offsetFromOrigin.dy < -80) {
                                    setState(() {
                                      _isRecordingLocked = true;
                                      _isRecordingCancelled = false;
                                    });
                                    _triggerVibrationShort();
                                  }
                                }
                              },
                              onLongPressUp: () {
                                if (!_isRecordingLocked) {
                                  _stopRecording();
                                }
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (_isRecording && !_isRecordingLocked)
                                    Positioned(
                                      bottom: 60,
                                      child: Column(
                                        children: [
                                          const Icon(Icons.lock_outline, color: Colors.white54, size: 20),
                                          Text('Lock', style: GoogleFonts.inter(color: Colors.white54, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: _isRecording ? 64 : 48,
                                    height: _isRecording ? 64 : 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isRecording ? Colors.redAccent : Colors.white.withOpacity(0.05),
                                      boxShadow: _isRecording ? [
                                        BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)
                                      ] : [],
                                    ),
                                    child: Icon(
                                      _isRecording ? Icons.mic : Icons.mic, 
                                      color: Colors.white,
                                      size: _isRecording ? 32 : 24,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        })(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _parseSingleMessage(Map<String, dynamic> msg) {
    String content = msg['content'] ?? '';
    if (_e2eEnabled && msg['message_type'] != 'voice' && !content.isEmpty && !msg.containsKey('pending')) {
       try { content = EncryptionHelper.decryptMessage(content); } catch (_) {}
    }
    return {
      ...msg,
      'content': content,
      '_parsed_date': DateTime.tryParse(msg['created_at'] ?? ''),
      '_formatted_time': _formatTime(msg['created_at']),
      if (msg['message_type'] == 'game_status') '_parsed_game_data': jsonDecode(content),
    };
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  Widget _buildDateDivider(String iso) {
    String label;
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        label = 'TODAY';
      } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
        label = 'YESTERDAY';
      } else {
        label = '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {
      label = 'SOME TIME AGO';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildGameStatusCard(Map<String, dynamic> msg) {
    Map<String, dynamic> data = msg['_parsed_game_data'] ?? {};

    final status = data['status'] ?? 'unknown';
    final gameName = data['gameName'] ?? 'Game';
    final sessionId = data['sessionId'];

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'accepted':
        statusColor = AppColors.primary;
        statusText = 'Game Accepted!';
        statusIcon = Icons.sports_esports;
        break;
      case 'rejected':
        statusColor = Colors.redAccent;
        statusText = 'Invitation Rejected';
        statusIcon = Icons.block;
        break;
      case 'cancelled':
        statusColor = Colors.white54;
        statusText = 'Invitation Cancelled';
        statusIcon = Icons.cancel;
        break;
      case 'completed':
        statusColor = AppColors.secondary;
        statusText = 'Game Finished';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.white38;
        statusText = 'Game Status';
        statusIcon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 300),
      child: InkWell(
        onTap: (status == 'accepted' || status == 'completed') 
            ? () => _navigateToGame(data['gameId'] ?? '', gameName, sessionId: sessionId, viewOnly: true)
            : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: statusColor.withOpacity(0.15), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, 
                        color: Colors.white, 
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gameName,
                      style: GoogleFonts.inter(
                        color: statusColor.withOpacity(0.7), 
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (status == 'accepted' || status == 'completed')
                Icon(Icons.arrow_forward_ios, color: statusColor.withOpacity(0.5), size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2B2E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _replyingTo!['sender_id'].toString() == _currentUserId.toString() ? 'Replying to You' : 'Replying to ${widget.peerName}',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!['message_type'] == 'voice' ? '🎤 Voice message' : _replyingTo!['content'],
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white38, size: 20),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  void _scrollToMessage(int id) {
    final key = _messageKeys[id];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

}

final _bubbleShadow = [
  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 2)),
];
final _bubbleBorder = Border.all(color: Colors.white10, width: 0.5);
const _meGradientColors = [Color(0x4D8B5CF6), Color(0x268B5CF6)]; 
const _theirColor = Color(0x14FFFFFF); 

class _ChatBubble extends StatefulWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final bool isFailed;
  final bool isGrouped;
  final double screenWidth;
  final Function(Map<String, dynamic>) onReply;
  final Function(int) onScrollToMessage;

  const _ChatBubble({
    super.key,
    required this.msg,
    required this.isMe,
    required this.isFailed,
    required this.isGrouped,
    required this.screenWidth,
    required this.onReply,
    required this.onScrollToMessage,
  });

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> with SingleTickerProviderStateMixin {
  double _dragExtent = 0.0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final isMe = widget.isMe;
    final isFailed = widget.isFailed;
    final isGrouped = widget.isGrouped;
    final screenWidth = widget.screenWidth;
    final type = msg['message_type'] ?? 'text';
    final m = msg;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragExtent += details.delta.dx;
          if (_dragExtent > 0) _dragExtent = 0;
          if (_dragExtent < -60) _dragExtent = -60;
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragExtent <= -60) {
          widget.onReply(msg);
          HapticFeedback.lightImpact();
        }
        setState(() => _dragExtent = 0.0);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(_dragExtent, 0, 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -40,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: (_dragExtent / -60).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.reply, color: AppColors.primary, size: 18),
                  ),
                ),
              ),
            ),
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: EdgeInsets.only(bottom: isGrouped ? 2 : 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          colors: _meGradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe ? null : _theirColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : (isGrouped ? 20 : 4)),
                    bottomRight: Radius.circular(isMe ? (isGrouped ? 20 : 4) : 20),
                  ),
                  border: _bubbleBorder,
                  boxShadow: _bubbleShadow,
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (msg['reply_to_id'] != null)
                      GestureDetector(
                        onTap: () {
                          final rId = msg['reply_to_id'] is int ? msg['reply_to_id'] : int.tryParse(msg['reply_to_id'].toString());
                          if (rId != null) widget.onScrollToMessage(rId);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(
                              left: BorderSide(color: AppColors.primary, width: 3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['reply_to_sender_id'].toString() == widget.msg['sender_id'].toString() ? 'You' : 'Peer',
                                style: GoogleFonts.inter(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                msg['reply_to_message_type'] == 'voice' ? '🎤 Voice message' : (msg['reply_to_content'] ?? ''),
                                style: GoogleFonts.inter(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (type == 'voice')
                      VoiceMessageBubble(
                        content: msg['content'],
                        duration: msg['duration'] ?? 0,
                        isMe: isMe,
                      )
                    else
                      Text(
                        msg['content'] ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          msg['_formatted_time'] ?? '',
                          style: const TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                        if (isMe && !isFailed) ...[
                          const SizedBox(width: 4),
                          Icon(
                            m['read_at'] != null ? Icons.done_all : Icons.done,
                            size: 14,
                            color: m['read_at'] != null ? Colors.blueAccent : Colors.white30,
                          ),
                        ],
                        if (isFailed) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.error_outline, size: 12, color: Colors.redAccent),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VoiceMessageBubble extends StatefulWidget {
  final String content;
  final int duration;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.content,
    required this.duration,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _totalDuration = Duration(seconds: widget.duration);

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    
    _audioPlayer.onPlayerComplete.listen((_) {
       if (mounted) setState(() {
         _isPlaying = false;
         _position = Duration.zero;
       });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (widget.content.startsWith('data:audio')) {
        try {
          final base64Str = widget.content.split(',').last;
          final bytes = await compute<String, Uint8List>(base64Decode, base64Str);
          await _audioPlayer.play(BytesSource(bytes));
        } catch (e) {
          debugPrint('Error playing voice message: $e');
        }
      } else {
        await _audioPlayer.play(UrlSource(widget.content));
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isMe ? Colors.white24 : AppColors.primary.withOpacity(0.2),
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble().clamp(0, _totalDuration.inMilliseconds.toDouble()),
                    max: _totalDuration.inMilliseconds > 0 
                        ? _totalDuration.inMilliseconds.toDouble() 
                        : 1.0,
                    onChanged: (v) {
                      _audioPlayer.seek(Duration(milliseconds: v.toInt()));
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: const TextStyle(fontSize: 9, color: Colors.white70),
                    ),
                    Text(
                      _formatDuration(_totalDuration),
                      style: const TextStyle(fontSize: 9, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}