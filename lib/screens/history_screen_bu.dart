import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../models/attendance.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  final DbService _dbService = DbService();
  List<Attendance> _attendance = [];
  final TextEditingController _userIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final userId = _userIdController.text.isEmpty ? 'user123' : _userIdController.text;
    try {
      _attendance = await _apiService.getAttendance(userId);
      if (_attendance.isEmpty) {
        _attendance = await _dbService.getCachedAttendance(userId);
      }
    } catch (e) {
      _attendance = await _dbService.getCachedAttendance(userId);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attendance History')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _userIdController,
              decoration: InputDecoration(labelText: 'User ID'),
              onSubmitted: (_) => _loadAttendance(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _attendance.length,
              itemBuilder: (context, index) {
                final record = _attendance[index];
                return ListTile(
                  title: Text('User: ${record.userId}'),
                  subtitle: Text('Time: ${record.timestamp}, Status: ${record.status}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}