import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  // ✅ Your deployed HTTPS function base and routes
  static const String _verifyBase =
      'https://asia-south1-alertmatefb-a1c17.cloudfunctions.net/verify';
  final Uri _startVerificationUri = Uri.parse(
    '$_verifyBase/start-verification',
  );
  final Uri _checkVerificationUri = Uri.parse(
    '$_verifyBase/check-verification',
  );

  bool _busy = false;

  // ---------------- Helpers ----------------

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final idToken = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }

  // Simple E.164 check; use libphonenumber for production
  bool _looksLikeE164(String s) {
    final re = RegExp(r'^\+\d{7,15}$');
    return re.hasMatch(s.trim());
  }

  // Convenience: if user types 10 digits (India), auto-prefix +91
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
            title: const Text('Verify contact'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter the OTP sent to $phone'),
                const SizedBox(height: 8),
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
                child: const Text('Cancel'),
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
                child: const Text('Resend'),
              ),
              ElevatedButton(
                onPressed: () {
                  final code = ctrl.text.trim();
                  Navigator.of(ctx).pop(code.isEmpty ? null : code);
                },
                child: const Text('Verify'),
              ),
            ],
          ),
    );
  }

  // --------------- Add Contact ---------------

  void _addContact() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) return;

    // Normalize phone to E.164 (auto +91 for 10 digits)
    final phoneE164 = _toE164IndiaIfNeeded(_phoneController.text);
    if (!_looksLikeE164(phoneE164)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone must be E.164, e.g. +919876543210'),
        ),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      // 1) Send OTP
      await _startVerification(phoneE164);

      // 2) Prompt for OTP
      final code = await _promptForOtp(phoneE164);
      if (code == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Verification canceled')));
        setState(() => _busy = false);
        return;
      }

      // 3) Verify OTP with function
      final ok = await _checkVerification(phoneE164, code);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect or expired code')),
        );
        setState(() => _busy = false);
        return;
      }

      // 4) Save contact as verified = true
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
          const SnackBar(content: Text('Contact added & verified')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  // --------------- UI (unchanged) ---------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F7FF),
      appBar: AppBar(
        title: Text(
          "Emergency Contacts",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF3E82C6),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "➕ Add New Contact",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003366),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Name",
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: "Phone Number",
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _relationController,
                      decoration: InputDecoration(
                        labelText: "Relationship",
                        prefixIcon: Icon(Icons.people_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _addContact,
                        icon: Icon(Icons.add, color: Colors.white),
                        label: Text(
                          _busy ? "Please wait…" : "Add Contact",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0055A4),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('emergency_contacts')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Error loading contacts"));
                  }
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final contacts = snapshot.data!.docs;

                  if (contacts.isEmpty) {
                    return Center(
                      child: Column(
                        children: [
                          Icon(Icons.contacts, size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("No emergency contacts added yet."),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: EdgeInsets.symmetric(vertical: 6),
                        elevation: 3,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Icon(Icons.person, color: Colors.blue),
                          ),
                          title: Text(
                            contact['name'],
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(contact['phone']),
                              if (contact['relation'] != null &&
                                  contact['relation']
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                                Text(
                                  "Relation: ${contact['relation']}",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteContact(contact.id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
