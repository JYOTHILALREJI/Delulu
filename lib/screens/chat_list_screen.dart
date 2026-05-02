import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChats();
  }

  Future<void> _fetchChats() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    // Get accepted connections
    final response = await Supabase.instance.client
        .from('connection_requests')
        .select('*, from_user:profiles!from_user(*), to_user:profiles!to_user(*)')
        .or('from_user.eq.$userId,to_user.eq.$userId')
        .eq('status', 'accepted');
    final requests = List<Map<String, dynamic>>.from(response);
    final List<Map<String, dynamic>> chats = [];
    for (var req in requests) {
      final peer = req['from_user']['id'] == userId
          ? req['to_user']
          : req['from_user'];
      chats.add({
        'roomId': '${userId}_${peer['id']}',
        'peerId': peer['id'],
        'peerName': peer['name'],
        'peerPhoto': (peer['photos'] as List?)?.isNotEmpty == true
            ? peer['photos'][0]
            : '',
      });
    }
    setState(() {
      _chats = chats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? const Center(child: Text('No connections yet'))
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: chat['peerPhoto'].toString().isNotEmpty
                            ? NetworkImage(chat['peerPhoto'])
                            : null,
                        child: chat['peerPhoto'].toString().isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(chat['peerName']),
                      onTap: () {
                        context.go(
                          '/chat/${chat['roomId']}/${chat['peerId']}',
                        );
                      },
                    );
                  },
                ),
    );
  }
}