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
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
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

  /// Save embedding (normalized)
  Future<void> saveFace(String userId, List<double> embedding) async {
    final db = await database;
    await db.insert(
      'faces',
      {'user_id': userId, 'embedding': jsonEncode(_normalize(embedding))},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Get all embeddings for a specific user
  Future<List<List<double>>> getEmbeddingsForUser(String userId) async {
    final db = await database;
    final maps = await db.query(
      'faces',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    return maps.map((e) {
      // final raw = jsonDecode(e['embedding']).cast<double>();
      final embeddingStr = e['embedding'] as String;
      final raw = jsonDecode(embeddingStr).cast<double>();
      return _normalize(raw);
    }).toList();
  }

  /// Get all faces (global)
  Future<List<Map<String, dynamic>>> getFaces() async {
    final db = await database;
    return await db.query('faces');
  }

  /// Check if embedding exists globally
  Future<String?> isFaceAlreadyEnrolledGlobally(List<double> newEmbedding,
      {double threshold = 0.85}) async {
    final faces = await getFaces();
    final normalized = _normalize(newEmbedding);

    for (var face in faces) {
      final stored = _normalize(jsonDecode(face['embedding']).cast<double>());
      final similarity = _cosineSimilarity(normalized, stored);
      if (similarity >= threshold) return face['user_id'];
    }
    return null;
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

  List<double> _normalize(List<double> embedding) {
    final mag = sqrt(embedding.fold(0, (sum, e) => sum + e * e));
    return embedding.map((e) => e / mag).toList();
  }
}
