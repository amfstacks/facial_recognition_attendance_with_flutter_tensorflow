import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/face_service.dart';
import '../services/db_service.dart'; // Updated to use SQLite

class EnrollScreen extends StatefulWidget {
  @override
  _EnrollScreenState createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<EnrollScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final FaceService _faceService = FaceService();
  final DbService _dbService = DbService();
  final TextEditingController _userIdController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _faceService.init();
    _initializeCamera();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera permission required. Please enable in settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        return;
      }
    }
  }

  Future<void> _initializeCamera() async {
    await _requestPermissions();
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No cameras available on this device.')),
      );
      return;
    }
    _controller = CameraController(cameras[1], ResolutionPreset.high); // Front camera
    _initializeControllerFuture = _controller.initialize().catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera initialization failed: $e')),
      );
    });
    setState(() {});
  }
  Future<bool> isFaceInsideGuide(Face face, Size previewSize) async {
    // Guide box dimensions (same as painter)
    final rectWidth = previewSize.width * 0.6;
    final rectHeight = previewSize.height * 0.5;
    final guideRect = Rect.fromCenter(
      center: Offset(previewSize.width / 2, previewSize.height / 2),
      width: rectWidth,
      height: rectHeight,
    );

    final faceRect = Rect.fromLTWH(
      face.boundingBox.left,
      face.boundingBox.top,
      face.boundingBox.width,
      face.boundingBox.height,
    );

    return guideRect.contains(faceRect.topLeft) && guideRect.contains(faceRect.bottomRight);
  }


  Future<void> _enroll_working_single_entry() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final faces = await _faceService.detectFaces(inputImage);

      if (faces == null || faces.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No face detected')));
        return;
      }

      // if (!await _faceService.isLivenessDetected(faces)) {
      //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Liveness check failed')));
      //   return;
      // }

      final bytes = await File(image.path).readAsBytes();
      final embedding = await _faceService.getEmbedding(bytes);

      // Save to SQLite instead of server
      await _dbService.saveFace(_userIdController.text, embedding);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enrollment successful')));
      Navigator.pushNamed(context, '/recognize');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  bool _isFaceInsideGuide(Face face, Size previewSize) {
    final rectWidth = previewSize.width * 0.6;
    final rectHeight = previewSize.height * 0.5;
    final guideRect = Rect.fromCenter(
      center: Offset(previewSize.width / 2, previewSize.height / 2),
      width: rectWidth,
      height: rectHeight,
    );

    final faceRect = Rect.fromLTWH(
      face.boundingBox.left,
      face.boundingBox.top,
      face.boundingBox.width,
      face.boundingBox.height,
    );

    return guideRect.contains(faceRect.topLeft) &&
        guideRect.contains(faceRect.bottomRight);
  }
  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, magA = 0, magB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    return dot / (sqrt(magA) * sqrt(magB));
  }
  Future<void> _enroll() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final faces = await _faceService.detectFaces(inputImage);

      if (faces == null || faces.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No face detected')));
        return;
      }
      // final previewSize = Size(_controller.value.previewSize!.height, _controller.value.previewSize!.width); // note rotation
      // if (!await isFaceInsideGuide(faces[0], previewSize)) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(content: Text('Please align your face inside the red box'))
      //   );
      //   return;
      // }
      final previewSize = Size(_controller.value.previewSize!.height, _controller.value.previewSize!.width);
      if (!_isFaceInsideGuide(faces[0], previewSize)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please align your face inside the red box')),
        );
        return;
      }

      final bytes = await File(image.path).readAsBytes();
      final embedding = await _faceService.getEmbedding(bytes);

      final existingUser = await _dbService.isFaceAlreadyEnrolledGlobally(embedding);
      if (existingUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('This face already exists (User: $existingUser)!'))
        );
        return;
      }

      // Save multiple embeddings per user
      await _dbService.saveFace(_userIdController.text, embedding);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enrollment successful')));
      _userIdController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Enroll Face')),
      body: Column(
        children: [
          // Expanded(
          //   child: FutureBuilder<void>(
          //     future: _initializeControllerFuture,
          //     builder: (context, snapshot) {
          //       if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
          //         return CameraPreview(_controller);
          //       }
          //       return Center(child: CircularProgressIndicator());
          //     },
          //   ),
          // ),
          Expanded(
            child: Stack(
              children: [
                FutureBuilder<void>(
                  future: _initializeControllerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
                      return CameraPreview(_controller);
                    }
                    return Center(child: CircularProgressIndicator());
                  },
                ),
                // Face guide box
                Positioned.fill(
                  child: CustomPaint(
                    painter: FaceGuidePainter(),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _userIdController,
              decoration: InputDecoration(labelText: 'User ID'),
            ),
          ),
          ElevatedButton(
            onPressed: _isProcessing ? null : _enroll,
            child: Text(_isProcessing ? 'Processing...' : 'Enroll'),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/recognize'),
            child: Text('Go to Recognition'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceService.dispose();
    super.dispose();
  }
}


class FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw a centered rectangle (example: 60% of width, 50% of height)
    final rectWidth = size.width * 0.6;
    final rectHeight = size.height * 0.5;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: rectWidth,
      height: rectHeight,
    );

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
