import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/health_data.dart';

class HealthService {
  final FirebaseApp app; // Required FirebaseApp

  HealthService({required this.app});

  // Connect to the correct regional Firebase Realtime Database
  late final DatabaseReference _db =
      FirebaseDatabase.instanceFor(
        app: app,
        databaseURL:
            "https://alertmatefb-a1c17-default-rtdb.asia-southeast1.firebasedatabase.app",
      ).ref();

  final _auth = FirebaseAuth.instance;

  /// Stream of health data from Realtime Database
  Stream<HealthData?> getHealthDataStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty(); // User not logged in

    final userRef = _db.child("users/$uid/sensors");

    return userRef.onValue.map((event) {
      final snapshot = event.snapshot;

      if (!snapshot.exists || snapshot.value == null) {
        return null; // No data yet
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);

      return HealthData(
        heartRate: (data["heartRate"] ?? 0).toDouble(),
        spo2: (data["spo2"] ?? 0).toDouble(),
        temperature: (data["temperature"] ?? 0).toDouble(),
        humidity: (data["humidity"] ?? 0).toDouble(),
        timestamp: (data["timestamp"] ?? 0),
      );
    });
  }
}