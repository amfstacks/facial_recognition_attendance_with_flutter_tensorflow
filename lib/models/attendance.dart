class Attendance {
  final String userId;
  final DateTime timestamp;
  final String status;

  Attendance({required this.userId, required this.timestamp, required this.status});

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      userId: map['user_id'],
      timestamp: DateTime.parse(map['timestamp']),
      status: map['status'],
    );
  }
}