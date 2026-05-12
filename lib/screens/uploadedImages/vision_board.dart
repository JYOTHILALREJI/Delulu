import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../components/delulu_wavy_loader.dart';

class VisionBoardScreen extends StatefulWidget {
  const VisionBoardScreen({super.key});

  @override
  State<VisionBoardScreen> createState() => _VisionBoardScreenState();
}

class _VisionBoardScreenState extends State<VisionBoardScreen> {
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final res = await ApiService.getMe();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final photosData = body['user']['photos'];
        setState(() {
          if (photosData is String) {
            _photos = (jsonDecode(photosData) as List).map((p) => Map<String, dynamic>.from(p)).toList();
          } else if (photosData is List) {
            _photos = photosData.map((p) => Map<String, dynamic>.from(p)).toList();
          }
          
          // Ensure keys match (legacy data might have 'is_blurred')
          for (var p in _photos) {
            if (p.containsKey('is_blurred') && !p.containsKey('is_private')) {
              p['is_private'] = p['is_blurred'];
            }
          }
          
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading photos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePhotos() async {
    try {
      final res = await ApiService.saveProfile({'photos': _photos});
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vision Board updated!')),
          );
        }
      } else {
        final body = jsonDecode(res.body);
        throw Exception(body['error'] ?? 'Server returned ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update Vision Board: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _togglePrimary(int index) {
    if (_photos[index]['is_private'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Private images cannot be set as primary.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _photos = _photos.asMap().entries.map((entry) {
        final i = entry.key;
        final photo = Map<String, dynamic>.from(entry.value);
        photo['is_primary'] = (i == index);
        return photo;
      }).toList();
    });
    _savePhotos();
  }

  void _togglePrivate(int index) {
    if (index < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The first 3 photos in your Vision Board must remain public.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final bool willBePrivate = !(_photos[index]['is_private'] ?? false);
    
    if (willBePrivate && _photos[index]['is_primary'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set another photo as primary before making this one private.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _photos[index] = Map<String, dynamic>.from(_photos[index]);
      _photos[index]['is_private'] = willBePrivate;
    });
    _savePhotos();
  }

  Future<void> _pickAndAddImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      
      setState(() {
        _photos.add({
          'url': base64,
          'is_private': false,
          'is_primary': false,
        });
      });
      _savePhotos();
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _photos.removeAt(oldIndex);
      _photos.insert(newIndex, item);
      
      // Auto-fix privacy: If a private photo is moved to the first 3 slots, make it public
      for (int i = 0; i < _photos.length; i++) {
        if (i < 3 && _photos[i]['is_private'] == true) {
          _photos[i] = Map<String, dynamic>.from(_photos[i]);
          _photos[i]['is_private'] = false;
        }
      }
    });
    _savePhotos();
  }

  void _deletePhoto(int index) {
    if (_photos[index]['is_primary'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set another photo as primary before deleting this one.')),
      );
      return;
    }

    setState(() {
      _photos.removeAt(index);
    });
    _savePhotos();
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: url.startsWith('data:image')
                    ? Image.memory(base64Decode(url.split(',').last), fit: BoxFit.contain)
                    : CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianEdge,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Vision Board',
          style: GoogleFonts.beVietnamPro(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: DeluluWavyLoader())
          : ReorderableGridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: _photos.length + (_photos.length < 6 ? 1 : 0),
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                if (index == _photos.length) {
                  return _buildAddButton(key: ValueKey('add_button'));
                }

                final photo = _photos[index];
                final url = photo['url'];
                final isPrimary = photo['is_primary'] == true;
                final isPrivate = photo['is_private'] == true;

                return GestureDetector(
                  key: ValueKey(url),
                  onTap: () => _showFullImage(url),
                  child: Stack(
                    children: [
                      // Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            url.startsWith('data:image')
                                ? Image.memory(base64Decode(url.split(',').last), fit: BoxFit.cover)
                                : CachedNetworkImage(
                                    imageUrl: url, 
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(child: DeluluWavyLoader(fontSize: 14)),
                                  ),
                            if (isPrivate)
                              BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(color: Colors.black.withValues(alpha: 0.2)),
                              ),
                          ],
                        ),
                      ),
                      // Private Overlay Label
                      if (isPrivate)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'PRIVATE',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Primary Tag
                      if (isPrimary)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PRIMARY',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      // Controls Overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                            ),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isPrimary ? Icons.star : Icons.star_border,
                                  color: isPrimary ? Colors.amber : Colors.white,
                                  size: 20,
                                ),
                                onPressed: () => _togglePrimary(index),
                              ),
                              if (index >= 3)
                                IconButton(
                                  icon: Icon(
                                    isPrivate ? Icons.visibility_off : Icons.visibility,
                                    color: isPrivate ? AppColors.primary : Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () => _togglePrivate(index),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _deletePhoto(index),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAddButton({required Key key}) {
    return GestureDetector(
      key: key,
      onTap: _pickAndAddImage,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              'Add Photo',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_photos.length}/6',
              style: GoogleFonts.inter(
                color: Colors.white24,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
