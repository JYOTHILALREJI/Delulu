import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    setState(() {
      _profile = response;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: (_profile?['photos'] as List?)?.isNotEmpty == true
                            ? NetworkImage(_profile!['photos'][0])
                            : null,
                        child: const Icon(Icons.person, size: 50),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_profile?['name']}, ${_profile?['age']}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_profile?['is_verified'] == true)
                        const Chip(
                          label: Text('Verified'),
                          avatar: Icon(Icons.verified, size: 16),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Profile'),
                  onTap: () => context.go('/edit-profile'),
                ),
                ListTile(
                  leading: const Icon(Icons.star),
                  title: const Text('Upgrade to Premium'),
                  onTap: () => context.go('/premium'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: _logout,
                ),
              ],
            ),
    );
  }
}