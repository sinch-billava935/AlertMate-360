import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Initialize FCM and sync token to RTDB + Firestore
  static Future<void> init() async {
    try {
      // Request permission (iOS only, harmless on Android)
      await _fcm.requestPermission();

      // Get current user
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, skipping token save');
        return;
      }

      // Get token
      String? token = await _fcm.getToken();
      if (token == null) {
        print('⚠️ FCM token is null');
        return;
      }

      final uid = user.uid;

      // ✅ RTDB path: users/{uid}/fcmToken
      final rtdbRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            "https://alertmatefb-a1c17-default-rtdb.asia-southeast1.firebasedatabase.app",
      ).ref("users/$uid/fcmToken");

      await rtdbRef.set(token);
      print('✅ Token saved to RTDB for $uid');

      // ✅ Firestore path: users/{uid}
      final firestoreRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);

      await firestoreRef.set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ Token saved to Firestore for $uid');

      // 🔄 Token refresh listener
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await rtdbRef.set(newToken);
        await firestoreRef.set({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('🔄 Token refreshed and updated everywhere');
      });
    } catch (e) {
      print('❌ FCM init error: $e');
    }
  }
}
