import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BlurredImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final bool blur;

  const BlurredImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[800],
        child: const Icon(Icons.person),
      );
    }
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.grey[800]),
      errorWidget: (_, __, ___) => const Icon(Icons.error),
    );
    if (blur) {
      image = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: image,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: image,
    );
  }
}