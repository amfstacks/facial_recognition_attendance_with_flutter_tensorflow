import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img_lib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

class FaceService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  Interpreter? _interpreter;

  // Future<void> init() async {
  //   _interpreter = await Interpreter.fromAsset('mobilefacenet.tflite');
  // }

  Future<void> init() async {
    try {
      print('Loading model from assets/mobilefacenet.tflite...');
      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite');
      print('Model loaded successfully!');
    } catch (e) {
      print('ERROR LOADING MODEL: $e');
      rethrow;
    }
  }

  Future<List<Face>?> detectFaces(InputImage inputImage) async {
    final faces = await _faceDetector.processImage(inputImage);
    return faces.isNotEmpty ? faces : null;
  }

  // Future<bool> isLivenessDetected(List<Face> faces, {int frameCount = 3}) async {
  //   // Basic blink detection: Check if smileProbability changes over frames
  //   // Implement with multiple frames if needed
  //   print(faces.first.smilingProbability);
  //   return faces.first.smilingProbability != null && faces.first.smilingProbability! > 0.5;
  // }

  Future<bool> isLivenessDetected(CameraController controller, {int frameCount = 5, Duration timeout = const Duration(seconds: 5)}) async {
    if (!controller.value.isInitialized) return false;

    bool blinkDetected = false;
    double? prevLeftEyeProb;
    double? prevRightEyeProb;
    final startTime = DateTime.now();

    while (!blinkDetected && DateTime.now().difference(startTime) < timeout) {
      try {
        final image = await controller.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);
        final faces = await detectFaces(inputImage);

        if (faces == null || faces.isEmpty) continue;

        final face = faces.first;
        if (face.leftEyeOpenProbability == null || face.rightEyeOpenProbability == null) {
          continue;
        }

        final currentLeftEyeProb = face.leftEyeOpenProbability!;
        final currentRightEyeProb = face.rightEyeOpenProbability!;

        if (prevLeftEyeProb != null && prevRightEyeProb != null) {
          // Detect blink: Eye was open (>0.8) and now closed (<0.4)
          if ((prevLeftEyeProb > 0.8 && currentLeftEyeProb < 0.4) ||
              (prevRightEyeProb > 0.8 && currentRightEyeProb < 0.4)) {
            blinkDetected = true;
          }
        }

        prevLeftEyeProb = currentLeftEyeProb;
        prevRightEyeProb = currentRightEyeProb;

        // Small delay to avoid excessive CPU usage
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        // Ignore errors in individual frames
        continue;
      }
    }

    return blinkDetected;
  }

  Future<List<double>> getEmbedding_(Uint8List imageBytes) async {
    // Decode and preprocess image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    // Resize to 112x112 (MobileFaceNet input)
    img.Image resized = img.copyResize(image, width: 112, height: 112);

    // Normalize to [-1, 1]
    var input = List.generate(1, (_) => List.generate(112, (_) => List.filled(112 * 3, 0.0)));
    for (int y = 0; y < 112; y++) {
      for (int x = 0; x < 112; x++) {
        var pixel = resized.getPixel(x, y);
        input[0][y][x * 3] = (pixel.r / 127.5) - 1.0; // R
        input[0][y][x * 3 + 1] = (pixel.g / 127.5) - 1.0; // G
        input[0][y][x * 3 + 2] = (pixel.b / 127.5) - 1.0; // B
      }
    }

    // Run model
    var output = List.filled(1 * 128, 0.0).reshape([1, 128]);
    // _interpreter!.run(input, output);
    // return output[0];
    try {
      _interpreter!.run(input, output);
    } catch (e) {
      throw Exception('Failed to run model inference: $e');
    }
    return output[0];
  }

  Future<List<double>> getEmbedding__(Uint8List imageBytes) async {
    if (_interpreter == null) {
      throw Exception('Model not initialized. Call init() first.');
    }

    img_lib.Image? image = img_lib.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize to 112x112
    img_lib.Image resized = img_lib.copyResize(image, width: 112, height: 112);

    // Create flat input list of size 1*112*112*3 = 37632
    final input = Float32List(1 * 112 * 112 * 3); // Use Float32List for precision
    int pixelIndex = 0;
    for (int y = 0; y < 112; y++) {
      for (int x = 0; x < 112; x++) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.getChannel(img_lib.Channel.red).toDouble();
        final g = pixel.getChannel(img_lib.Channel.green).toDouble();
        final b = pixel.getChannel(img_lib.Channel.blue).toDouble();
        input[pixelIndex++] = (r / 127.5) - 1.0; // R
        input[pixelIndex++] = (g / 127.5) - 1.0; // G
        input[pixelIndex++] = (b / 127.5) - 1.0; // B
        if (input[pixelIndex - 3].isNaN || input[pixelIndex - 2].isNaN || input[pixelIndex - 1].isNaN) {
          throw Exception('Invalid input value: NaN detected at pixel ($x, $y)');
        }
      }
    }

    // Output flat list of size 128
    final output = Float32List(128);


    try {
      print('Running inference with input size: ${input.length}');
      print('Input sample (first 5): ${input.sublist(0, 5)}');
      _interpreter!.run(input, output);
      print('Inference successful. Output sample (first 5): ${output.sublist(0, 5)}');
    } catch (e) {
      print('Inference error details: $e');
      throw Exception('Failed to run model inference: $e');
    }

    return output.toList();
  }
  Future<List<double>> getEmbedding(Uint8List imageBytes) async {
    if (_interpreter == null) {
      throw Exception('Model not initialized. Call init() first.');
    }

    img_lib.Image? image = img_lib.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize to 112x112
    img_lib.Image resized = img_lib.copyResize(image, width: 112, height: 112);

    // Create 4D input tensor: [1, 112, 112, 3]
    final input = List.generate(1, (_) =>
        List.generate(112, (y) =>
            List.generate(112, (x) {
              final pixel = resized.getPixel(x, y);
              final r = pixel.getChannel(img_lib.Channel.red).toDouble();
              final g = pixel.getChannel(img_lib.Channel.green).toDouble();
              final b = pixel.getChannel(img_lib.Channel.blue).toDouble();
              return [(r / 127.5) - 1.0, (g / 127.5) - 1.0, (b / 127.5) - 1.0];
            })
        )
    );

    // Output buffer
    // final output = List.filled(1 * 128, 0.0).reshape([1, 128]);
    final output = List.filled(1 * 192, 0.0).reshape([1, 192]);
    try {
      print('Running inference...');
      _interpreter!.run(input, output);
      print('Inference successful!');
    } catch (e) {
      print('Inference error details: $e');
      throw Exception('Failed to run model inference: $e');
    }

    // Return the first output vector (embedding)
    return List<double>.from(output[0]);
  }

  void dispose() {
    _faceDetector.close();
    _interpreter?.close();
  }
}