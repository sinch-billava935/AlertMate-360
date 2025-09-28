import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/health_service.dart';
import '../models/health_data.dart';

class MapScreen extends StatelessWidget {
  MapScreen({super.key});

  final HealthService healthService = HealthService(app: Firebase.app());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Location Stats",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<HealthData?>(
        stream: healthService.getHealthDataStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("No location data available"));
          }

          final data = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildIndicator(
                  label: "📍 Latitude",
                  value: "${data.latitude}",
                ),
                _buildIndicator(
                  label: "📍 Longitude",
                  value: "${data.longitude}",
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

  // Reusable card for displaying info
  Widget _buildIndicator({
    required String label,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 18)),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }
}
