import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Existing functions here...

  /// Initialize FCM and store the token in Firestore
  Future<void> setupFCM() async {
    final fcm = FirebaseMessaging.instance;

    // Request notification permission
    await fcm.requestPermission(alert: true, badge: true, sound: true);

    // Get device FCM token
    final token = await fcm.getToken();
    if (token != null) {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }
}
