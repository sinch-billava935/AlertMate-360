import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlertHistoryScreen extends StatelessWidget {
  const AlertHistoryScreen({super.key});

  String _formatDate(DateTime dt) {
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      appBar: AppBar(
        title: const Text(
          "Alert History",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          user == null
              ? const Center(child: Text("Please log in to view alerts."))
              : StreamBuilder<QuerySnapshot>(
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
                      child: Text(
                        "No alerts yet. Tap SOS to trigger one.",
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final data =
                          docs[i].data() as Map<String, dynamic>? ?? {};
                      final name = (data['userName'] ?? 'Unknown').toString();
                      final lat = (data['latitude'] as num?)?.toDouble();
                      final lon = (data['longitude'] as num?)?.toDouble();
                      final ts = (data['timestamp'] as Timestamp?)?.toDate();

                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.shade100,
                            child: const Icon(Icons.warning, color: Colors.red),
                          ),
                          title: Text(
                            'SOS triggered by $name',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (lat != null && lon != null)
                                Text('Location: $lat, $lon'),
                              if (ts != null)
                                Text('Time: ${_formatDate(ts.toLocal())}'),
                            ],
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
