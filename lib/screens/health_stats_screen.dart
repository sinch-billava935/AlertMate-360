import 'package:flutter/material.dart';

class HealthStatsScreen extends StatelessWidget {
  // Temporary mock values – replace later with real-time data
  final int heartRate = 76;
  final int spo2 = 97;
  final double temperature = 36.8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Health Stats", style: TextStyle(color: Colors.white)),
        backgroundColor: Color.fromARGB(255, 62, 130, 198),
      ),
      backgroundColor: Color(0xFFF2F7FF), // Light background
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            SizedBox(height: 20),
            Text(
              "Your Health Summary",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 30),

            // Heart Rate Card
            _buildStatCard(
              context,
              title: "Heart Rate",
              value: "$heartRate bpm",
              icon: Icons.favorite,
              iconColor: Colors.red,
            ),

            // SpO2 Card
            _buildStatCard(
              context,
              title: "SpO₂ Level",
              value: "$spo2%",
              icon: Icons.bloodtype,
              iconColor: Colors.blue,
            ),

            // Temperature Card
            _buildStatCard(
              context,
              title: "Body Temperature",
              value: "$temperature °C",
              icon: Icons.thermostat_rounded,
              iconColor: Colors.orange,
            ),

            Spacer(),
            Text(
              "Monitor your vitals regularly",
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.symmetric(vertical: 12),
      elevation: 4,
      child: ListTile(
        leading: Icon(icon, size: 36, color: iconColor),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
