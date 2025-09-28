import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/health_service.dart';
import '../models/health_data.dart';

class HealthStatsScreen extends StatelessWidget {
  HealthStatsScreen({super.key});

  final HealthService healthService = HealthService(app: Firebase.app());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Health Stats",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 62, 130, 198),
      ),
      body: StreamBuilder<HealthData?>(
        stream: healthService.getHealthDataStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No data available'));
          }

          final data = snapshot.data!;

          // Function to color-code values
          Color getHeartRateColor(double hr) =>
              (hr < 60 || hr > 100) ? Colors.red : Colors.green;
          Color getSpO2Color(double spo2) =>
              (spo2 < 95) ? Colors.red : Colors.green;
          Color getEnvTempColor(double temp) =>
              (temp < 18 || temp > 35) ? Colors.red : Colors.green;
          Color getHumanTempColor(double temp) =>
              (temp < 97 || temp > 99.5) ? Colors.red : Colors.green; // in °F
          Color getHumidityColor(double hum) =>
              (hum < 30 || hum > 60) ? Colors.orange : Colors.green;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildIndicator(
                  label: "❤ Heart Rate",
                  value: "${data.heartRate} bpm",
                  color: getHeartRateColor(data.heartRate),
                ),
                _buildIndicator(
                  label: "🩸 SpO2",
                  value: "${data.spo2} %",
                  color: getSpO2Color(data.spo2),
                ),
                _buildIndicator(
                  label: "🌡 Environment Temp",
                  value: "${data.environmentTemperatureC} °C",
                  color: getEnvTempColor(data.environmentTemperatureC),
                ),
                _buildIndicator(
                  label: "🌡 Human Temp",
                  value: "${data.humanTemperatureF} °F",
                  color: getHumanTempColor(data.humanTemperatureF),
                ),
                _buildIndicator(
                  label: "💧 Humidity",
                  value: "${data.humidity} %",
                  color: getHumidityColor(data.humidity),
                ),
                const SizedBox(height: 16),
                Text(
                  "Last Updated: ${DateTime.fromMillisecondsSinceEpoch(data.timestamp)}",
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper widget for colored indicator
  Widget _buildIndicator({
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 18)),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
