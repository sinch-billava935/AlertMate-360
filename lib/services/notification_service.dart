import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize FCM, local notifications and sync token
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 🔸 Local notification setup
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    await _localNotifications.initialize(initSettings);

    // 🔸 Request FCM permission (iOS)
    await _fcm.requestPermission();

    // ✅ Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Foreground message: ${message.notification?.title}');
      showNotification(
        title: message.notification?.title ?? 'AlertMate',
        body: message.notification?.body ?? 'Emergency alert received.',
      );
    });

    // ✅ Handle background token registration
    await _syncToken();

    // 🔄 Token refresh listener
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _updateToken(newToken);
    });
  }

  /// Sync current token to RTDB and Firestore
  static Future<void> _syncToken() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, skipping token save');
        return;
      }

      String? token = await _fcm.getToken();
      if (token == null) {
        print('⚠️ FCM token is null');
        return;
      }

      await _updateToken(token);
    } catch (e) {
      print('❌ Error syncing token: $e');
    }
  }

  /// Helper to update token in DB
  static Future<void> _updateToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // ✅ RTDB
    final rtdbRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          "https://alertmatefb-a1c17-default-rtdb.asia-southeast1.firebasedatabase.app",
    ).ref("users/$uid/fcmToken");

    await rtdbRef.set(token);
    print('✅ Token saved to RTDB for $uid');

    // ✅ Firestore
    final firestoreRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid);

    await firestoreRef.set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('✅ Token saved to Firestore for $uid');
  }

  /// 🔔 Show local notification when app is in foreground
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'alertmate_channel',
          'AlertMate Notifications',
          channelDescription: 'Geofence and SOS alerts',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
    );
  }
}
