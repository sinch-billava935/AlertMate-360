import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';

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

  bool _voiceTriggerEnabled = false;
  SpeechDetectionService? _speechService;
  bool _isListening = false;
  String _speechStatus = '';

  int _selectedIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _selectedIndex);

    _user = _auth.currentUser;
    _email = _user?.email ?? 'no-email@example.com';
    _subscribeToUserDoc();
    _loadVoiceTriggerSetting();
    _setupNotificationListeners();
    Future.microtask(() => NotificationService.init());
  }

  void _setupNotificationListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      NotificationService.showNotification(
        title: message.notification?.title ?? 'AlertMate 360',
        body: message.notification?.body ?? 'You have a new alert',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _pageController.jumpToPage(1); // Navigate to SOS screen
    });
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
    _docSub = docRef.snapshots().listen((snap) {
      if (!mounted) return;
      final data = snap.data();
      final fromFs = (data?['username'] as String?)?.trim();
      setState(() {
        _username =
            fromFs?.isNotEmpty == true
                ? fromFs!
                : (_auth.currentUser?.displayName ?? 'User');
        _email = _auth.currentUser?.email ?? _email;
        _loading = false;
      });
    });
  }

  Future<void> _loadVoiceTriggerSetting() async {
    final enabled = await _settingsService.isVoiceTriggerEnabled();
    setState(() => _voiceTriggerEnabled = enabled);
    if (enabled) _initVoiceTrigger();
  }

  Future<void> _initVoiceTrigger() async {
    _speechService = SpeechDetectionService(
      onHelpDetected: _onHelpDetected,
      onError: _onSpeechError,
      onStatusUpdate: _onSpeechStatusUpdate,
    );
    final initialized = await _speechService!.initialize();
    if (initialized && _voiceTriggerEnabled) await _startVoiceTrigger();
  }

  Future<void> _startVoiceTrigger() async {
    if (_speechService == null || _isListening) return;
    _speechService!.startListening();
    setState(() {
      _isListening = true;
      _speechStatus = 'Listening for "help"...';
    });
  }

  Future<void> _stopVoiceTrigger() async {
    if (_speechService == null || !_isListening) return;
    _speechService!.stopListening();
    setState(() {
      _isListening = false;
      _speechStatus = '';
    });
  }

  void _onHelpDetected() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Detected 'help' - Triggering SOS")),
    );
    _pageController.jumpToPage(1); // Navigate to SOS screen
  }

  void _onSpeechError(String error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Voice trigger error: $error')));
    if (_voiceTriggerEnabled)
      Future.delayed(const Duration(seconds: 2), _startVoiceTrigger);
  }

  void _onSpeechStatusUpdate(String status) {
    if (mounted) setState(() => _speechStatus = status);
  }

  Future<void> _toggleVoiceTrigger(bool enabled) async {
    await _settingsService.setVoiceTriggerEnabled(enabled);
    setState(() => _voiceTriggerEnabled = enabled);
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
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _signOut() async {
    await _stopVoiceTrigger();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
        onTap: onTap,
      ),
    );
  }

  Widget _buildHomeContent() {
    final displayName = _username;
    const Color accentColor = Color(0xFF3E82C6);

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
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
                "Welcome, $displayName 👋",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your safety companion for health & SOS alerts",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_voiceTriggerEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        "Voice trigger active",
                        style: GoogleFonts.poppins(color: Colors.green),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 1),
              _buildFeatureCard(
                icon: Icons.warning_amber_rounded,
                color: Colors.redAccent,
                title: "Trigger SOS",
                subtitle: "Send emergency alert with live location",
                onTap: () => _pageController.jumpToPage(1),
              ),
              _buildFeatureCard(
                icon: Icons.monitor_heart,
                color: Colors.teal,
                title: "Health Stats",
                subtitle: "Monitor SpO2, heart rate & temperature",
                onTap: () => _pageController.jumpToPage(2),
              ),
              _buildFeatureCard(
                icon: Icons.map_rounded,
                color: Colors.blueAccent,
                title: "Map View",
                subtitle: "Track your current location in real time",
                onTap: () => _pageController.jumpToPage(3),
              ),
              _buildFeatureCard(
                icon: Icons.contacts_rounded,
                color: Colors.deepPurple,
                title: "Emergency Contacts",
                subtitle: "Manage your emergency contact list",
                onTap: () => _pageController.jumpToPage(4),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: Text(
                  "Logout",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _signOut,
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const Color accentColor = Color(0xFF3E82C6);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E1117) : const Color(0xFFF4F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: accentColor,
        centerTitle: true,
        title: Text(
          "AlertMate 360",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => SettingsScreen(
                        initialVoiceTriggerState: _voiceTriggerEnabled,
                        onVoiceTriggerChanged: _toggleVoiceTrigger,
                      ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.account_circle_outlined,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => AccountDetailsScreen(
                        onUsernameChanged: (newName) async {},
                      ),
                ),
              );
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        children: [
          _buildHomeContent(),
          SosScreen(
            selectedIndex: _selectedIndex,
            onTabChanged: (index) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
          HealthStatsScreen(
            selectedIndex: _selectedIndex,
            onTabChanged: (index) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
          MapScreen(
            selectedIndex: _selectedIndex,
            onTabChanged: (index) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
          EmergencyContactsScreen(
            selectedIndex: _selectedIndex,
            onTabChanged: (index) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: accentColor,
        unselectedItemColor: Colors.black54,
        currentIndex: _selectedIndex,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_rounded),
            label: "Trigger SOS",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: "Health",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: "Map"),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts_rounded),
            label: "Contacts",
          ),
        ],
      ),
    );
  }
}
