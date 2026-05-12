import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  
  // Streams for real-time updates
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

  Map<String, dynamic>? _lastInviteSent;
  Map<String, dynamic>? get lastInviteSent => _lastInviteSent;

  /// Set to the peerId of the currently open ChatScreen.
  /// GlobalWrapper uses this to decide whether to show the top banner.
  String? activeChatPeerId;

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

  bool get connected => _socket?.connected ?? false;

  void emitTyping(int channelId, String peerId, bool isTyping) {
    _socket?.emit('typing', {
      'channelId': channelId,
      'peerId': peerId,
      'isTyping': isTyping,
    });
  }

  void emitAttentionSeeker(String peerId) {
    _socket?.emit('attention_seeker', {
      'peerId': peerId,
    });
  }

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

  void emitGameSessionUpdate(String sessionId, int duration) {
    _socket?.emit('game_session_update', {
      'sessionId': sessionId,
      'duration': duration,
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

  Stream<Map<String, dynamic>> get newMessageStream => _messageController.stream;

  void emitGameSelectChoice(String sessionId, String choice, String peerId) {
    print('[SocketService] Emitting game_select_choice: $choice for session $sessionId');
    _socket?.emit('game_select_choice', {
      'sessionId': sessionId,
      'choice': choice,
      'peerId': peerId,
    });
  }

  void emitGameSendQuestion(String sessionId, String question, String peerId) {
    print('[SocketService] Emitting game_send_question: $question');
    _socket?.emit('game_send_question', {
      'sessionId': sessionId,
      'question': question,
      'peerId': peerId,
    });
  }

  void emitSubmitAnswer(String sessionId, String answer, String peerId, String type, {int duration = 0}) {
    print('[SocketService] Emitting game_submit_answer: $type');
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
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket!.on('new_message', (data) {
      _messageController.add(data);
    });

    _socket!.on('unread_update', (data) {
      _unreadController.add(data);
    });

    _socket!.on('message_read', (data) {
      _readReceiptController.add(data);
    });

    _socket!.on('typing_status', (data) {
      _typingController.add(data);
    });

    _socket!.on('user_status', (data) {
      _statusController.add(data);
    });

    _socket!.on('attention_seeker_received', (data) {
      _attentionController.add(data);
    });

    _socket!.on('game_invite_received', (data) {
      _gameInviteController.add(data);
    });

    _socket!.on('game_invite_sent', (data) {
      _lastInviteSent = data;
      _gameInviteSentController.add(data);
    });

    _socket!.on('game_invite_response_received', (data) {
      _gameInviteResponseController.add(data);
    });

    _socket!.on('game_cancelled', (data) {
      _gameCancelledController.add(data);
    });

    _socket!.on('game_state_synced', (data) {
      _gameStateController.add(data);
    });

    _socket!.on('game_points_synced', (data) {
      _gamePointsController.add(data);
    });

    _socket!.on('message_updated', (data) {
      _messageUpdateController.add(data);
    });

    _socket!.on('game_ended_by_peer', (data) {
      _gameEndController.add(data);
    });

    _socket!.on('game_invite_missed', (data) {
      _gameMissedController.add(data);
    });

    _socket!.on('error_message', (data) {
      _errorController.add(data);
    });

    _socket!.on('new_game_message', (data) {
      try {
        _gameMessageController.add(Map<String, dynamic>.from(data as Map));
      } catch (e) {
        print('[SocketService] Error mapping new_game_message: $e');
      }
    });

    _socket!.onConnectError((err) => print('Socket Connect Error: $err'));
    _socket!.onError((err) => print('Socket Error: $err'));
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void dispose() {
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
    disconnect();
  }
}
