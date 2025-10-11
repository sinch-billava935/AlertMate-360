import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/health_service.dart';
import '../models/health_data.dart';
import 'health_stats_screen.dart';
import 'emergency_contacts_screen.dart';
import 'sos_screen.dart';

class MapScreen extends StatelessWidget {
  MapScreen({super.key});
  final HealthService healthService = HealthService(app: Firebase.app());

  static const Color accentColor = Color(0xFF3E82C6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E1117) : const Color(0xFFF4F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: accentColor,
        centerTitle: true,
        title: Text(
          "Map View",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<HealthData?>(
        stream: healthService.getHealthDataStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Text(
                "No location data available",
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            );
          }

          final data = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Image.asset(
                  'assets/logo/new_shield.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 10),
                Text(
                  "Track Your Location 👣",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Monitor real-time coordinates & updates",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                _buildFeatureCard(
                  icon: Icons.location_on,
                  color: Colors.redAccent,
                  title: "Latitude",
                  subtitle: "${data.latitude}",
                ),
                _buildFeatureCard(
                  icon: Icons.location_searching,
                  color: Colors.blueAccent,
                  title: "Longitude",
                  subtitle: "${data.longitude}",
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      "Last Updated: ${DateTime.fromMillisecondsSinceEpoch(data.timestamp)}",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 35),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: accentColor,
        unselectedItemColor: Colors.black54,
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => SosScreen()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => HealthStatsScreen()),
            );
          } else if (index == 2) {
            // Stay on MapScreen
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => EmergencyContactsScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_rounded),
            label: "Trigger SOS",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: "Health",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_rounded),
            label: "Map View",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts_rounded),
            label: "Contacts",
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(2),
        leading: Icon(icon, color: color, size: 30),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
        ),
      ),
    );
  }
}
