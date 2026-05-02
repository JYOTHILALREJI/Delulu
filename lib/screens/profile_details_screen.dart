import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../wiggets/blurred_image.dart';
import '../utils/constants.dart';

class ProfileDetailsScreen extends StatefulWidget {
  final String userId;
  const ProfileDetailsScreen({super.key, required this.userId});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', widget.userId)
        .single();
    setState(() {
      _profile = response;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile!;
    return Scaffold(
      appBar: AppBar(title: Text(profile['name'] ?? 'Profile')),
      body: SingleChildScrollView(
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
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(profile['bio'] ?? 'No bio', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Interests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: (List<String>.from(profile['interests'] ?? []))
                  .map((i) => Chip(label: Text('#$i')))
                  .toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendConnectionRequest(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Connect'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendConnectionRequest() async {
    final fromUserId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('connection_requests').insert({
      'from_user': fromUserId,
      'to_user': widget.userId,
      'status': 'pending',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection request sent')),
      );
      Navigator.pop(context);
    }
  }
}