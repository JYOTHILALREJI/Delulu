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

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get unreadStream => _unreadController.stream;
  Stream<Map<String, dynamic>> get readReceiptStream => _readReceiptController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get attentionStream => _attentionController.stream;

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

  void connect() async {
    if (_socket != null && _socket!.connected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

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
    disconnect();
  }
}
