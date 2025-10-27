import 'package:flutter/material.dart';
import 'screens/enroll_screen.dart';
import 'screens/recognize_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FaceRecognitionApp());
}

class FaceRecognitionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => EnrollScreen(),
        // '/recognize': (context) => RecognizeScreen(),
        // '/history': (context) => HistoryScreen(),
      },
    );
  }
}