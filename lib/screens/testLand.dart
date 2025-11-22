import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TallyLookupScreen extends StatefulWidget {
  const TallyLookupScreen({Key? key}) : super(key: key);

  @override
  State<TallyLookupScreen> createState() => _TallyLookupScreenState();
}

class _TallyLookupScreenState extends State<TallyLookupScreen> {
  final TextEditingController _tallyController = TextEditingController();
  bool _isLoading = false;
  Member? _member;

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
  void dispose() {
    _tallyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "Tally Lookup",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 10),
            Text(
              "Search by Tally Number",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800]),
            ),
            SizedBox(height: 20),

            // Tally input field
            TextField(
              controller: _tallyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Enter Tally Number",
                prefixIcon: Icon(Icons.confirmation_number_outlined),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                EdgeInsets.symmetric(vertical: 18, horizontal: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            // Search button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _searchTally,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 3,
                  backgroundColor: Colors.blueAccent,
                ),
                child: _isLoading
                    ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : Text(
                  "Search",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 30),

            // Result Card
            if (_member != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Profile image
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(
                        _member!.imageUrl.isNotEmpty
                            ? 'https://cockadocms.com/uploads/${_member!.imageUrl}'
                            : 'https://via.placeholder.com/150',
                      ),
                      backgroundColor: Colors.grey[200],
                    ),
                    SizedBox(height: 20),

                    // Full name
                    Text(
                      _member!.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),

                    // Tally number
                    Text(
                      "Tally No: ${_tallyController.text}",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 12),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
