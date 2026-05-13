import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  Timer? _heartbeatTimer;
  Timer? _typingDebounce;
  bool _isTyping = false;

  // Streams
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _unreadController = StreamController<Map<String, dynamic>>.broadcast();
  final _readReceiptController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _attentionController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameInviteController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameInviteSentController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameInviteResponseController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameCancelledController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameStateController = StreamController<Map<String, dynamic>>.broadcast();
  final _gamePointsController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameEndController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameMissedController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _reactionController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get unreadStream => _unreadController.stream;
  Stream<Map<String, dynamic>> get readReceiptStream => _readReceiptController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get attentionStream => _attentionController.stream;
  Stream<Map<String, dynamic>> get gameInviteStream => _gameInviteController.stream;
  Stream<Map<String, dynamic>> get gameInviteSentStream => _gameInviteSentController.stream;
  Stream<Map<String, dynamic>> get gameInviteResponseStream => _gameInviteResponseController.stream;
  Stream<Map<String, dynamic>> get gameCancelledStream => _gameCancelledController.stream;
  Stream<Map<String, dynamic>> get gameStateStream => _gameStateController.stream;
  Stream<Map<String, dynamic>> get gamePointsStream => _gamePointsController.stream;
  Stream<Map<String, dynamic>> get gameEndStream => _gameEndController.stream;
  Stream<Map<String, dynamic>> get messageUpdateStream => _messageUpdateController.stream;
  Stream<Map<String, dynamic>> get gameMissedStream => _gameMissedController.stream;
  Stream<Map<String, dynamic>> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get newGameMessageStream => _gameMessageController.stream;
  Stream<Map<String, dynamic>> get reactionStream => _reactionController.stream;

  String? activeChatPeerId;
  bool get connected => _socket?.connected ?? false;

  // --- Typing with debounce & auto-stop ---
  void emitTyping(int channelId, String peerId, bool isTyping) {
    if (!isTyping) {
      _typingDebounce?.cancel();
      if (_isTyping) {
        _socket?.emit('typing:stop', {'channelId': channelId, 'peerId': peerId});
        _isTyping = false;
      }
      return;
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!_isTyping) {
        _socket?.emit('typing:start', {'channelId': channelId, 'peerId': peerId});
        _isTyping = true;
      }
    });

    // Auto-stop after 4 seconds if no new typing
    Timer(const Duration(seconds: 4), () {
      if (_isTyping) {
        _socket?.emit('typing:stop', {'channelId': channelId, 'peerId': peerId});
        _isTyping = false;
      }
    });
  }

  void emitConversationViewing(int? channelId) {
    _socket?.emit('conversation:viewing', {'channelId': channelId});
  }

  void emitAttentionSeeker(String peerId) {
    _socket?.emit('attention_seeker', {'peerId': peerId});
  }

  void emitReactionAdd(int messageId, String reaction, String peerId) {
    _socket?.emit('reaction:add', {'messageId': messageId, 'reaction': reaction, 'peerId': peerId});
  }

  void emitReactionRemove(int messageId, String peerId) {
    _socket?.emit('reaction:remove', {'messageId': messageId, 'peerId': peerId});
  }

  // --- Game methods ---
  void emitGameInvite(int channelId, String peerId, String gameId, String gameName) {
    _socket?.emit('game_invite', {
      'channelId': channelId,
      'peerId': peerId,
      'gameId': gameId,
      'gameName': gameName,
    });
  }

  void emitGameInviteResponse(int channelId, String peerId, String gameId, String gameName, String sessionId, bool accepted) {
    _socket?.emit('game_invite_response', {
      'channelId': channelId,
      'peerId': peerId,
      'gameId': gameId,
      'gameName': gameName,
      'sessionId': sessionId,
      'accepted': accepted,
    });
  }

  void emitGameCancel(int channelId, String peerId, String sessionId) {
    _socket?.emit('game_cancel', {
      'channelId': channelId,
      'peerId': peerId,
      'sessionId': sessionId,
    });
  }

  void emitGameStateUpdate(String sessionId, Map<String, dynamic> state, String peerId) {
    _socket?.emit('game_state_update', {
      'sessionId': sessionId,
      'state': state,
      'peerId': peerId,
    });
  }

  void emitGamePointUpdate(String sessionId, String userId, int points, String peerId) {
    _socket?.emit('game_point_update', {
      'sessionId': sessionId,
      'userId': userId,
      'points': points,
      'peerId': peerId,
    });
  }

  void emitGameSelectChoice(String sessionId, String choice, String peerId) {
    _socket?.emit('game_select_choice', {
      'sessionId': sessionId,
      'choice': choice,
      'peerId': peerId,
    });
  }

  void emitGameSendQuestion(String sessionId, String question, String peerId) {
    _socket?.emit('game_send_question', {
      'sessionId': sessionId,
      'question': question,
      'peerId': peerId,
    });
  }

  void emitSubmitAnswer(String sessionId, String answer, String peerId, String type, {int duration = 0}) {
    _socket?.emit('game_submit_answer', {
      'sessionId': sessionId,
      'answer': answer,
      'peerId': peerId,
      'type': type,
      'duration': duration,
    });
  }

  void emitGameEnd(int channelId, String peerId, String sessionId) {
    _socket?.emit('game_end', {
      'channelId': channelId,
      'peerId': peerId,
      'sessionId': sessionId,
    });
  }

  // --- Connection & Heartbeat ---
  void connect() async {
    if (_socket != null && _socket!.connected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    _socket = io.io(ApiService.baseUrl.replaceFirst('/api', ''), {
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token}
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Socket connected: ${_socket!.id}');
      _startHeartbeat();
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
      _stopHeartbeat();
    });

    // Event listeners
    _socket!.on('new_message', (data) => _messageController.add(data));
    _socket!.on('unread_update', (data) => _unreadController.add(data));
    _socket!.on('message_read', (data) => _readReceiptController.add(data));
    _socket!.on('typing_status', (data) => _typingController.add(data));
    _socket!.on('user_status', (data) => _statusController.add(data));
    _socket!.on('attention_seeker_received', (data) => _attentionController.add(data));
    _socket!.on('game_invite_received', (data) => _gameInviteController.add(data));
    _socket!.on('game_invite_sent', (data) => _gameInviteSentController.add(data));
    _socket!.on('game_invite_response_received', (data) => _gameInviteResponseController.add(data));
    _socket!.on('game_cancelled', (data) => _gameCancelledController.add(data));
    _socket!.on('game_state_synced', (data) => _gameStateController.add(data));
    _socket!.on('game_points_synced', (data) => _gamePointsController.add(data));
    _socket!.on('message_updated', (data) => _messageUpdateController.add(data));
    _socket!.on('game_ended_by_peer', (data) => _gameEndController.add(data));
    _socket!.on('game_invite_missed', (data) => _gameMissedController.add(data));
    _socket!.on('error_message', (data) => _errorController.add(data));
    _socket!.on('new_game_message', (data) => _gameMessageController.add(data));
    _socket!.on('reaction_updated', (data) => _reactionController.add(data));
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_socket != null && _socket!.connected) {
        _socket!.emit('presence:heartbeat');
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void dispose() {
    _typingDebounce?.cancel();
    _messageController.close();
    _unreadController.close();
    _readReceiptController.close();
    _typingController.close();
    _statusController.close();
    _attentionController.close();
    _gameInviteController.close();
    _gameInviteSentController.close();
    _gameInviteResponseController.close();
    _gameCancelledController.close();
    _gameStateController.close();
    _gamePointsController.close();
    _gameEndController.close();
    _messageUpdateController.close();
    _gameMissedController.close();
    _errorController.close();
    _gameMessageController.close();
    _reactionController.close();
    disconnect();
  }
}
