import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

enum VerificationTask {
  smile,
  blink,
  turnRight,
  turnLeft,
  tiltUp,
  tiltDown,
  winkLeft,
  winkRight,
  neutral,
  smileWide,
}

class FaceVerificationService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Future<List<Face>> detectFaces(XFile imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    return await _faceDetector.processImage(inputImage);
  }

  bool checkTask(Face face, VerificationTask task) {
    final double smilingProb = face.smilingProbability ?? 0.0;
    final double leftEyeOpenProb = face.leftEyeOpenProbability ?? 1.0;
    final double rightEyeOpenProb = face.rightEyeOpenProbability ?? 1.0;
    final double headEulerAngleY = face.headEulerAngleY ?? 0.0; // Yaw
    final double headEulerAngleX = face.headEulerAngleX ?? 0.0; // Pitch

    debugPrint('Verification Debug:');
    debugPrint('  Task: $task');
    debugPrint('  Smile: $smilingProb');
    debugPrint('  Eyes: L:$leftEyeOpenProb, R:$rightEyeOpenProb');
    debugPrint('  Angles: Y:$headEulerAngleY, X:$headEulerAngleX');

    switch (task) {
      case VerificationTask.smile:
        return smilingProb > 0.4;
      case VerificationTask.smileWide:
        return smilingProb > 0.7;
      case VerificationTask.blink:
        return leftEyeOpenProb < 0.4 && rightEyeOpenProb < 0.4;
      case VerificationTask.turnRight:
        return headEulerAngleY > 10;
      case VerificationTask.turnLeft:
        return headEulerAngleY < -10;
      case VerificationTask.tiltUp:
        return headEulerAngleX > 8;
      case VerificationTask.tiltDown:
        return headEulerAngleX < -8;
      case VerificationTask.winkLeft:
        return leftEyeOpenProb < 0.4 && rightEyeOpenProb > 0.5;
      case VerificationTask.winkRight:
        return rightEyeOpenProb < 0.4 && leftEyeOpenProb > 0.5;
      case VerificationTask.neutral:
        return headEulerAngleY.abs() < 10 && headEulerAngleX.abs() < 10;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}

class VerificationCameraScreen extends StatefulWidget {
  const VerificationCameraScreen({super.key});

  @override
  State<VerificationCameraScreen> createState() => _VerificationCameraScreenState();
}

class _VerificationCameraScreenState extends State<VerificationCameraScreen> {
  CameraController? _controller;
  bool _isVerifying = false;
  bool _isCameraReady = false;
  final FaceVerificationService _faceService = FaceVerificationService();
  late VerificationTask _currentTask;
  
  final List<VerificationTask> _allTasks = VerificationTask.values;

  @override
  void initState() {
    super.initState();
    _currentTask = (List<VerificationTask>.from(_allTasks)..shuffle()).first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPrivacyDialog());
  }

  Future<void> _showPrivacyDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Privacy Alert', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, color: Colors.white)),
        content: Text(
          'Your live data will not be stored in the database. It will be used only for one-time verification to ensure you are a real person.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initCamera();
            },
            child: Text('OK', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      front,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera Error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  String get _taskText {
    switch (_currentTask) {
      case VerificationTask.smile: return 'Give us a big SMILE! 😊';
      case VerificationTask.smileWide: return 'A WIDE SMILE please! 😁';
      case VerificationTask.blink: return 'BLINK both eyes slowly';
      case VerificationTask.turnRight: return 'Turn your head to the RIGHT';
      case VerificationTask.turnLeft: return 'Turn your head to the LEFT';
      case VerificationTask.tiltUp: return 'Tilt your head UP';
      case VerificationTask.tiltDown: return 'Tilt your head DOWN';
      case VerificationTask.winkLeft: return 'WINK with your LEFT eye';
      case VerificationTask.winkRight: return 'WINK with your RIGHT eye';
      case VerificationTask.neutral: return 'Look straight at the camera';
    }
  }

  Future<void> _processVerification() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    setState(() => _isVerifying = true);
    try {
      final image = await _controller!.takePicture();
      final faces = await _faceService.detectFaces(image);
      
      if (faces.isEmpty) {
        _showError('No face detected. Please align your face in the circle.');
      } else {
        final success = _faceService.checkTask(faces.first, _currentTask);
        if (success) {
          if (mounted) Navigator.pop(context, true);
        } else {
          _showError('Alignment looks good, but the specific task wasn\'t clear. Please try again with a more noticeable expression.');
        }
      }
    } catch (e) {
      _showError('Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.toastBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady || _controller == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    final cameraRatio = _controller!.value.aspectRatio;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fixed aspect ratio camera preview
          Center(
            child: AspectRatio(
              aspectRatio: 1 / cameraRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          
          // Overlay
          Container(
            color: Colors.black.withOpacity(0.4),
          ),
          
          // Face Frame
          Center(
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.9,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
          ),
          
          // Instruction Card
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  Text(
                    'LIVENESS TASK',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _taskText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.beVietnamPro(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // Action Button
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: Column(
              children: [
                if (_isVerifying)
                  const CircularProgressIndicator(color: AppColors.primary)
                else
                  ElevatedButton(
                    onPressed: _processVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: AppColors.primary.withOpacity(0.5),
                    ),
                    child: Text('I\'M DOING IT!', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Align your face within the frame\nand perform the task shown above.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),

          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
        ],
      ),
    );
  }
}
