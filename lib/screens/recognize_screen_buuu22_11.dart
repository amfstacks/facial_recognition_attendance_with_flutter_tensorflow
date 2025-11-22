// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import '../services/face_service.dart';
// import '../services/db_service.dart';
// import '../models/attendance.dart';
//
// class RecognizeScreen extends StatefulWidget {
//   @override
//   _RecognizeScreenState createState() => _RecognizeScreenState();
// }
//
// class _RecognizeScreenState extends State<RecognizeScreen> {
//   late CameraController _controller;
//   late Future<void> _initializeControllerFuture;
//   final FaceService _faceService = FaceService();
//   final DbService _dbService = DbService();
//   bool _isProcessing = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _faceService.init();
//     _initializeCamera();
//   }
//
//   Future<void> _initializeCamera() async {
//     final cameras = await availableCameras();
//     if (cameras.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('No cameras available on this device.')),
//       );
//       return;
//     }
//     _controller = CameraController(cameras[1], ResolutionPreset.high);
//     _initializeControllerFuture = _controller.initialize().catchError((e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Camera initialization failed: $e')),
//       );
//     });
//     setState(() {});
//   }
//
//   Future<void> _recognize_working_single_entry() async {
//     if (_isProcessing) return;
//     setState(() => _isProcessing = true);
//
//     try {
//       await _initializeControllerFuture;
//       final image = await _controller.takePicture();
//       final inputImage = InputImage.fromFilePath(image.path);
//       final faces = await _faceService.detectFaces(inputImage);
//
//       if (faces == null || faces.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No face detected')));
//         return;
//       }
//
//       // if (!await _faceService.isLivenessDetected(faces)) {
//       //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Liveness check failed')));
//       //   return;
//       // }
//
//       final bytes = await File(image.path).readAsBytes();
//       final embedding = await _faceService.getEmbedding(bytes);
//       final userId = await _dbService.recognizeFace(embedding);
//
//       if (userId != null) {
//         final attendance = Attendance(
//           userId: userId,
//           timestamp: DateTime.now(),
//           status: 'present',
//         );
//         await _dbService.cacheAttendance(attendance);
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance marked for $userId')));
//         Navigator.pushNamed(context, '/history');
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No match found')));
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
//     } finally {
//       setState(() => _isProcessing = false);
//     }
//   }
//
//   Future<void> _recognize() async {
//     if (_isProcessing) return;
//     setState(() => _isProcessing = true);
//
//     try {
//       await _initializeControllerFuture;
//       final image = await _controller.takePicture();
//       final inputImage = InputImage.fromFilePath(image.path);
//       final faces = await _faceService.detectFaces(inputImage);
//
//       if (faces == null || faces.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No face detected')));
//         return;
//       }
//
//       final bytes = await File(image.path).readAsBytes();
//       final embedding = await _faceService.getEmbedding(bytes);
//
//       final userId = await _dbService.recognizeFace(embedding);
//
//       if (userId != null) {
//         final attendance = Attendance(
//           userId: userId,
//           timestamp: DateTime.now(),
//           status: 'present',
//         );
//         await _dbService.cacheAttendance(attendance);
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance marked for $userId')));
//         Navigator.pushNamed(context, '/history');
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No match found')));
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
//     } finally {
//       setState(() => _isProcessing = false);
//     }
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Mark Attendance')),
//       body: Column(
//         children: [
//           Expanded(
//             child: FutureBuilder<void>(
//               future: _initializeControllerFuture,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
//                   return CameraPreview(_controller);
//                 }
//                 return Center(child: CircularProgressIndicator());
//               },
//             ),
//           ),
//           SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: _isProcessing ? null : _recognize,
//             child: Text(_isProcessing ? 'Processing...' : 'Mark Attendance'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pushNamed(context, '/history'),
//             child: Text('View Attendance History'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     _faceService.dispose();
//     super.dispose();
//   }
// }