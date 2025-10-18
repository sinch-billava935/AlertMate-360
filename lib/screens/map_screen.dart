import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../services/health_service.dart';
import '../models/health_data.dart';

class MapScreen extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  MapScreen({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  final HealthService healthService = HealthService(app: Firebase.app());
  static const Color accentColor = Color(0xFF3E82C6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E1117) : const Color(0xFFF4F6FB),
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
                ElevatedButton.icon(
                  onPressed: () async {
                    final lat = data.latitude;
                    final lon = data.longitude;
                    final Uri googleMapsUrl = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
                    );
                    if (await canLaunchUrl(googleMapsUrl)) {
                      await launchUrl(
                        googleMapsUrl,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Could not open Google Maps"),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.map, color: Colors.white),
                  label: Text(
                    "Open in Google Maps",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    shadowColor: accentColor.withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 25),
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
                    child: Builder(
                      builder: (context) {
                        try {
                          int rawTs = data.timestamp;
                          final int normalizedMs =
                              (rawTs < 1000000000000) ? rawTs * 1000 : rawTs;
                          final DateTime dt =
                              DateTime.fromMillisecondsSinceEpoch(
                                normalizedMs,
                                isUtc: true,
                              ).toLocal();
                          final String formatted = DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(dt);
                          return Text(
                            "Last Updated: $formatted",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          );
                        } catch (e) {
                          return Text(
                            "Last Updated: Unknown",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 35),
              ],
            ),
          );
        },
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
