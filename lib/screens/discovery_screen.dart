import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../widgets/blurred_image.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  List<Map<String, dynamic>> _profiles = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  Future<void> _fetchProfiles() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    // 60/40 matching dummy: fetch all except self
    final response = await Supabase.instance.client
        .from('profiles')
        .select('*')
        .neq('id', userId);
    final allProfiles = List<Map<String, dynamic>>.from(response);
    // TODO: implement 60% interest sort + 40% random
    setState(() {
      _profiles = allProfiles;
      _isLoading = false;
    });
  }

  void _nextProfile() {
    if (_currentIndex < _profiles.length - 1) {
      setState(() => _currentIndex++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more profiles')),
      );
    }
  }

  Future<void> _sendConnectionRequest(String toUserId) async {
    final fromUserId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('connection_requests').insert({
      'from_user': fromUserId,
      'to_user': toUserId,
      'status': 'pending',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connection request sent')),
    );
    _nextProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profiles.isEmpty) {
      return const Scaffold(body: Center(child: Text('No profiles found')));
    }
    final profile = _profiles[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delulu'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => context.go('/chat-list'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.go('/profile-settings'),
          ),
        ],
      ),
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! < -10) _nextProfile();
        },
        child: Card(
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: BlurredImage(
                    imageUrl: (profile['photos'] as List?)?.isNotEmpty == true
                        ? profile['photos'][0]
                        : '',
                    width: 200,
                    height: 200,
                    blur: true,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${profile['name']}, ${profile['age']}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Distance: ${(profile['distance'] ?? 5).toString()} km',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: (List<String>.from(profile['interests'] ?? []))
                      .map((i) => Chip(label: Text('#$i')))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text(profile['bio'] ?? 'No bio'),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _nextProfile,
                      icon: const Icon(Icons.close, size: 40, color: Colors.red),
                    ),
                    IconButton(
                      onPressed: () => _sendConnectionRequest(profile['id']),
                      icon: const Icon(Icons.favorite, size: 40, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Requests'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          if (index == 1) context.go('/requests');
          if (index == 2) context.go('/chat-list');
          if (index == 3) context.go('/profile-settings');
        },
      ),
    );
  }
}