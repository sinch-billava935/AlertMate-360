import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'sos_screen.dart';
import 'health_stats_screen.dart';
import 'map_screen.dart';
import 'emergency_contacts_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2F7FF), // Light bluish background
      appBar: AppBar(
        title: Text("AlertMate 360", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Color(0xFF3E82C6), // Darker blue
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 30),
            Text(
              "Welcome, User!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003366),
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Your safety companion for health monitoring & instant SOS.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            SizedBox(height: 30),

            // SOS Feature Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 32,
                ),
                title: Text("Trigger SOS"),
                subtitle: Text("Send an emergency alert with location"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SosScreen()),
                  );
                },
              ),
            ),
            SizedBox(height: 20),

            // Health Stats Feature Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.monitor_heart,
                  color: Colors.green,
                  size: 32,
                ),
                title: Text("Health Stats"),
                subtitle: Text("Track SpO2, heart rate, and temperature"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HealthStatsScreen()),
                  );
                },
              ),
            ),
            SizedBox(height: 20),

            // Map Feature Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(Icons.map_rounded, color: Colors.blue, size: 32),
                title: Text("Map View"),
                subtitle: Text("View your current location"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MapScreen()),
                  );
                },
              ),
            ),
            SizedBox(height: 20),

            // Emergency Contacts Feature Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.contacts,
                  color: Colors.deepPurple,
                  size: 32,
                ),
                title: Text("Emergency Contacts"),
                subtitle: Text("Manage your emergency contact list"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmergencyContactsScreen(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),

            Spacer(),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.logout, color: Colors.white),
                label: Text("Logout", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => LoginScreen()),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
