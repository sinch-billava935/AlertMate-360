import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/health_service.dart';
import '../models/health_data.dart';
import 'sos_screen.dart';
import 'map_screen.dart';
import 'emergency_contacts_screen.dart';

class HealthStatsScreen extends StatefulWidget {
  const HealthStatsScreen({super.key});

  @override
  State<HealthStatsScreen> createState() => _HealthStatsScreenState();
}

class _HealthStatsScreenState extends State<HealthStatsScreen> {
  final HealthService healthService = HealthService(app: Firebase.app());
  int _selectedIndex = 1;
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
          "Health Stats",
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
                'No data available',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            );
          }

          final data = snapshot.data!;

          Color getHeartRateColor(double hr) =>
              (hr < 60 || hr > 100) ? Colors.red : Colors.green;
          Color getSpO2Color(double spo2) =>
              (spo2 < 95) ? Colors.red : Colors.green;
          Color getEnvTempColor(double temp) =>
              (temp < 18 || temp > 35) ? Colors.red : Colors.green;
          Color getHumanTempColor(double temp) =>
              (temp < 97 || temp > 99.5) ? Colors.red : Colors.green;
          Color getHumidityColor(double hum) =>
              (hum < 30 || hum > 60) ? Colors.orange : Colors.green;

          final indicators = [
            {
              "icon": Icons.favorite,
              "label": "Heart Rate",
              "value": "${data.heartRate} bpm",
              "color": getHeartRateColor(data.heartRate),
            },
            {
              "icon": Icons.bloodtype,
              "label": "SpO2",
              "value": "${data.spo2} %",
              "color": getSpO2Color(data.spo2),
            },
            {
              "icon": Icons.thermostat_rounded,
              "label": "Env Temp",
              "value": "${data.environmentTemperatureC} °C",
              "color": getEnvTempColor(data.environmentTemperatureC),
            },
            {
              "icon": Icons.thermostat,
              "label": "Human Temp",
              "value": "${data.humanTemperatureF} °F",
              "color": getHumanTempColor(data.humanTemperatureF),
            },
            {
              "icon": Icons.water_drop,
              "label": "Humidity",
              "value": "${data.humidity} %",
              "color": getHumidityColor(data.humidity),
            },
          ];

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
                  "Health Overview 🩺",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Monitor real-time vitals & environment",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                ...indicators.map(
                  (ind) => _buildIndicatorCard(
                    icon: ind["icon"] as IconData,
                    label: ind["label"] as String,
                    value: ind["value"] as String,
                    color: ind["color"] as Color,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(18),
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
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => SosScreen()),
            );
          } else if (index == 1) {
            // Stay here
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => MapScreen()),
            );
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

  Widget _buildIndicatorCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
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
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        trailing: Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
