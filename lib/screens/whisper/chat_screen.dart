import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  Timer? _typingTimer;
  StreamSubscription? _socketSub;
  
  bool _isPremium = false;
  DateTime? _lastAttentionSeekerAt;
  bool _isAttentionCooldownActive = false;
  String _cooldownRemaining = "";
  Timer? _cooldownTimer;
  ImageProvider? _peerImageProvider;

  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  String? _recordingPath;
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  Duration _serverTimeOffset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _isPeerOnline = widget.isOnline;
    _initPeerImageProvider();
    _audioRecorder = AudioRecorder();
    _fetchCurrentUser().then((_) => _loadMessages()); // Chain to ensure ID is ready
    _fetchPeerProfile();
    _markRead();
    _initSocket();
  }

  void _initPeerImageProvider() {
    if (widget.peerImageUrl != null && widget.peerImageUrl!.isNotEmpty) {
      if (widget.peerImageUrl!.startsWith('data:image')) {
        _peerImageProvider = MemoryImage(base64Decode(widget.peerImageUrl!.split(',').last));
      } else {
        _peerImageProvider = CachedNetworkImageProvider(widget.peerImageUrl!);
      }
    }
  }

  Future<void> _fetchPeerProfile() async {
    try {
      final res = await ApiService.getPublicProfile(widget.peerId);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
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
          if (!_messages.any((m) => m['id'] == msg['id'])) {
            _messages.add(msg);
            _scrollToBottom();
          }
        });
        if (msg['sender_id'] != _currentUserId) {
          _markRead();
        }
      }
    });

    // Listen for read receipts
    SocketService().readReceiptStream.listen((data) {
      if (mounted && data['channelId'] == widget.channelId) {
        _loadMessages();
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
          _fetchCurrentUser(); // Refresh to get correct timestamp
        } else {
          _showCustomToast(data['message'], isError: true);
        }
      }
    });
  }

  void _triggerVibration() async {
    if (await Vibration.hasVibrator() ?? false) {
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

  void _onTypingChanged() {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    
    // Rebuild to toggle Mic/Send button
    setState(() {});

    // Emit "typing" if text is not empty
    if (_msgController.text.isNotEmpty) {
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
        final body = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _currentUserId = body['user']['id'].toString();
            _isPremium = body['user']['is_premium'] == true;
            
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
      final body = jsonDecode(res.body);
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(body['messages'] ?? []);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    // Optimistically add message
    final tempMessage = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'sender_id': _currentUserId,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
      'pending': true,
    };
    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    try {
      final res = await ApiService.sendMessage(widget.channelId, text);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        // Replace temp message with server one
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempMessage['id']);
          if (index != -1) {
            _messages[index] = {
              ...body['message'],
              'sender_id': body['message']['sender_id'],
            };
          }
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
          _recordingPath = path;
          _recordingDuration = 0;
        });

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
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      
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
      final base64Audio = 'data:audio/m4a;base64,${base64Encode(bytes)}';

      // Optimistically add message
      final tempMessage = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'sender_id': _currentUserId,
        'content': base64Audio,
        'message_type': 'voice',
        'duration': duration,
        'created_at': DateTime.now().toIso8601String(),
        'pending': true,
      };
      setState(() {
        _messages.add(tempMessage);
      });
      _scrollToBottom();

      final res = await ApiService.sendMessage(
        widget.channelId, 
        base64Audio, 
        messageType: 'voice', 
        duration: duration
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempMessage['id']);
          if (index != -1) {
            _messages[index] = {
              ...body['message'],
              'sender_id': body['message']['sender_id'],
            };
          }
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
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkCooldown());
  }

  void _checkCooldown() {
    if (_lastAttentionSeekerAt == null) return;

    final nowServer = DateTime.now().add(_serverTimeOffset);
    final lastUse = _lastAttentionSeekerAt!;
    final diff = nowServer.difference(lastUse);
    final cooldown = _isPremium ? const Duration(minutes: 30) : const Duration(days: 7);

    if (diff < cooldown) {
      final remaining = cooldown - diff;
      setState(() {
        _isAttentionCooldownActive = true;
        if (remaining.inDays > 0) {
          _cooldownRemaining = '${remaining.inDays}d ${remaining.inHours % 24}h';
        } else if (remaining.inHours > 0) {
          _cooldownRemaining = '${remaining.inHours}h ${remaining.inMinutes % 60}m';
        } else {
          _cooldownRemaining = '${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _isAttentionCooldownActive = false;
          _cooldownRemaining = "";
        });
      }
      _cooldownTimer?.cancel();
    }
  }

  void _handleAttentionSeeker() {
    if (_isAttentionCooldownActive) {
      if (!_isPremium) {
        _showCustomToast('Attention Seeker is on cooldown. Upgrade to Premium for 30-min reuse!', isError: true);
      } else {
        _showCustomToast('Cooldown active: $_cooldownRemaining', isError: true);
      }
      return;
    }

    if (!_isPeerOnline) {
      _showCustomToast('${widget.peerName} is currently offline. You can only seek attention when they are online!', isError: true);
      return;
    }

    // Trigger local feedback
    _triggerVibration();
    
    // Emit to server
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
                if (mounted) Navigator.pop(context); // Leave chat
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
      backgroundColor: const Color(0xFF2A2B2E),
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
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
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
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_id'].toString() == _currentUserId.toString();
                          final isFailed = msg['failed'] == true;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.primaryContainer.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(isMe ? 18 : 4),
                                  topRight: Radius.circular(isMe ? 4 : 18),
                                  bottomLeft: const Radius.circular(18),
                                  bottomRight: const Radius.circular(18),
                                ),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (msg['message_type'] == 'voice')
                                    VoiceMessageBubble(
                                      content: msg['content'],
                                      duration: msg['duration'] ?? 0,
                                      isMe: isMe,
                                    )
                                  else
                                    Text(
                                      msg['content'],
                                      style: GoogleFonts.beVietnamPro(fontSize: 15, color: AppColors.onSurface),
                                    ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateTime.parse(msg['created_at']).hour.toString().padLeft(2, '0') +
                                            ':' +
                                            DateTime.parse(msg['created_at']).minute.toString().padLeft(2, '0'),
                                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.outline.withValues(alpha: 0.5)),
                                      ),
                                      if (isMe && !isFailed) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          msg['read_at'] != null ? Icons.done_all : Icons.check,
                                          size: 14,
                                          color: msg['read_at'] != null ? AppColors.primaryContainer : AppColors.outline.withValues(alpha: 0.5),
                                        ),
                                      ],
                                      if (isFailed) ...[
                                        const SizedBox(width: 4),
                                        Icon(Icons.error_outline, size: 12, color: AppColors.error),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Input bar
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Attention Seeker Button
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
                                  .withValues(alpha: 0.3),
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
                      border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                    ),
                    child: Row(
                      children: [
                        if (_isRecording)
                          Expanded(
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.mic, color: Colors.redAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Recording... ${_recordingDuration}s',
                                    style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Release to send',
                                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.5),
                                    AppColors.tertiary.withValues(alpha: 0.5),
                                  ],
                                ),
                              ),
                              padding: const EdgeInsets.all(1), // thin border
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1B1E),
                                  borderRadius: BorderRadius.circular(23),
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
                                  onChanged: (_) => _onTypingChanged(),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        // Voice/Send Toggle
                        (() {
                          if (_msgController.text.trim().isNotEmpty) {
                            return GestureDetector(
                              onTap: _sendMessage,
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
                              onLongPressUp: _stopRecording,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isRecording ? Colors.redAccent : Colors.white.withOpacity(0.05),
                                ),
                                child: Icon(
                                  _isRecording ? Icons.stop : Icons.mic, 
                                  color: Colors.white
                                ),
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
        final base64Str = widget.content.split(',').last;
        final bytes = base64Decode(base64Str);
        await _audioPlayer.play(BytesSource(bytes));
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