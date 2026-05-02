import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  List<String> _interests = [];
  List<String> _existingPhotos = [];
  List<XFile> _newPhotos = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    setState(() {
      _nameController.text = response['name'] ?? '';
      _ageController.text = (response['age'] ?? 0).toString();
      _bioController.text = response['bio'] ?? '';
      _interests = List<String>.from(response['interests'] ?? []);
      _existingPhotos = List<String>.from(response['photos'] ?? []);
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _newPhotos.add(image));
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final List<String> allPhotos = List.from(_existingPhotos);
    for (final photo in _newPhotos) {
      final url = await StorageService.uploadFile(File(photo.path));
      allPhotos.add(url);
    }
    final userId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('profiles').update({
      'name': _nameController.text,
      'age': int.parse(_ageController.text),
      'bio': _bioController.text,
      'interests': _interests,
      'photos': allPhotos,
    }).eq('id', userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      context.go('/profile-settings');
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ageController,
                    decoration: const InputDecoration(labelText: 'Age'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bioController,
                    decoration: const InputDecoration(labelText: 'Bio'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  const Text('Interests (comma separated)'),
                  TextField(
                    onSubmitted: (value) {
                      final newInterests = value.split(',').map((e) => e.trim()).toList();
                      setState(() => _interests.addAll(newInterests));
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _interests.map((i) => Chip(
                      label: Text(i),
                      onDeleted: () => setState(() => _interests.remove(i)),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Photos'),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _existingPhotos.length + _newPhotos.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _existingPhotos.length + _newPhotos.length) {
                        return GestureDetector(
                          onTap: _pickImage,
                          child: Container(color: Colors.grey[800], child: const Icon(Icons.add)),
                        );
                      }
                      final isExisting = index < _existingPhotos.length;
                      final imageUrl = isExisting
                          ? _existingPhotos[index]
                          : _newPhotos[index - _existingPhotos.length].path;
                      return Image.network(imageUrl, fit: BoxFit.cover);
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isSaving ? const CircularProgressIndicator() : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
    );
  }
}