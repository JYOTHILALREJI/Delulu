import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

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
            _photos = List<Map<String, dynamic>>.from(jsonDecode(photosData));
          } else if (photosData is List) {
            _photos = List<Map<String, dynamic>>.from(photosData);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePhotos() async {
    try {
      await ApiService.saveProfile({'photos': _photos});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vision Board updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update Vision Board')),
        );
      }
    }
  }

  void _togglePrimary(int index) {
    setState(() {
      for (int i = 0; i < _photos.length; i++) {
        _photos[i]['is_primary'] = (i == index);
      }
    });
    _savePhotos();
  }

  void _toggleBlur(int index) {
    setState(() {
      _photos[index]['is_blurred'] = !(_photos[index]['is_blurred'] ?? false);
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  final url = photo['url'];
                  final isPrimary = photo['is_primary'] == true;
                  final isBlurred = photo['is_blurred'] == true;
                  final isLastThree = index >= _photos.length - 3;

                  return GestureDetector(
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
                                  : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                              if (isBlurred)
                                BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(color: Colors.black.withValues(alpha: 0.2)),
                                ),
                            ],
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
                                if (isLastThree)
                                  IconButton(
                                    icon: Icon(
                                      isBlurred ? Icons.blur_on : Icons.blur_off,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () => _toggleBlur(index),
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
            ),
    );
  }
}
