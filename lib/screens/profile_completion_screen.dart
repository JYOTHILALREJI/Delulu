import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/storage_service.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Prefer not to say';
  final List<String> _interestedIn = [];
  final List<String> _interests = [];
  final _bioController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 6) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImages.add(image);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least 3 photos')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Upload images to R2 (or Supabase storage)
      List<String> photoUrls = [];
      for (var image in _selectedImages) {
        final url = await StorageService.uploadFile(File(image.path));
        photoUrls.add(url);
      }

      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profiles').insert({
        'id': userId,
        'name': _nameController.text,
        'age': int.parse(_ageController.text),
        'gender': _selectedGender,
        'interested_in': _interestedIn,
        'interests': _interests,
        'bio': _bioController.text,
        'photos': photoUrls,
        'location': null, // will be set later
        'is_verified': false,
      });

      if (!mounted) return;
      context.go('/face-verification');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(labelText: 'Age'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const Text('Gender'),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  items: ['Man', 'Woman', 'Non-binary', 'Prefer not to say']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedGender = v!),
                ),
                const SizedBox(height: 16),
                const Text('Interested In'),
                Wrap(
                  children: ['Men', 'Women', 'Everyone'].map((choice) {
                    return ChoiceChip(
                      label: Text(choice),
                      selected: _interestedIn.contains(choice),
                      onSelected: (selected) {
                        setState(() {
                          if (selected && !_interestedIn.contains(choice)) {
                            _interestedIn.add(choice);
                          } else {
                            _interestedIn.remove(choice);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Custom Interests (comma separated)'),
                TextFormField(
                  onFieldSubmitted: (value) {
                    final newInterests = value
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                    setState(() {
                      _interests.addAll(newInterests);
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'e.g., Travel, Coffee, Hiking',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _interests.map((interest) {
                    return Chip(
                      label: Text(interest),
                      onDeleted: () {
                        setState(() {
                          _interests.remove(interest);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(labelText: 'Bio (max 200)'),
                  maxLength: 200,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('Photos (3-6)'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _selectedImages.length +
                      (_selectedImages.length < 6 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _selectedImages.length) {
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.add),
                        ),
                      );
                    }
                    return Image.file(
                      File(_selectedImages[index].path),
                      fit: BoxFit.cover,
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFBD00FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Enter the Dream'),
        ),
      ),
    );
  }
}