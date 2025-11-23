import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/api_service.dart';
import '../services/face_service.dart';
import '../services/db_service.dart';
import '../models/attendance.dart';

class RecognizeScreen extends StatefulWidget {
  const RecognizeScreen({Key? key}) : super(key: key);

  @override
  _RecognizeScreenState createState() => _RecognizeScreenState();
}

class _RecognizeScreenState extends State<RecognizeScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final FaceService _faceService = FaceService();
  final ApiService _apiService = ApiService();

  bool _isProcessing = false;

  // UI state for guide box (flip to true when you detect a well-aligned face)
  bool _isFaceAligned = false;

  @override
  void initState() {
    super.initState();
    _faceService.init();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cameras available on this device.')),
      );
      return;
    }

    // Prefer back camera; fall back to first available
    final backCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(backCamera, ResolutionPreset.high, enableAudio: false);
    _initializeControllerFuture = _controller.initialize().catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera initialization failed: $e')),
      );
    });

    setState(() {});
  }

  Future<void> _recognize() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final faces = await _faceService.detectFaces(inputImage);

      if (faces == null || faces.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No face detected')));
        return;
      }

      // Optional: set _isFaceAligned true briefly to show green box when a face is found
      setState(() => _isFaceAligned = true);
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _isFaceAligned = false);

      final bytes = await File(image.path).readAsBytes();
      final embedding = await _faceService.getEmbedding(bytes);

      final match = await _apiService.recognizeFace(embedding);

      if (match != null) {
        print(match);
        final userId = match['member_id'];
        final fullName = match['full_name'];
        final intId = int.tryParse(userId);
        if (intId == null) {
          print("Invalid userId from API: $userId");
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('found $fullName')));
        final markAttendance = await _apiService.recordAttendance(intId);
        if (markAttendance['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(markAttendance['message'] ?? 'Attendance marked!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(markAttendance['message'] ?? 'Failed to mark attendance')),
          );
        }
        // final markAttendance = await _api_service_recordAttendanceSafely(intId);
        // if (markAttendance) {
        //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance marked for $userId')));
        // } else {
        //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to record attendance')));
        // }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No match found')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // Wrapper to avoid compile-time errors if your ApiService method names differ
  Future<bool> _api_service_recordAttendanceSafely(int memberId) async {
    try {
      final res = await _apiService.recordAttendance(memberId);
      // If recordAttendance returns a Map like your earlier examples, adapt accordingly.
      if (res is Map<String, dynamic>) {
        return res['success'] == true;
      }
      return res == true;
    } catch (e) {
      print('Error recording attendance: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        actions: [
          // Helpful toggle for debugging: force green/red guide box
          IconButton(
            icon: Icon(_isFaceAligned ? Icons.toggle_on : Icons.toggle_off),
            tooltip: 'Toggle guide state (debug)',
            onPressed: () => setState(() => _isFaceAligned = !_isFaceAligned),
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview area with overlayed guide box
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
                  return Stack(
                    children: [
                      CameraPreview(_controller),
                      // Guide overlay fills the preview
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: true,
                          child: CustomPaint(
                            painter: GuideBoxPainter(isAligned: _isFaceAligned),
                          ),
                        ),
                      ),
                      // Instruction chip
                      Positioned(
                        top: 24,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _isFaceAligned ? 'Good — hold still' : 'Place face inside the box',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),

          const SizedBox(height: 14),

          // Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _recognize,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(_isProcessing ? 'Processing...' : 'Mark Attendance'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: 8),
                // TextButton(
                //   onPressed: () => Navigator.pushNamed(context, '/history'),
                //   child: const Text('View Attendance History'),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that draws the center guide box (red or green)
class GuideBoxPainter extends CustomPainter {
  final bool isAligned;
  GuideBoxPainter({required this.isAligned});

  @override
  void paint(Canvas canvas, Size size) {
    // Guide rect size (adjust percentages as you prefer)
    final rectWidth = size.width * 0.62;
    final rectHeight = size.height * 0.52;
    final rect = Rect.fromCenter(center: size.center(Offset.zero), width: rectWidth, height: rectHeight);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    // Vignette (dim outside the box)
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.45);
    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()..addRRect(rrect);
    final diff = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(diff, overlayPaint);

    // Border paint
    final borderPaint = Paint()
      ..color = isAligned ? Colors.greenAccent : Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Soft shadow around the rect
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadowPaint);

    // Draw the border
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant GuideBoxPainter oldDelegate) => oldDelegate.isAligned != isAligned;
}
