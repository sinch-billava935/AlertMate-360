// lib/screens/home_screen.dart
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  User? _user;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  String _username = 'User';
  String _email = 'no-email@example.com';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _email = _user?.email ?? 'no-email@example.com';
    _subscribeToUserDoc();
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

  @override
  void dispose() {
    _docSub?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
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
    final email = _email;

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
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => AccountDetailsScreen(
                        // AccountDetailsScreen will default to current user and Firestore
                        onUsernameChanged: (newName) async {
                          // optional: handle extra tasks if needed
                        },
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
