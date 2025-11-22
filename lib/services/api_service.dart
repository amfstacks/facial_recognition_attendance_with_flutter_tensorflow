import 'dart:convert';
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