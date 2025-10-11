import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'alert_history_screen.dart';
import 'health_stats_screen.dart';
import 'map_screen.dart';
import 'sos_screen.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  _EmergencyContactsScreenState createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationController = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser!.uid;

  static const String _verifyBase =
      'https://asia-south1-alertmatefb-a1c17.cloudfunctions.net/verify';
  final Uri _startVerificationUri = Uri.parse(
    '$_verifyBase/start-verification',
  );
  final Uri _checkVerificationUri = Uri.parse(
    '$_verifyBase/check-verification',
  );

  bool _busy = false;

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final idToken = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }

  bool _looksLikeE164(String s) {
    final re = RegExp(r'^\+\d{7,15}$');
    return re.hasMatch(s.trim());
  }

  String _toE164IndiaIfNeeded(String input) {
    final t = input.trim();
    if (t.startsWith('+')) return t;
    if (RegExp(r'^\d{10}$').hasMatch(t)) return '+91$t';
    return t;
  }

  Future<void> _startVerification(String phoneE164) async {
    final headers = await _authHeaders();
    final res = await http.post(
      _startVerificationUri,
      headers: headers,
      body: jsonEncode({'phone': phoneE164}),
    );
    if (res.statusCode >= 400) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      throw Exception(body?['error'] ?? 'Failed to start verification');
    }
  }

  Future<bool> _checkVerification(String phoneE164, String code) async {
    final headers = await _authHeaders();
    final res = await http.post(
      _checkVerificationUri,
      headers: headers,
      body: jsonEncode({'phone': phoneE164, 'code': code}),
    );
    if (res.statusCode >= 400) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      throw Exception(body?['error'] ?? 'Failed to check verification');
    }
    final body = jsonDecode(res.body);
    return body['status'] == 'approved';
  }

  Future<String?> _promptForOtp(String phone) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              'Verify contact',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter the OTP sent to $phone',
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(hintText: '6-digit OTP'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await _startVerification(phone);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('OTP resent')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Resend failed: $e')),
                      );
                    }
                  }
                },
                child: Text('Resend', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                onPressed: () {
                  final code = ctrl.text.trim();
                  Navigator.of(ctx).pop(code.isEmpty ? null : code);
                },
                child: Text(
                  'Verify',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _addContact() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) return;

    final phoneE164 = _toE164IndiaIfNeeded(_phoneController.text);
    if (!_looksLikeE164(phoneE164)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phone must be E.164, e.g. +919876543210',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      await _startVerification(phoneE164);

      final code = await _promptForOtp(phoneE164);
      if (code == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification canceled',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        setState(() => _busy = false);
        return;
      }

      final ok = await _checkVerification(phoneE164, code);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Incorrect or expired code',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        setState(() => _busy = false);
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('emergency_contacts')
          .add({
            'name': _nameController.text.trim(),
            'phone': phoneE164,
            'relation': _relationController.text.trim(),
            'verified': true,
            'timestamp': FieldValue.serverTimestamp(),
          });

      _nameController.clear();
      _phoneController.clear();
      _relationController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Contact added & verified',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _deleteContact(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('emergency_contacts')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF3E82C6);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text(
          "Emergency Contacts",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: accentColor,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            Image.asset('assets/logo/new_shield.png', width: 100, height: 100),
            const SizedBox(height: 12),
            Text(
              "Emergency Contacts 👥",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Manage your emergency contact list for quick assistance when needed.",
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "➕ Add New Contact",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Name",
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Phone Number",
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _relationController,
                      decoration: InputDecoration(
                        labelText: "Relationship",
                        prefixIcon: const Icon(Icons.people_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text(
                          _busy ? "Please wait..." : "Add Contact",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 6,
                        ),
                        onPressed: _busy ? null : _addContact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('emergency_contacts')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error loading contacts",
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final contacts = snapshot.data!.docs;

                if (contacts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.contacts, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        Text(
                          "No emergency contacts added yet.",
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.person, color: Colors.blue),
                        ),
                        title: Text(
                          contact['name'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact['phone'],
                              style: GoogleFonts.poppins(),
                            ),
                            if (contact['relation'] != null &&
                                contact['relation']
                                    .toString()
                                    .trim()
                                    .isNotEmpty)
                              Text(
                                "Relation: ${contact['relation']}",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteContact(contact.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: accentColor,
        unselectedItemColor: Colors.black54,
        currentIndex: 3,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SosScreen()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HealthStatsScreen()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => MapScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_rounded),
            label: "Trigger SOS",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: "Health",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_rounded),
            label: "Map View",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts_rounded),
            label: "Contacts",
          ),
        ],
      ),
    );
  }
}
