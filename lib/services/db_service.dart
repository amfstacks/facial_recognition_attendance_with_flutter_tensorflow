import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/attendance.dart';

// class DbService {
//   static Database? _database;
//
//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDatabase();
//     return _database!;
//   }
//
//   Future<Database> _initDatabase() async {
//     String path = join(await getDatabasesPath(), 'attendance.db');
//     return await openDatabase(path, version: 1, onCreate: (db, version) async {
//       await db.execute('''
//         CREATE TABLE attendance (
//           id INTEGER PRIMARY KEY AUTOINCREMENT,
//           user_id TEXT,
//           timestamp TEXT,
//           status TEXT
//         )
//       ''');
//     });
//   }
//
//   Future<void> cacheAttendance(Attendance attendance) async {
//     final db = await database;
//     await db.insert('attendance', attendance.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
//   }
//
//   Future<List<Attendance>> getCachedAttendance(String userId) async {
//     final db = await database;
//     final List<Map<String, dynamic>> maps =
//     await db.query('attendance', where: 'user_id = ?', whereArgs: [userId]);
//     return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
//   }
//
//   Future<void> syncAttendance() async {
//     // Sync cached attendance with backend when online
//     // Implement based on your needs
//   }
// }




class DbService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'attendance.db');
    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE faces (
          user_id TEXT PRIMARY KEY,
          embedding TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE attendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          timestamp TEXT,
          status TEXT
        )
      ''');
    });
  }

  Future<void> saveFace(String userId, List<double> embedding) async {
    final db = await database;
    await db.insert(
      'faces',
      {'user_id': userId, 'embedding': jsonEncode(embedding)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getFaces() async {
    final db = await database;
    return await db.query('faces');
  }

  Future<String?> recognizeFace(List<double> embedding) async {
    final faces = await getFaces();
    double bestScore = 0;
    String? bestMatch;

    for (var face in faces) {
      final storedEmbedding = jsonDecode(face['embedding']).cast<double>();
      final score = _cosineSimilarity(embedding, storedEmbedding);
      if (score > 0.65 && score > bestScore) { // Tuned threshold
        bestScore = score;
        bestMatch = face['user_id'];
      }
    }
    return bestMatch;
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

  Future<void> cacheAttendance(Attendance attendance) async {
    final db = await database;
    await db.insert('attendance', attendance.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Attendance>> getCachedAttendance(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
    await db.query('attendance', where: 'user_id = ?', whereArgs: [userId]);
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  Future<void> syncToServer() async {
    // Placeholder for server sync when ready
    // Fetch all faces and attendance, send to server APIs
    // Example: await ApiService().enroll(...);
  }

  // Future<void> syncToServer() async {
  //   final db = await database;
  //   final faces = await db.query('faces');
  //   final attendance = await db.query('attendance');
  //   for (var face in faces) {
  //     await ApiService().enroll(face['user_id'], jsonDecode(face['embedding']));
  //   }
  //   for (var record in attendance) {
  //     await ApiService().markAttendance(record['user_id']);
  //   }
  // }
}