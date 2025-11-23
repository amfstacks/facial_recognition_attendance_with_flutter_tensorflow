import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/attendance.dart';

class ApiService {
  // static const String baseUrl = 'https://yoursharedhost.com/api'; // Replace with your host
  static const String baseUrl = 'https://cockadocms.com/ovc/api.php';

  static Future<Member?> fetchMemberFromTally(String qrData) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl?tally_Number=$qrData'));
      if (response.statusCode == 200) {
        return Member.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error fetching member: $e');
      return null;
    }
  }

   Future<bool> saveMemberFace(int memberId, List<double> embedding) async {
    try {
      print(memberId);
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {
          'member_id': memberId.toString(),
          'embedding': jsonEncode(embedding),
        },
      );
      print('Response body: ${response.body}');
      print('Status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error saving member face: $e');
      return false;
    }
  }

   Future<List<List<double>>> getEmbeddingsForUser(int memberId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl?member_id=$memberId'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map<List<double>>((e) {
          final raw = (jsonDecode(e['embedding']) as List).map((v) => (v as num).toDouble()).toList();
          return _normalize(raw);
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching user embeddings: $e');
      return [];
    }
  }

  /// Get all faces globally
   Future<List<Map<String, dynamic>>> getFaces() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl?all_faces=1'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map<Map<String, dynamic>>((e) {
          final embedding = (jsonDecode(e['embedding']) as List).map((v) => (v as num).toDouble()).toList();
          final normalized = _normalize(embedding);
          return {
            'member_id': e['member_id'],
            'full_name': e['full_name'],
            'embedding': jsonEncode(normalized),
          };
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching global faces: $e');
      return [];
    }
  }
  List<double> _normalize(List<double> embedding) {
    final mag = sqrt(embedding.fold(0, (sum, e) => sum + e * e));
    return embedding.map((e) => e / mag).toList();
  }
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
  Future<bool> enroll(String userId, List<double> embedding) async {
    final response = await http.post(
      Uri.parse('$baseUrl/enroll.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'embedding': embedding,
      }),
    );
    return response.statusCode == 200 && jsonDecode(response.body)['success'];
  }

  Future<String?> recognize(List<double> embedding) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recognize.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'embedding': embedding}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['user_id'] != 'no_match' ? data['user_id'] : null;
    }
    return null;
  }

  Future<bool> markAttendance(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'status': 'present'}),
    );
    return response.statusCode == 200;
  }

  Future<List<Attendance>> getAttendance(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/get_attendance.php?user_id=$userId'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Attendance.fromMap(e)).toList();
    }
    return [];
  }



  Future<String?> recognizeFace_(List<double> embedding) async {
    final faces = await getFaces();
    double bestScore = 0;
    String? bestMatch;
// print(faces);
// print('faces___');
    for (var face in faces) {
      final storedEmbedding = jsonDecode(face['embedding']).cast<double>();
      final score = _cosineSimilarity(embedding, storedEmbedding);
      if (score > 0.85 && score > bestScore) { // Tuned threshold
        bestScore = score;
        bestMatch = face['member_id'];
      }
    }
    return bestMatch;
  }
  Future<Map<String, dynamic>?> recognizeFace(List<double> embedding) async {
    final faces = await getFaces();
    double bestScore = 0;
    Map<String, dynamic>? bestMatch;

    for (var face in faces) {
      final storedEmbedding = jsonDecode(face['embedding']).cast<double>();
      final score = _cosineSimilarity(embedding, storedEmbedding);

      if (score > 0.85 && score > bestScore) {
        bestScore = score;
        bestMatch = {
          'member_id': face['member_id'],
          'full_name': face['full_name']
        };
      }
    }

    return bestMatch;
  }


  Future<Map<String, dynamic>> recordAttendance(int memberId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl'),
        body: {'action': 'record_attendance', 'member_id': memberId.toString()},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to connect to server.'};
    } catch (e) {
      print('Error recording attendance: $e');
      return {'success': false, 'message': 'Error recording attendance.'};
    }
  }
}

class Member {
  final int id;
  final String name;
  final String imageUrl;

  Member({required this.id, required this.name, required this.imageUrl});

  factory Member.fromJson(Map<String, dynamic> json) {
    int parsedId = 0;
    final dynamic idValue = json['id'];
    if (idValue is int) {
      parsedId = idValue;
    } else if (idValue is String) {
      parsedId = int.tryParse(idValue) ?? 0;
    }
    return Member(
      id: parsedId,
      name: json['full_name'],
      imageUrl: json['image_path'] ?? 'https://via.placeholder.com/150',
    );
  }
}