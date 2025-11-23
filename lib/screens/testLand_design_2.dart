import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import 'enroll_screen.dart';

class TallyLookupScreen extends StatefulWidget {
  const TallyLookupScreen({Key? key}) : super(key: key);

  @override
  State<TallyLookupScreen> createState() => _TallyLookupScreenState();
}

class _TallyLookupScreenState extends State<TallyLookupScreen> {
  final TextEditingController _tallyController = TextEditingController();
  bool _isLoading = false;
  Member? _member;

  Future<void> _requestPermissions() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera permission required.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _searchTally() async {
    final qrData = _tallyController.text.trim();
    if (qrData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid Tally Number")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _member = null;
    });

    try {
      final result = await ApiService.fetchMemberFromTally(qrData);
      if (result != null) {
        setState(() => _member = result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No member found for this Tally Number")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching member: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    _tallyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff5f6fb),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 80,
        title: Column(
          children: [
            Text(
              "Church of Christ, Kado",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Facial Attendance System",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            )
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // HEADER
            SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Search by Tally Number",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            SizedBox(height: 20),

            // INPUT FIELD
            TextField(
              controller: _tallyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Tally Number",
                prefixIcon: Icon(Icons.confirmation_number_outlined),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            // BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _searchTally,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.shade700,
                  elevation: 4,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)
                    : Text(
                  "Search",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
              ),
            ),
            SizedBox(height: 30),

            // RESULT CARD
            if (_member != null)
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundImage: NetworkImage(
                        _member!.imageUrl.isNotEmpty
                            ? 'https://cockadocms.com/uploads/${_member!.imageUrl}'
                            : 'https://via.placeholder.com/150',
                      ),
                      backgroundColor: Colors.grey[200],
                    ),
                    SizedBox(height: 18),

                    Text(
                      _member!.name,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6),

                    Text(
                      "Tally No: ${_tallyController.text}",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 18),

                    // CAPTURE BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.camera_alt_outlined),
                        label: Text(
                          "Capture Face",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.blueAccent, width: 1.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EnrollScreen(member: _member!),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 40),

            // MARK ATTENDANCE BUTTON (BOTTOM)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/recognize'),
              child: Text(
                'Mark Attendance',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blueAccent.shade700,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
