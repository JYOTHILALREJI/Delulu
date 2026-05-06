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
  Timer? _typingTimer;
  StreamSubscription? _socketSub;
  
  bool _isPremium = false;
  DateTime? _lastAttentionSeekerAt;
  bool _isAttentionCooldownActive = false;
  String _cooldownRemaining = "";
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _isPeerOnline = widget.isOnline;
    _fetchCurrentUser();
    _loadMessages();
    _markRead();
    _initSocket();
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
            _currentUserId = body['user']['id'];
            _isPremium = body['user']['is_premium'] == true;
            final lastAt = body['user']['last_attention_seeker_at'];
            print('DEBUG: last_attention_seeker_at from server: $lastAt');
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

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _checkCooldown();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkCooldown());
  }

  void _checkCooldown() {
    if (_lastAttentionSeekerAt == null) return;

    final now = DateTime.now();
    // lastAttentionSeekerAt is parsed from UTC string, convert to local for comparison
    final lastUseLocal = _lastAttentionSeekerAt!.toLocal();
    final diff = now.difference(lastUseLocal);
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
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  backgroundImage: widget.peerImageUrl != null && widget.peerImageUrl!.isNotEmpty
                      ? (widget.peerImageUrl!.startsWith('data:image')
                          ? MemoryImage(base64Decode(widget.peerImageUrl!.split(',').last))
                          : CachedNetworkImageProvider(widget.peerImageUrl!) as ImageProvider)
                      : null,
                  child: widget.peerImageUrl == null || widget.peerImageUrl!.isEmpty
                      ? const Icon(Icons.person, color: AppColors.outlineVariant)
                      : null,
                ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peerName,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
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
            ),
          ],
        ),
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
                          final isMe = msg['sender_id'] == _currentUserId;
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
                                borderRadius: BorderRadius.circular(23),
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                              child: TextField(
                                controller: _msgController,
                                style: GoogleFonts.beVietnamPro(fontSize: 15, color: AppColors.onSurface),
                                decoration: InputDecoration(
                                  hintText: 'Type a whisper...',
                                  hintStyle: GoogleFonts.beVietnamPro(
                                      fontSize: 15, color: AppColors.onSurfaceVariant.withValues(alpha: 0.7)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(23),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                textCapitalization: TextCapitalization.sentences,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                            onPressed: _sendMessage,
                          ),
                        ),
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