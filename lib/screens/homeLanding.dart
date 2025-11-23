import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import 'enroll_screen.dart';

class HomeLanding extends StatefulWidget {
  const HomeLanding({Key? key}) : super(key: key);

  @override
  State<HomeLanding> createState() => _HomeLandingScreenState();
}

class _HomeLandingScreenState extends State<HomeLanding> {

  Future<void> _requestPermissions() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera permission required'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff3f4f8),

      // --- BEAUTIFUL APP BAR ---
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        toolbarHeight: 90,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              "Church of Christ, Kado",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 6),
            Text(
              "Facial Attendance System",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            )
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 35),
        child: SingleChildScrollView(
          child: Column(
            children: [
          
              // ========== ENROLL MEMBER CARD ==========
              _actionCard(
                icon: Icons.person_add_alt_1_rounded,
                iconColor: Colors.blueAccent,
                title: "Enroll New Member",
                subtitle: "Capture face & store profile",
                buttonText: "Start Enrollment",
                buttonColor1: Colors.blueAccent,
                buttonColor2: Colors.lightBlue,
                buttonIcon: Icons.camera_alt_rounded,
                onPressed: () => Navigator.pushNamed(context, '/enrol'),
              ),
          
              SizedBox(height: 35),
          
              // ========== MARK ATTENDANCE CARD ==========
              _actionCard(
                icon: Icons.fact_check_rounded,
                iconColor: Colors.green,
                title: "Mark Attendance",
                subtitle: "Recognize member using face",
                buttonText: "Start Recognition",
                buttonColor1: Colors.green.shade700,
                buttonColor2: Colors.green.shade400,
                buttonIcon: Icons.face_retouching_natural_rounded,
                onPressed: () => Navigator.pushNamed(context, '/recognize'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // REUSABLE CARD WIDGET
  Widget _actionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonText,
    required IconData buttonIcon,
    required Color buttonColor1,
    required Color buttonColor2,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 18,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: iconColor.withOpacity(0.15),
            child: Icon(icon, size: 45, color: iconColor),
          ),

          SizedBox(height: 18),

          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),

          SizedBox(height: 5),

          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),

          SizedBox(height: 22),

          // BEAUTIFUL GRADIENT BUTTON
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [buttonColor1, buttonColor2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ElevatedButton.icon(
              icon: Icon(buttonIcon, color: Colors.white),
              label: Text(
                buttonText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onPressed,
            ),
          ),
        ],
      ),
    );
  }
}
