import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/attention_seeker_button.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String peerId;
  const ChatScreen({super.key, required this.roomId, required this.peerId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  late IO.Socket _socket;
  bool _isTyping = false;
  bool _peerTyping = false;
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser!.id;
    _initSocket();
    _fetchMessages();
    _markMessagesAsRead();
  }

  void _initSocket() {
    _socket = IO.io('http://localhost:3001', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });
    _socket.connect();
    _socket.emit('join_chat', widget.roomId);
    _socket.on('new_message', (data) {
      setState(() {
        _messages.add(data);
      });
      NotificationService.showNotification(
        'New message',
        data['content'],
      );
    });
    _socket.on('user_typing', (data) {
      setState(() => _peerTyping = true);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _peerTyping = false);
      });
    });
  }

  Future<void> _fetchMessages() async {
    final response = await Supabase.instance.client
        .from('messages')
        .select()
        .eq('room_id', widget.roomId)
        .order('created_at', ascending: true);
    setState(() {
      _messages.addAll(List<Map<String, dynamic>>.from(response));
    });
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty) return;
    final content = _textController.text;
    final message = {
      'room_id': widget.roomId,
      'sender_id': _currentUserId,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    };
    await Supabase.instance.client.from('messages').insert(message);
    _socket.emit('send_message', {
      'roomId': widget.roomId,
      'message': content,
      'userId': _currentUserId,
    });
    _textController.clear();
    _fetchMessages(); // refresh
  }

  Future<void> _sendFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = File(result.files.single.path!);
      final url = await StorageService.uploadFile(file);
      await Supabase.instance.client.from('messages').insert({
        'room_id': widget.roomId,
        'sender_id': _currentUserId,
        'content': url,
        'file_url': url,
        'file_type': result.files.single.extension,
      });
      _fetchMessages();
    }
  }

  void _markMessagesAsRead() {
    // Update read receipts – simplified
  }

  void _onTyping() {
    if (!_isTyping) {
      _isTyping = true;
      _socket.emit('typing', {'roomId': widget.roomId, 'userId': _currentUserId});
      Future.delayed(const Duration(seconds: 1), () {
        _isTyping = false;
      });
    }
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              context.go('/call/${widget.roomId}/${widget.peerId}');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_peerTyping)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('typing...', style: TextStyle(fontStyle: FontStyle.italic)),
            ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages.reversed.toList()[index];
                final isMe = msg['sender_id'] == _currentUserId;
                return MessageBubble(
                  message: msg['content'],
                  isMe: isMe,
                  timestamp: msg['created_at'],
                );
              },
            ),
          ),
          AttentionSeekerButton(
            peerId: widget.peerId,
            socket: _socket,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _sendFile,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onChanged: (_) => _onTyping(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}