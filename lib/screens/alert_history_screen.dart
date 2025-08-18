// lib/screens/alert_history_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlertHistoryScreen extends StatelessWidget {
  const AlertHistoryScreen({super.key});

  String _formatDate(DateTime dt) {
    // Simple formatter: yyyy-MM-dd HH:mm:ss
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Alert History",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          user == null
              ? const Center(child: Text("Please log in to view alerts."))
              : StreamBuilder<QuerySnapshot>(
                // Read from users/{uid}/sos ordered by timestamp desc
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('sos')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading history: ${snapshot.error}'),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text("No alerts yet. Tap SOS to trigger one."),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final data =
                          docs[i].data() as Map<String, dynamic>? ?? {};
                      final name = (data['userName'] ?? 'Unknown').toString();
                      final lat = (data['latitude'] as num?)?.toDouble();
                      final lon = (data['longitude'] as num?)?.toDouble();
                      final ts = (data['timestamp'] as Timestamp?)?.toDate();

                      final subtitleLines = <String>[];
                      if (lat != null && lon != null) {
                        subtitleLines.add('Location: $lat, $lon');
                      }
                      if (ts != null) {
                        subtitleLines.add('Time: ${_formatDate(ts.toLocal())}');
                      }

                      return ListTile(
                        leading: const Icon(Icons.warning, color: Colors.red),
                        title: Text('SOS triggered by $name'),
                        subtitle: Text(subtitleLines.join('\n')),
                        dense: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
