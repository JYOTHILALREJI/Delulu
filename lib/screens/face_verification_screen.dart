import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';

class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _controller;
  final FaceDetector _faceDetector = GoogleMlKit.vision.faceDetector();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(frontCamera, ResolutionPreset.medium);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isProcessing = true);
    try {
      final XFile picture = await _controller!.takePicture();
      final File file = File(picture.path);
      final inputImage = InputImage.fromFile(file);
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No face detected. Try again.')),
        );
        setState(() => _isProcessing = false);
        return;
      }
      // Liveness check: simple – assume passed for MVP
      // Generate hash of face embedding (simplified: hash entire image bytes)
      final bytes = await file.readAsBytes();
      final hash = _hashBytes(bytes);
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profiles').update({
        'face_hash': hash,
        'is_verified': true,
      }).eq('id', userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Face verified!')),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/discovery');
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _hashBytes(Uint8List bytes) {
    // In real app, use crypto package and device salt
    return bytes.length.toString(); // placeholder
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Face Verification')),
      body: Column(
        children: [
          Expanded(
            child: CameraPreview(_controller!),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _captureAndVerify,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBD00FF),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator()
                  : const Text('Capture & Verify'),
            ),
          ),
        ],
      ),
    );
  }
}