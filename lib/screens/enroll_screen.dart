import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/face_service.dart';
import '../services/db_service.dart';

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
  bool _isFaceAligned = false;

  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _faceService.init();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceService.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  /// ------------------ CAMERA ------------------
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

  Future<void> _initializeCamera({int cameraIndex = 0}) async {
    await _requestPermissions();
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No cameras available on this device.')),
      );
      return;
    }
    _selectedCameraIndex = cameraIndex.clamp(0, _cameras.length - 1);
    _controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize().catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera initialization failed: $e')),
      );
    });
    setState(() {});
  }

  void _switchCamera() {
    final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _controller.dispose();
    _initializeCamera(cameraIndex: newIndex);
  }

  /// ------------------ FACE GUIDE ------------------
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

  /// ------------------ STRICT ENROLLMENT ------------------
  Future<void> _enrollStrict() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _initializeControllerFuture;
      final previewSize = Size(
        _controller.value.previewSize!.height,
        _controller.value.previewSize!.width,
      );

      int stableFramesRequired = 3;
      int stableFramesCount = 0;
      XFile? bestImage;

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Align your face inside the box and stay still'))
      );

      while (stableFramesCount < stableFramesRequired) {
        final image = await _controller.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);
        final faces = await _faceService.detectFaces(inputImage);

        if (faces == null || faces.isEmpty) {
          stableFramesCount = 0;
          setState(() => _isFaceAligned = false);
          await Future.delayed(Duration(milliseconds: 800));
          continue;
        }

        final face = faces[0];

        // ------------------ ORIENTATION CHECK ------------------
        final yaw = face.headEulerAngleY ?? 0;
        final roll = face.headEulerAngleZ ?? 0;
        final pitch = face.headEulerAngleX ?? 0;

        if (yaw.abs() > 15 || roll.abs() > 10 || pitch.abs() > 10) {
          stableFramesCount = 0;
          setState(() => _isFaceAligned = false);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Face must be straight and centered'))
          );
          await Future.delayed(Duration(milliseconds: 800));
          continue;
        }

        // ------------------ GUIDE BOX CHECK ------------------
        if (!_isFaceInsideGuide(face, previewSize)) {
          stableFramesCount = 0;
          setState(() => _isFaceAligned = false);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Keep your face inside the red box'))
          );
          await Future.delayed(Duration(milliseconds: 800));
          continue;
        }

        // Face is aligned, inside box
        stableFramesCount++;
        bestImage = image;
        setState(() => _isFaceAligned = true);
        await Future.delayed(Duration(milliseconds: 500));
      }

      // ------------------ GET EMBEDDING ------------------
      final bytes = await File(bestImage!.path).readAsBytes();
      final embedding = await _faceService.getEmbedding(bytes);

      // ------------------ GLOBAL DUPLICATE CHECK ------------------
      final existingUser = await _dbService.isFaceAlreadyEnrolledGlobally(
        embedding,
        threshold: 0.85,
      );
      if (existingUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This face already exists (User: $existingUser)!')),
        );
        return;
      }

      // ------------------ MULTI-ANGLE CHECK ------------------
      final userEmbeddings = await _dbService.getEmbeddingsForUser(_userIdController.text);
      for (var e in userEmbeddings) {
        final sim = _cosineSimilarity(embedding, e);
        if (sim > 0.95) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('This angle is already enrolled for this user!')),
          );
          return;
        }
      }

      // ------------------ SAVE EMBEDDING ------------------
      await _dbService.saveFace(_userIdController.text, embedding);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enrollment successful!'))
      );
      _userIdController.clear();
      setState(() => _isFaceAligned = false);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// ------------------ WIDGET BUILD ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enroll Face'),
        actions: [
          IconButton(
            icon: Icon(Icons.cameraswitch),
            onPressed: _cameras.length > 1 ? _switchCamera : null,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Column(
        children: [
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
                Positioned.fill(
                  child: CustomPaint(
                    painter: FaceGuidePainter(isAligned: _isFaceAligned),
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
            onPressed: _isProcessing ? null : _enrollStrict,
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
}

/// ------------------ GUIDE BOX PAINTER ------------------
class FaceGuidePainter extends CustomPainter {
  final bool isAligned;
  FaceGuidePainter({this.isAligned = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isAligned ? Colors.green : Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

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
  bool shouldRepaint(covariant FaceGuidePainter oldDelegate) => oldDelegate.isAligned != isAligned;
}
