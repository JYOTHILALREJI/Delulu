import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/blurred_image.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final response = await Supabase.instance.client
        .from('connection_requests')
        .select('*, from_user:profiles!from_user(*)')
        .eq('to_user', userId)
        .eq('status', 'pending');
    setState(() {
      _requests = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
    });
  }

  Future<void> _respond(String requestId, String status) async {
    await Supabase.instance.client
        .from('connection_requests')
        .update({'status': status})
        .eq('id', requestId);
    _fetchRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection Requests')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(child: Text('No pending requests'))
              : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    final profile = req['from_user'];
                    return ListTile(
                      leading: BlurredImage(
                        imageUrl: (profile['photos'] as List?)?.isNotEmpty == true
                            ? profile['photos'][0]
                            : '',
                        width: 50,
                        height: 50,
                        blur: true,
                      ),
                      title: Text(profile['name'] ?? 'Unknown'),
                      subtitle: Text(profile['bio'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _respond(req['id'], 'accepted'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _respond(req['id'], 'rejected'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}