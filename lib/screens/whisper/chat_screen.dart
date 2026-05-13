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
import 'package:vibration/vibration.dart';
import '../aura/public_aura_screen.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'components/game_drawer.dart';
import 'game_screen.dart';
import '../../utils/encryption_helper.dart';

// ----- Helper to decrypt and parse a single message -----
Map<String, dynamic> _parseSingleMessage(Map<String, dynamic> raw) {
  final msg = Map<String, dynamic>.from(raw);
  final content = msg['content'];
  if (content is String && EncryptionHelper.isEncrypted(content)) {
    try {
      msg['content'] = EncryptionHelper.decryptMessage(content);
    } catch (_) {}
  }
  // Parse date
  if (msg['created_at'] != null) {
    try {
      final dt = DateTime.parse(msg['created_at'].toString()).toLocal();
      msg['_parsed_date'] = dt;
      msg['_formatted_time'] = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}
  }
  // Parse game status
  if (msg['message_type'] == 'game_status') {
    try {
      final gameData = content is Map ? content : jsonDecode(content.toString());
      msg['_parsed_game_data'] = gameData is Map ? gameData : {};
      if (msg['_parsed_game_data']['sessionId'] != null) {
        msg['_gameSessionId'] = msg['_parsed_game_data']['sessionId'].toString();
      }
    } catch (_) {
      msg['_parsed_game_data'] = {};
    }
  }
  return msg;
}

// ----- Individual message bubble with ValueNotifier -----
class _OptimizedChatBubble extends StatefulWidget {
  final ValueNotifier<Map<String, dynamic>> messageNotifier;
  final bool isMe;
  final bool isFailed;
  final bool isGrouped;
  final double screenWidth;
  final VoidCallback onReply;
  final String currentUserId;
  final String peerName;
  final Function(String reaction) onReactionSelected;
  final Function(Map<String, dynamic> msg) gameCardBuilder;

  const _OptimizedChatBubble({
    Key? key,
    required this.messageNotifier,
    required this.isMe,
    required this.isFailed,
    required this.isGrouped,
    required this.screenWidth,
    required this.onReply,
    required this.onReactionSelected,
    required this.currentUserId,
    required this.peerName,
    required this.gameCardBuilder,
  }) : super(key: key);

  @override
  State<_OptimizedChatBubble> createState() => _OptimizedChatBubbleState();
}

class _OptimizedChatBubbleState extends State<_OptimizedChatBubble> {
  double _dragExtent = 0.0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: widget.messageNotifier,
      builder: (context, msg, _) {
        final type = msg['message_type'] ?? 'text';
        final reactions = List<Map<String, dynamic>>.from(msg['reactions'] ?? []);
        final isReply = msg['reply_to_id'] != null;
        
        final snapshot = msg['snapshot'] ?? {};
        final senderSnapshot = snapshot['sender'] ?? {};
        final peerSnapshot = snapshot['peer'] ?? {};
        
        // Read receipt logic: only show pink ticks if the PEER (receiver) has them enabled
        // WhatsApp Rule: My visibility depends on the peer's choice to share.
        final peerAllowsReadReceipts = peerSnapshot['readReceiptsEnabled'] ?? true;
        final isRead = msg['read_at'] != null;
        final showPinkTick = isRead && peerAllowsReadReceipts;
        
        // E2EE logic: Banner is shown once per session, not in bubbles
        // (Removing isE2EE field here to clean up bubbles)

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragExtent += details.delta.dx;
              if (_dragExtent > 0) _dragExtent = 0;
              if (_dragExtent < -60) _dragExtent = -60;
            });
          },
          onHorizontalDragEnd: (_) {
            if (_dragExtent <= -60) {
              widget.onReply();
              HapticFeedback.lightImpact();
            }
            setState(() => _dragExtent = 0.0);
          },
          onLongPress: widget.isMe ? null : () => _showReactionPicker(context),
          child: Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Reply hint
                if (_dragExtent < 0)
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
                // Bubble
                Align(
                  alignment: type == 'game_status' 
                    ? Alignment.center 
                    : (widget.isMe ? Alignment.centerRight : Alignment.centerLeft),
                  child: Column(
                    crossAxisAlignment: type == 'game_status'
                      ? CrossAxisAlignment.center
                      : (widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start),
                    children: [
                      if (type == 'game_status')
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: widget.gameCardBuilder(msg),
                        )
                      else
                        Container(
                          margin: EdgeInsets.only(bottom: widget.isGrouped ? 2 : 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: widget.screenWidth * 0.75),
                          decoration: BoxDecoration(
                            gradient: widget.isMe
                                ? const LinearGradient(
                                    colors: [Color(0x4D8B5CF6), Color(0x268B5CF6)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: widget.isMe ? null : const Color(0x14FFFFFF),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(widget.isMe ? 20 : (widget.isGrouped ? 20 : 4)),
                              bottomRight: Radius.circular(widget.isMe ? (widget.isGrouped ? 20 : 4) : 20),
                            ),
                            border: Border.all(color: Colors.white10, width: 0.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (isReply) _buildReplyPreview(msg),
                              if (type == 'voice')
                                VoiceMessageBubble(
                                  content: msg['content'],
                                  duration: msg['duration'] ?? 0,
                                  isMe: widget.isMe,
                                )
                              else
                                Text(
                                  msg['content'] ?? '',
                                  style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.35),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    msg['_formatted_time'] ?? '',
                                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                                  ),
                                  if (widget.isMe && !widget.isFailed) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      isRead ? Icons.done_all : Icons.done,
                                      size: 14,
                                      color: showPinkTick ? const Color(0xFFFF4FA3) : Colors.white30,
                                    ),
                                  ],
                                  if (widget.isFailed) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.error_outline, size: 12, color: Colors.redAccent),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (reactions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 4,
                            children: reactions.map((r) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF374151),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Text(r['reaction'], style: const TextStyle(fontSize: 12)),
                            )).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReactionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['❤️', '😂', '😮', '😢', '😡', '👍'].map((emoji) => GestureDetector(
            onTap: () {
              widget.onReactionSelected(emoji);
              Navigator.pop(ctx);
            },
            child: Text(emoji, style: const TextStyle(fontSize: 32)),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(Map<String, dynamic> msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg['reply_to_sender_id'].toString() == widget.currentUserId ? 'You' : widget.peerName,
            style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            msg['reply_to_message_type'] == 'voice' ? '🎤 Voice message' : (msg['reply_to_content'] ?? ''),
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Temporary stub for game status card - will be updated to use actual logic
  Widget _buildGameStatusCard(Map<String, dynamic> msg) {
    return Container(); // Placeholder
  }
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

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final List<ValueNotifier<Map<String, dynamic>>> _messageNotifiers = [];
  final Map<int, ValueNotifier<Map<String, dynamic>>> _notifierMap = {};
  
  bool _isLoading = true;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;
  bool _isPeerOnline = false;
  bool _isPeerTyping = false;
  bool _isBlocked = false;
  bool _isPeerPremium = false;
  bool _e2eEnabled = false;
  bool _typingIndicatorEnabled = true;
  Timer? _typingTimer;
  
  bool _isPremium = false;
  bool _isAttentionCooldownActive = false;
  bool _isAttentionFreeUsed = false;
  String _cooldownRemaining = "";
  Timer? _cooldownTimer;
  ImageProvider? _peerImageProvider;

  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isRecordingCancelled = false;
  bool _isRecordingLocked = false;
  String? _currentRecordingPath;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  Map<String, dynamic>? _replyingTo;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Duration _serverTimeOffset = Duration.zero;
  DateTime? _lastAttentionSeekerAt;
  late AnimationController _attentionPulseController;
  late Animation<double> _attentionPulseAnimation;

  @override
  void initState() {
    super.initState();
    _isPeerOnline = widget.isOnline;
    _initPeerImageProvider();
    _audioRecorder = AudioRecorder();
    // Mark this peer's chat as active so global banner is suppressed
    SocketService().activeChatPeerId = widget.peerId;
    
    _attentionPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _attentionPulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _attentionPulseController, curve: Curves.easeInOut),
    );

    _loadCachedData().then((_) {
      _fetchCurrentUser().then((_) => _loadMessages());
    });

    _fetchPeerProfile();
    _markRead();
    _initSocket();

    // Notify server we are viewing this conversation for realtime read receipts
    SocketService().emitConversationViewing(widget.channelId);
    SocketService().emitMessageSync(widget.channelId);

    _msgController.addListener(_onTypingChanged);
    _loadPersistedCooldown();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedId = prefs.getString('current_user_id');
      if (cachedId != null) {
        _currentUserId = cachedId;
      }
      
      if (mounted) {
        setState(() {
          _isPremium = prefs.getBool('is_premium') ?? false;
        });
      }

      final cachedMsgs = prefs.getString('chat_messages_${widget.channelId}');
      if (cachedMsgs != null) {
        final body = await compute<String, dynamic>(jsonDecode, cachedMsgs);
        final List<dynamic> raw = body['messages'] ?? [];
        
        final List<ValueNotifier<Map<String, dynamic>>> notifiers = [];
        for (var m in raw) {
          final parsed = _parseSingleMessage(m as Map<String, dynamic>);
          final notifier = ValueNotifier(parsed);
          notifiers.add(notifier);
          _notifierMap[parsed['id']] = notifier;
        }

        if (mounted) {
          setState(() {
            _messageNotifiers.clear();
            _messageNotifiers.addAll(notifiers);
            _isLoading = false;
          });
          _scrollToBottom(animated: false);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
            _isPeerPremium = body['profile']?['is_premium_user'] == true;
          });
        }
      }
    } catch (_) {}
  }

  void _initSocket() {
    SocketService().messageStream.listen((rawMsg) {
      if (rawMsg['channel_id'] != widget.channelId) return;

      final msg = _parseSingleMessage(Map<String, dynamic>.from(rawMsg));

      // CHECK FOR OPTIMISTIC MESSAGE
      final incomingTempId = msg['client_temp_id'];

      if (incomingTempId != null) {
        final existing = _messageNotifiers.where((n) {
          return n.value['client_temp_id'] == incomingTempId;
        }).toList();

        if (existing.isNotEmpty) {
          // REPLACE optimistic bubble with real DB message
          existing.first.value = msg;

          // Update notifier map to use the real database ID
          _notifierMap.remove(msg['id']); // Remove if it was accidentally added elsewhere
          _notifierMap[msg['id']] = existing.first;

          return;
        }
      }

      // Prevent duplicate DB insert
      final id = msg['id'];
      if (_notifierMap.containsKey(id)) return;

      // Deduplicate by gameSessionId in real-time
      final sessionId = msg['_gameSessionId'];
      if (sessionId != null) {
        final existingGameNotifier = _messageNotifiers.where((n) => n.value['_gameSessionId'] == sessionId).toList();
        if (existingGameNotifier.isNotEmpty) {
          // Update the existing card with the new status/data
          existingGameNotifier.first.value = msg;
          // Also update the notifierMap key if the DB ID changed
          _notifierMap.remove(existingGameNotifier.first.value['id']);
          _notifierMap[id] = existingGameNotifier.first;
          return;
        }
      }

      final notifier = ValueNotifier(msg);

      if (mounted) {
        setState(() {
          _messageNotifiers.add(notifier);
          _notifierMap[id] = notifier;
        });

        if (msg['sender_id'].toString() != _currentUserId.toString()) {
          _markRead();
          SocketService().emitConversationViewing(widget.channelId);
        }
        _scrollToBottom();
      }
    });

    SocketService().messageStatusStream.listen((data) {
      if (!mounted || data['channelId'] != widget.channelId) return;
      
      if (data['type'] == 'read_receipt') {
        final readAt = data['readAt'] ?? DateTime.now().toIso8601String();

        for (final notifier in _messageNotifiers) {
          final msg = notifier.value;
          final isMyMessage = msg['sender_id'].toString() == _currentUserId.toString();
          if (isMyMessage && msg['read_at'] == null) {
            notifier.value = { ...msg, 'read_at': readAt };
          }
        }
      } else if (data['type'] == 'unread_update') {
        // Optional: Trigger a reload if needed, but usually unread_update is for the other user
      }
    });

    SocketService().messageUpdateStream.listen((data) {
      if (mounted && data['channel_id'] == widget.channelId) {
        final updated = _parseSingleMessage(Map<String, dynamic>.from(data));
        final notifier = _notifierMap[updated['id']];
        if (notifier != null) notifier.value = updated;
      }
    });

    SocketService().typingStream.listen((data) {
      if (mounted && data['channelId'] == widget.channelId && data['from'].toString() == widget.peerId) {
        setState(() => _isPeerTyping = data['isTyping']);
      }
    });

    SocketService().statusStream.listen((data) {
      if (mounted && data['userId'] == widget.peerId) {
        setState(() => _isPeerOnline = data['status'] == 'online');
      }
    });

    SocketService().attentionStream.listen((data) {
      if (mounted) {
        _triggerVibration();
        _showCustomToast('${widget.peerName} is seeking your attention!', isError: true);
      }
    });

    SocketService().attentionSentStream.listen((data) {
      if (mounted) {
        setState(() {
          _lastAttentionSeekerAt = DateTime.parse(data['lastUsed']);
          if (!_isPremium) _isAttentionFreeUsed = true;
          _startCooldownTimer();
        });
      }
    });

    SocketService().errorStream.listen((data) {
      if (mounted) {
        if (data['type'] == 'attention_cooldown') {
          _showCustomToast(data['message'], isError: true);
          _startCooldownTimer();
        } else if (data['type'] == 'attention_premium_required') {
          _showCustomToast(data['message'], isError: true);
          setState(() => _isAttentionCooldownActive = true);
        } else {
          _showCustomToast(data['message'], isError: true);
        }
        _fetchCurrentUser();
      }
    });

    SocketService().reactionStream.listen((data) {
      if (!mounted) return;
      final notifier = _notifierMap[data['messageId']];
      if (notifier != null) {
        final msg = notifier.value;
        final reactions = List<Map<String, dynamic>>.from(msg['reactions'] ?? []);
        if (data['action'] == 'add') {
          final idx = reactions.indexWhere((r) => r['userId'] == data['userId']);
          if (idx != -1) reactions[idx]['reaction'] = data['reaction'];
          else reactions.add({'userId': data['userId'], 'reaction': data['reaction']});
        } else if (data['action'] == 'remove') {
          reactions.removeWhere((r) => r['userId'] == data['userId']);
        }
        msg['reactions'] = reactions;
        notifier.value = {...msg};
      }
    });

    // Listen for game invitations — show Accept/Reject sheet for User B
    SocketService().gameInviteStream.listen((data) {
      if (!mounted) return;
      // Only handle if the invite is from the current chat peer
      final fromId = data['fromId']?.toString() ?? '';
      if (fromId != widget.peerId) return;
      final sessionId = data['sessionId']?.toString() ?? '';
      final gameId   = data['gameId']?.toString()   ?? '';
      final gameName = data['gameName']?.toString()  ?? 'Game';
      final fromName = data['fromName']?.toString()  ?? widget.peerName;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        builder: (_) => Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A0033), Color(0xFF0D001A)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('🎲', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('$fromName challenged you!',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(gameName,
                style: GoogleFonts.inter(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    SocketService().emitGameInviteResponse(
                      widget.channelId, widget.peerId, gameId, gameName, sessionId, false);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('DECLINE', style: GoogleFonts.outfit(color: Colors.white54, letterSpacing: 1)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    SocketService().emitGameInviteResponse(
                      widget.channelId, widget.peerId, gameId, gameName, sessionId, true);
                    _navigateToGame(gameId, gameName, sessionId: sessionId, isInviter: false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('ACCEPT 🎉', style: GoogleFonts.outfit(
                    color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
                )),
              ]),
            ],
          ),
        ),
      );
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

  void _navigateToGame(String gameId, String gameName, {String? sessionId, bool viewOnly = false, bool isInviter = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          gameId: gameId,
          gameName: gameName,
          peerId: widget.peerId,
          peerName: widget.peerName,
          isInviter: isInviter,
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
        initialMessageCount: _messageNotifiers.length,
        isPeerOnline: _isPeerOnline,
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

  bool _wasTyping = false;
  void _onTypingChanged() {
    if (!_typingIndicatorEnabled) return;
    
    final isNotEmpty = _msgController.text.trim().isNotEmpty;
    if (isNotEmpty != _wasTyping) {
      _wasTyping = isNotEmpty;
      SocketService().emitTyping(widget.channelId, widget.peerId, isNotEmpty);
      debugPrint('[Typing] Emitting ${isNotEmpty ? 'start' : 'stop'} to ${widget.peerId}');
    }

    // Auto-stop typing if no changes for 3 seconds (as fallback to server expiry)
    _typingTimer?.cancel();
    if (isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _wasTyping) {
          _wasTyping = false;
          SocketService().emitTyping(widget.channelId, widget.peerId, false);
        }
      });
    }
  }

  @override
  void dispose() {
    _attentionPulseController.dispose();
    // Clear the active chat peer so global game invite banner resumes
    if (SocketService().activeChatPeerId == widget.peerId) {
      SocketService().activeChatPeerId = null;
    }
    // Notify server we stopped viewing this conversation
    SocketService().emitConversationViewing(null);

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
            
            _isPremium = body['user']['is_premium_user'] == true;
            SharedPreferences.getInstance().then((prefs) {
              prefs.setBool('is_premium', _isPremium);
            });
            _e2eEnabled = body['user']['e2e_encryption_enabled'] ?? false;
            _typingIndicatorEnabled = body['user']['typing_indicator_enabled'] ?? true;
            
            // Calculate server time offset
            if (body['server_time'] != null) {
              final serverTime = DateTime.parse(body['server_time']);
              _serverTimeOffset = serverTime.difference(DateTime.now());
            }

            _isAttentionFreeUsed = body['user']['attention_seeker_free_used'] == true;
            final lastAt = body['user']['attention_seeker_last_used'];
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
        
        final body = await compute<String, dynamic>(jsonDecode, res.body);
        final List<dynamic> raw = body['messages'] ?? [];
        
        final List<ValueNotifier<Map<String, dynamic>>> notifiers = [];
        _notifierMap.clear();

        // Group by gameSessionId and only keep the latest for each session
        final Map<String, int> lastGameIndex = {};
        final List<Map<String, dynamic>> processed = [];

        for (var m in raw) {
          final parsed = _parseSingleMessage(m as Map<String, dynamic>);
          final sessionId = parsed['_gameSessionId'];

          if (sessionId != null) {
            if (lastGameIndex.containsKey(sessionId)) {
              // Replace older game message with newer one
              processed[lastGameIndex[sessionId]!] = parsed;
            } else {
              lastGameIndex[sessionId] = processed.length;
              processed.add(parsed);
            }
          } else {
            processed.add(parsed);
          }
        }

        for (var p in processed) {
          final notifier = ValueNotifier(p);
          notifiers.add(notifier);
          _notifierMap[p['id']] = notifier;
        }

        if (mounted) {
          setState(() {
            _messageNotifiers.clear();
            _messageNotifiers.addAll(notifiers);
            _isLoading = false;
          });
          _scrollToBottom(animated: false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final position = _scrollController.position.maxScrollExtent;

      if (animated) {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(position);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    FocusScope.of(context).unfocus();

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = _parseSingleMessage({
      'id': tempId,
      'client_temp_id': tempId,
      'sender_id': _currentUserId,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
      'pending': true,
      'reply_to_id': _replyingTo?['id'],
      'reply_to_content': _replyingTo?['content'],
      'reply_to_sender_id': _replyingTo?['sender_id'],
      'reply_to_message_type': _replyingTo?['message_type'],
    });

    final notifier = ValueNotifier(tempMsg);
    final replyToId = _replyingTo?['id'];

    // --- Fix: Encrypt at send-time if enabled ---
    String finalContent = text;
    if (_e2eEnabled) {
      finalContent = EncryptionHelper.encryptMessage(text);
    }

    setState(() {
      _messageNotifiers.add(notifier);
      _replyingTo = null;
    });
    _scrollToBottom();

    try {
      final res = await ApiService.sendMessage(
        widget.channelId, 
        finalContent, 
        replyToId: replyToId,
        clientTempId: tempId,
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final serverMsg = _parseSingleMessage(body['message']);
        final serverId = serverMsg['id'] as int;
        
        // Update the optimistic notifier with real data
        notifier.value = serverMsg;
        _notifierMap[serverId] = notifier;
      } else {
        notifier.value['failed'] = true;
        notifier.value = {...notifier.value};
      }
    } catch (_) {
      notifier.value['failed'] = true;
      notifier.value = {...notifier.value};
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

      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final tempMsg = _parseSingleMessage({
        'id': tempId,
        'client_temp_id': tempId,
        'sender_id': _currentUserId,
        'content': base64Audio,
        'message_type': 'voice',
        'duration': duration,
        'created_at': DateTime.now().toIso8601String(),
        'pending': true,
      });

      final notifier = ValueNotifier(tempMsg);

      // --- Fix: Encrypt voice at send-time if enabled ---
      String finalContent = base64Audio;
      if (_e2eEnabled) {
        finalContent = EncryptionHelper.encryptMessage(base64Audio);
      }

      setState(() {
        _messageNotifiers.add(notifier);
      });
      _scrollToBottom();

      final res = await ApiService.sendMessage(
        widget.channelId, 
        finalContent, 
        messageType: 'voice', 
        duration: duration,
        clientTempId: tempId,
      );

      if (res.statusCode == 200) {
        final body = await compute<String, dynamic>(jsonDecode, res.body);
        final serverMsg = _parseSingleMessage(body['message']);
        final serverId = serverMsg['id'] as int;
        
        notifier.value = serverMsg;
        _notifierMap[serverId] = notifier;
      } else {
        notifier.value['failed'] = true;
        notifier.value = {...notifier.value};
      }
    } catch (e) {
      print('Error sending voice message: $e');
    }
  }

  void _checkCooldown() {
    if (_lastAttentionSeekerAt == null || !mounted) return;

    final nowServer = DateTime.now().add(_serverTimeOffset);
    final lastUse = _lastAttentionSeekerAt!;
    final diff = nowServer.difference(lastUse);
    final cooldown = _isPremium ? const Duration(minutes: 15) : const Duration(days: 9999);

    if (diff < cooldown) {
      final remaining = cooldown - diff;
      String label;
      if (!_isPremium) {
        label = 'Used';
      } else {
        final m = remaining.inMinutes;
        final s = remaining.inSeconds % 60;
        label = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      }
      
      if (label != _cooldownRemaining || !_isAttentionCooldownActive) {
        setState(() {
          _isAttentionCooldownActive = true;
          _cooldownRemaining = label;
        });
      }
    } else {
      // Cooldown expired for premium users
      if (_isAttentionCooldownActive && _isPremium) {
        setState(() {
          _isAttentionCooldownActive = false;
          _cooldownRemaining = '';
        });
      }
      // For non-premium, once used, it stays active (disabled)
      if (!_isPremium && _isAttentionFreeUsed) {
        setState(() {
          _isAttentionCooldownActive = true;
          _cooldownRemaining = 'Used';
        });
      }
    }
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

  Widget _buildBubbleWithDate(BuildContext context, int index) {
    final notifier = _messageNotifiers[index];
    final msg = notifier.value;
    final isMe = msg['sender_id'].toString() == _currentUserId.toString();
    final isFailed = msg['failed'] == true;
    
    bool isGrouped = false;
    if (index > 0) {
      final youngerMsg = _messageNotifiers[index - 1].value;
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
    if (index == 0) {
      showDateDivider = true;
    } else {
      final olderMsg = _messageNotifiers[index - 1].value;
      final olderDate = olderMsg['_parsed_date'] as DateTime?;
      final currDate = msg['_parsed_date'] as DateTime?;
      if (olderDate != null && currDate != null) {
        if (olderDate.year != currDate.year || olderDate.month != currDate.month || olderDate.day != currDate.day) {
          showDateDivider = true;
        }
      }
    }

    final content = _OptimizedChatBubble(
      messageNotifier: notifier,
      isMe: isMe,
      isFailed: isFailed,
      isGrouped: isGrouped,
      screenWidth: MediaQuery.of(context).size.width,
      onReply: () => setState(() => _replyingTo = msg),
      onReactionSelected: (reaction) {
        SocketService().emitReactionAdd(msg['id'], reaction, widget.peerId);
      },
      currentUserId: _currentUserId ?? '',
      peerName: widget.peerName,
      gameCardBuilder: _buildGameStatusCard,
    );

    if (showDateDivider) {
      return Column(
        children: [
          _buildDateDivider(msg['created_at']),
          content,
        ],
      );
    }
    return content;
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
                        if (_isPeerPremium) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.workspace_premium, size: 10, color: Colors.black),
                          ),
                        ],
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
      body: Stack(
        children: [
          // Background is now solid black as requested
          Positioned.fill(
            child: Container(color: Colors.black),
          ),
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
                children: [
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
                        : RepaintBoundary(
                            child: StreamBuilder<Map<String, dynamic>>(
                              stream: SocketService().messageStatusStream,
                              builder: (context, _) {
                                return ListView.builder(
                                  controller: _scrollController,
                                  reverse: false,
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  itemCount: _messageNotifiers.length + (_e2eEnabled ? 1 : 0),
                                  cacheExtent: 800,
                                  addAutomaticKeepAlives: false,
                                  addRepaintBoundaries: true,
                                  itemBuilder: (context, index) {
                                    if (_e2eEnabled) {
                                      if (index == 0) {
                                        // Encryption Notice (Chip style) - Very top
                                        return Center(
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.03),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 14),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Messages are end-to-end encrypted',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white38,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      return _buildBubbleWithDate(context, index - 1);
                                    }
                                    
                                    return _buildBubbleWithDate(context, index);
                                  },
                                );
                              }
                            ),
                          ),
                  ),
                  if (_replyingTo != null) _buildReplyPreview(),
                  _buildAttentionSeekerButton(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2B2E).withOpacity(0.8),
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
                                    if (_isRecording)
                                      const Icon(Icons.mic, color: Colors.redAccent, size: 20)
                                          .animate(onPlay: (controller) => controller.repeat())
                                          .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 600.ms, curve: Curves.easeInOut)
                                          .then()
                                          .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1), duration: 600.ms, curve: Curves.easeInOut)
                                    else
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
                                    hintText: 'Whisper something Delulu...',
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
                                    // Horizontal swipe to cancel
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
                                    
                                    // Vertical swipe to lock
                                    if (details.offsetFromOrigin.dy < -80) {
                                      setState(() {
                                        _isRecordingLocked = true;
                                        _isRecordingCancelled = false;
                                      });
                                      _triggerVibrationShort();
                                      _showCustomToast('Recording locked', isError: false);
                                    }
                                  }
                                },
                                onLongPressEnd: (details) {
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
            ),
        ],
      ),
    );
  }

  // Consolidated with top-level version

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
    final Map<String, dynamic> data = (msg['_parsed_game_data'] is Map) 
        ? Map<String, dynamic>.from(msg['_parsed_game_data'] as Map) 
        : {};
    final isMe = msg['sender_id'].toString() == _currentUserId.toString();

    final status = data['status'] ?? 'unknown';
    final gameName = data['gameName'] ?? 'Game';
    final sessionId = data['sessionId'];

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'accepted':
      case 'completed':
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
      case 'missed':
        statusColor = Colors.white54;
        statusText = 'Invitation Missed';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.white38;
        statusText = 'Game Status';
        statusIcon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
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
          if (status == 'pending' && !isMe) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                SocketService().emitGameInviteResponse(
                  widget.channelId,
                  widget.peerId,
                  data['gameId'] ?? '',
                  gameName,
                  sessionId ?? '',
                  true
                );
                _navigateToGame(data['gameId'] ?? '', gameName, sessionId: sessionId);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.tertiary]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                  ],
                ),
                child: Center(
                  child: Text(
                    "I'M IN",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ],
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

  Widget _buildAttentionSeekerButton() {
    final bool isDisabled = (!_isPremium && _isAttentionFreeUsed) || (_isPremium && _isAttentionCooldownActive);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tooltip(
        message: isDisabled && !_isPremium ? 'Upgrade to Rizz+ for unlimited Attention Seeker' : '',
        preferBelow: false,
        triggerMode: TooltipTriggerMode.tap,
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        child: GestureDetector(
          onTap: isDisabled ? null : _handleAttentionSeeker,
          child: ScaleTransition(
            scale: isDisabled ? const AlwaysStoppedAnimation(1.0) : _attentionPulseAnimation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isDisabled ? 110 : 54, 
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(27),
                gradient: LinearGradient(
                  colors: isDisabled
                      ? [const Color(0xFF1F2937), const Color(0xFF111827)]
                      : [AppColors.primary, AppColors.tertiary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDisabled ? Colors.black45 : AppColors.primary.withOpacity(0.6)),
                    blurRadius: isDisabled ? 4 : 20,
                    spreadRadius: isDisabled ? 1 : 2,
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isDisabled && _isPremium ? Icons.timer_outlined : Icons.vibration,
                      color: isDisabled ? Colors.white24 : Colors.white,
                      size: 24,
                    ),
                    if (isDisabled) ...[
                      const SizedBox(width: 8),
                      Text(
                        _cooldownRemaining,
                        style: GoogleFonts.inter(
                          fontSize: 13, 
                          color: Colors.white60, 
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleAttentionSeeker() {
    if (_isAttentionCooldownActive) return;
    SocketService().emitAttentionSeeker(widget.peerId);
    HapticFeedback.heavyImpact();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkCooldown();
    });
  }

  void _loadPersistedCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('last_attention_${widget.peerId}');
    if (saved != null) {
      final dt = DateTime.parse(saved);
      if (mounted) {
        setState(() {
          _lastAttentionSeekerAt = dt;
          _startCooldownTimer();
        });
      }
    }
  }

  void _scrollToMessage(int id) {
    // Basic implementation: find index and scroll
    final index = _messageNotifiers.indexWhere((n) => n.value['id'] == id);
    if (index != -1 && _scrollController.hasClients) {
       // Estimate height - not perfect but works for simple lists
       _scrollController.animateTo(
         index * 100.0, 
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
const _theirColor = Color(0x14FFFFFF); 

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
