import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';

class SosScreen extends StatefulWidget {
  @override
  _SosScreenState createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool sosTriggered = false;
  bool isLoading = false;

  /// Fetch current location (optional)
  Future<Map<String, double?>> _getLocation() async {
    Location location = Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await location.requestService();
    if (!serviceEnabled) return {};

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
    }
    if (permissionGranted != PermissionStatus.granted) return {};

    final locData = await location.getLocation();
    return {'latitude': locData.latitude, 'longitude': locData.longitude};
  }

  /// Send SOS data to Firestore (Triggers Cloud Function)
  Future<void> _sendSosToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    // Optionally include location
    final loc = await _getLocation();

    final sosData = {
      'timestamp': FieldValue.serverTimestamp(),
      'latitude': loc['latitude'],
      'longitude': loc['longitude'],
    };

    final sosRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('sos')
        .add(sosData);

    print("🚨 SOS document created at path: ${sosRef.path}");
  }

  /// Trigger SOS with confirmation dialog
  void _triggerSos() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Confirm Emergency Alert"),
            content: const Text(
              "Are you sure you want to trigger the SOS alert?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  setState(() => isLoading = true);

                  try {
                    await _sendSosToFirestore();

                    setState(() {
                      isLoading = false;
                      sosTriggered = true;
                    });

                    // Disable the button for 5 seconds
                    Future.delayed(const Duration(seconds: 5), () {
                      if (mounted) {
                        setState(() => sosTriggered = false);
                      }
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("🚨 SOS Alert Triggered Successfully!"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  } catch (e) {
                    setState(() => isLoading = false);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("⚠️ Failed to send SOS alert: $e"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                child: const Text("Yes, Trigger"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        title: const Text("SOS Alert"),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 90,
            ),
            const SizedBox(height: 20),
            Text(
              sosTriggered
                  ? "Please wait... You can trigger another SOS after a few seconds."
                  : "Tap the button below to send an emergency alert.",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon:
                  isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.emergency),
              label: Text(
                isLoading
                    ? "Sending..."
                    : (sosTriggered ? "Please Wait..." : "Trigger SOS"),
              ),
              onPressed: (sosTriggered || isLoading) ? null : _triggerSos,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    (sosTriggered || isLoading) ? Colors.grey : Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 40),
            if (sosTriggered)
              const Text(
                "⏳ Button re-enabled in 5 seconds...",
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            const Spacer(),
            const Text(
              "Stay calm. You're not alone.",
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
