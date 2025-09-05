import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';

import '../services/voice_trigger_service.dart';
import 'alert_history_screen.dart';

class SosScreen extends StatefulWidget {
  @override
  _SosScreenState createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool sosTriggered = false;
  bool isLoading = false;

  // 👇 Voice
  final _voice = VoiceTriggerService();
  bool _voiceReady = false;
  bool _startingVoice = false;
  final List<String> _keywords = [
    'sos',
    'help',
    'help me',
    'emergency',
    'alert',
  ];

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    final ok = await _voice.init();
    if (mounted) setState(() => _voiceReady = ok);
  }

  /// Fetch current location
  Future<Map<String, double?>> _getLocation() async {
    final location = Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await location.requestService();
    if (!serviceEnabled) return {};

    var permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
    }
    if (permissionGranted != PermissionStatus.granted) return {};

    final locData = await location.getLocation();
    return {'latitude': locData.latitude, 'longitude': locData.longitude};
  }

  /// Send SOS data to Firestore
  Future<void> _sendSosToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    final data = userDoc.data() ?? {};
    final userName = (data['username'] ?? data['name'] ?? 'Unknown').toString();

    final loc = await _getLocation();

    final sosData = {
      'userName': userName,
      'timestamp': FieldValue.serverTimestamp(),
      'latitude': loc['latitude'],
      'longitude': loc['longitude'],
      'triggeredBy': user.uid,
      'triggerSource': 'voice_or_button',
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('sos')
        .add(sosData);
  }

  /// Confirm + trigger
  void _confirmAndTrigger() {
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
                  await _performTrigger();
                },
                child: const Text(
                  "Yes, Trigger",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _performTrigger() async {
    setState(() => isLoading = true);
    try {
      await _sendSosToFirestore();

      if (!mounted) return;
      setState(() {
        isLoading = false;
        sosTriggered = true;
      });

      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => sosTriggered = false);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "🚨 SOS Alert Triggered Successfully!",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: "View History",
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertHistoryScreen()),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚠️ Failed to send SOS alert: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Voice listening flow
  Future<void> _startVoiceListening() async {
    if (_startingVoice || !_voiceReady) return;

    setState(() => _startingVoice = true);

    if (!_voice.isAvailable) {
      final ok = await _voice.init();
      if (!ok) {
        setState(() => _startingVoice = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Speech recognition not available on this device."),
          ),
        );
        return;
      }
    }

    await _voice.startListening(
      listenFor: const Duration(seconds: 8),
      onFinalResult: (finalText) async {
        setState(() => _startingVoice = false);
        if (finalText.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Didn't catch that. Try saying: 'SOS' or 'Help me'.",
              ),
            ),
          );
          return;
        }

        if (_voice.matchesTrigger(finalText, _keywords)) {
          await _performTrigger();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Heard: \"$finalText\" — no trigger word detected.",
              ),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        title: const Text("SOS Alert", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: "History",
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlertHistoryScreen()),
              );
            },
          ),
        ],
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
                  : "Tap the button below or use voice ('SOS', 'Help me') to send an emergency alert.",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Trigger SOS button
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
                      : const Icon(Icons.emergency, color: Colors.white),
              label: Text(
                isLoading
                    ? "Sending..."
                    : (sosTriggered ? "Please Wait..." : "Trigger SOS"),
                style: const TextStyle(color: Colors.white),
              ),
              onPressed:
                  (sosTriggered || isLoading) ? null : _confirmAndTrigger,
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

            const SizedBox(height: 20),

            // Voice SOS button (now below Trigger SOS)
            ElevatedButton.icon(
              icon: const Icon(Icons.mic, color: Colors.white),
              label: Text(
                _startingVoice ? "Listening..." : "Voice SOS",
                style: const TextStyle(color: Colors.white),
              ),
              onPressed:
                  (_startingVoice || isLoading) ? null : _startVoiceListening,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _startingVoice ? Colors.grey : Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                textStyle: const TextStyle(fontSize: 18),
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
