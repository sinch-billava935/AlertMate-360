import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/voice_trigger_service.dart';
import 'alert_history_screen.dart';

class SosScreen extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const SosScreen({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool sosTriggered = false;
  bool isLoading = false;

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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("🚨 SOS Alert Triggered Successfully!"),
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
                "Didn't catch that. Try saying 'SOS' or 'Help me'.",
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const Color accentColor = Color(0xFF3E82C6);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E1117) : const Color(0xFFF4F6FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Image.asset('assets/logo/new_shield.png', width: 100, height: 100),
            const SizedBox(height: 16),
            Text(
              "Emergency SOS Trigger",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Tap the button or say 'HELP' to send an emergency alert.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 30),
            _buildFeatureButton(
              icon: Icons.warning_rounded,
              color: Colors.redAccent,
              label: isLoading ? "Sending..." : "TRIGGER SOS",
              onTap: (sosTriggered || isLoading) ? null : _confirmAndTrigger,
            ),
            const SizedBox(height: 16),
            _buildFeatureButton(
              icon: Icons.mic,
              color: accentColor,
              label: _startingVoice ? "Listening..." : "VOICE SOS",
              onTap:
                  (_startingVoice || isLoading) ? null : _startVoiceListening,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  sosTriggered
                      ? "🚨 SOS Alert Triggered! Stay calm. Help is on the way."
                      : "Stay calm. Help is on the way.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: sosTriggered ? Colors.redAccent : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      // <-- Added: FloatingActionButton that opens AlertHistoryScreen
      floatingActionButton: FloatingActionButton(
        heroTag: 'sosHistoryFab',
        tooltip: 'Alert History',
        child: const Icon(Icons.history),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AlertHistoryScreen()),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback? onTap,
  }) {
    return AnimatedOpacity(
      opacity: (onTap == null) ? 0.7 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), Colors.white],
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 26),
                  const SizedBox(width: 18),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
