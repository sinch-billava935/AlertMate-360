import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'sos_screen.dart';
import 'health_stats_screen.dart';
import 'map_screen.dart';
import 'emergency_contacts_screen.dart';
import 'login_screen.dart';
import 'account_details_screen.dart';
import 'settings_screen.dart';
import '../services/speech_detection_service.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;
  final SettingsService _settingsService = SettingsService();

  User? _user;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  String _username = 'User';
  String _email = 'no-email@example.com';
  bool _loading = true;

  // Voice trigger state
  bool _voiceTriggerEnabled = false;
  SpeechDetectionService? _speechService;
  bool _isListening = false;
  String _speechStatus = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _user = _auth.currentUser;
    _email = _user?.email ?? 'no-email@example.com';
    _subscribeToUserDoc();
    _loadVoiceTriggerSetting();

    // ✅ Initialize FCM notification service
    // NotificationService.init();
    Future.microtask(() => NotificationService.init());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      _stopVoiceTrigger();
    } else if (state == AppLifecycleState.resumed && _voiceTriggerEnabled) {
      _startVoiceTrigger();
    }
  }

  void _subscribeToUserDoc() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _username = _auth.currentUser?.displayName ?? 'User';
        _loading = false;
      });
      return;
    }

    final docRef = _fs.collection('users').doc(uid);
    _docSub = docRef.snapshots().listen(
      (snap) {
        if (!mounted) return;
        final data = snap.data();
        final fromFs = (data?['username'] as String?)?.trim();
        setState(() {
          _username =
              fromFs != null && fromFs.isNotEmpty
                  ? fromFs
                  : (_auth.currentUser?.displayName ?? 'User');
          _email = _auth.currentUser?.email ?? _email;
          _loading = false;
        });
      },
      onError: (e) {
        debugPrint('Failed to listen to user doc: $e');
        if (mounted) {
          setState(() {
            _username = _auth.currentUser?.displayName ?? 'User';
            _loading = false;
          });
        }
      },
    );
  }

  Future<void> _loadVoiceTriggerSetting() async {
    final enabled = await _settingsService.isVoiceTriggerEnabled();
    setState(() {
      _voiceTriggerEnabled = enabled;
    });

    if (enabled) {
      _initVoiceTrigger();
    }
  }

  Future<void> _initVoiceTrigger() async {
    _speechService = SpeechDetectionService(
      onHelpDetected: _onHelpDetected,
      onError: _onSpeechError,
      onStatusUpdate: _onSpeechStatusUpdate,
    );

    final initialized = await _speechService!.initialize();
    if (initialized && _voiceTriggerEnabled) {
      await _startVoiceTrigger();
    }
  }

  Future<void> _startVoiceTrigger() async {
    if (_speechService == null || _isListening) return;

    try {
      _speechService!.startListening();
      setState(() {
        _isListening = true;
        _speechStatus = 'Listening for "help"...';
      });
    } catch (e) {
      debugPrint('Failed to start voice trigger: $e');
    }
  }

  Future<void> _stopVoiceTrigger() async {
    if (_speechService == null || !_isListening) return;

    try {
      _speechService!.stopListening();
      setState(() {
        _isListening = false;
        _speechStatus = '';
      });
    } catch (e) {
      debugPrint('Failed to stop voice trigger: $e');
    }
  }

  void _onHelpDetected() {
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Detected 'help' - Triggering SOS"),
        duration: Duration(seconds: 2),
      ),
    );

    // Trigger SOS flow
    Navigator.push(context, MaterialPageRoute(builder: (_) => SosScreen()));
  }

  void _onSpeechError(String error) {
    debugPrint('Speech detection error: $error');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voice trigger error: $error'),
        duration: const Duration(seconds: 3),
      ),
    );

    // Auto-restart on error
    if (_voiceTriggerEnabled) {
      Future.delayed(Duration(seconds: 2), _startVoiceTrigger);
    }
  }

  void _onSpeechStatusUpdate(String status) {
    if (mounted) {
      setState(() {
        _speechStatus = status;
      });
    }
  }

  Future<void> _toggleVoiceTrigger(bool enabled) async {
    await _settingsService.setVoiceTriggerEnabled(enabled);
    setState(() {
      _voiceTriggerEnabled = enabled;
    });

    if (enabled) {
      if (_speechService == null) {
        await _initVoiceTrigger();
      } else {
        await _startVoiceTrigger();
      }
    } else {
      await _stopVoiceTrigger();
    }
  }

  @override
  void dispose() {
    _docSub?.cancel();
    _speechService?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _signOut() async {
    await _stopVoiceTrigger();

    // // remove token from DB before signing out
    // final uid = _auth.currentUser?.uid;
    // if (uid != null) {
    //   await NotificationService.removeFcmTokenFromDatabase(uid);
    // }

    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _username;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7FF),
      appBar: AppBar(
        title: const Text(
          "AlertMate 360",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF3E82C6),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => SettingsScreen(
                        initialVoiceTriggerState: _voiceTriggerEnabled,
                        onVoiceTriggerChanged: _toggleVoiceTrigger,
                      ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => AccountDetailsScreen(
                        onUsernameChanged: (newName) async {},
                      ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    Text(
                      "Welcome, $displayName!",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Your safety companion for health monitoring & instant SOS.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 30),

                    // Voice Trigger Status and Feedback
                    if (_voiceTriggerEnabled)
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mic, color: Colors.green, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  "Voice trigger active",
                                  style: TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                          if (_speechStatus.isNotEmpty)
                            Text(
                              _speechStatus,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // SOS Feature Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 32,
                        ),
                        title: const Text("Trigger SOS"),
                        subtitle: const Text(
                          "Send an emergency alert with location",
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SosScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Health Stats Feature Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.monitor_heart,
                          color: Colors.green,
                          size: 32,
                        ),
                        title: const Text("Health Stats"),
                        subtitle: const Text(
                          "Track SpO2, heart rate, and temperature",
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HealthStatsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Map Feature Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.map_rounded,
                          color: Colors.blue,
                          size: 32,
                        ),
                        title: const Text("Map View"),
                        subtitle: const Text("View your current location"),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => MapScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Emergency Contacts Feature Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.contacts,
                          color: Colors.deepPurple,
                          size: 32,
                        ),
                        title: const Text("Emergency Contacts"),
                        subtitle: const Text(
                          "Manage your emergency contact list",
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EmergencyContactsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Spacer(),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text(
                          "Logout",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _signOut,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
      ),
    );
  }
}
