// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../services/db_service.dart';
// import '../services/face_service.dart';
// import '../services/api_service.dart';
// import 'package:image/image.dart' as img;
//
// class EnrollScreen extends StatefulWidget {
//   @override
//   _EnrollScreenState createState() => _EnrollScreenState();
// }
//
// class _EnrollScreenState extends State<EnrollScreen> {
//   late CameraController _controller;
//   late Future<void> _initializeControllerFuture;
//   final FaceService _faceService = FaceService();
//   final ApiService _apiService = ApiService();
//   final DbService _dbService = DbService();
//   final TextEditingController _userIdController = TextEditingController();
//   bool _isProcessing = false;
//
//   @override
//   void initState() {
//     super.initState();
//     // _requestPermissions();
//     // _faceService.init();
//     // _initializeCamera();
//     _initialize();
//   }
//
//   Future<void> _initialize() async {
//     await _requestPermissions(); // Wait for permission
//     _faceService.init();
//     await _initializeCamera();
//     setState(() {});
//   }
//
//   Future<void> _requestPermissions() async {
//     await [Permission.camera].request();
//   }
//
//   Future<void> _initializeCamera() async {
//     final cameras = await availableCameras();
//     _controller = CameraController(cameras[1], ResolutionPreset.high); // Front camera
//     _initializeControllerFuture = _controller.initialize();
//     setState(() {});
//   }
//
//   Future<void> _enroll() async {
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
//       if (!await _faceService.isLivenessDetected(faces)) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Liveness check failed')));
//         // return;
//       }
//
//       // Crop face (simplified; adjust bounding box)
//       final bytes = await File(image.path).readAsBytes();
//       final embedding = await _faceService.getEmbedding(bytes);
//
//       final success = await _apiService.enroll(_userIdController.text, embedding);
//       if (success) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enrollment successful')));
//         Navigator.pushNamed(context, '/recognize');
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enrollment failed')));
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
//     } finally {
//       setState(() => _isProcessing = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Enroll Face')),
//       body: Column(
//         children: [
//           Expanded(
//             child: FutureBuilder<void>(
//               future: _initializeControllerFuture,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.done) {
//                   return CameraPreview(_controller);
//                 }
//                 return Center(child: CircularProgressIndicator());
//               },
//             ),
//           ),
//           Padding(
//             padding: EdgeInsets.all(16.0),
//             child: TextField(
//               controller: _userIdController,
//               decoration: InputDecoration(labelText: 'User ID'),
//             ),
//           ),
//           ElevatedButton(
//             onPressed: _isProcessing ? null : _enroll,
//             child: Text(_isProcessing ? 'Processing...' : 'Enroll'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pushNamed(context, '/recognize'),
//             child: Text('Go to Recognition'),
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