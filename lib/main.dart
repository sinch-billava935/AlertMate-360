import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/home_screen.dart';
import 'voice/porcupine_test_screen.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart'; // ← added

// ✅ Background FCM message handler — must be top-level
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ignore: avoid_print
  print('📩 Handling a background message: ${message.messageId}');
  NotificationService.showNotification(
    title: message.notification?.title ?? 'AlertMate 360',
    body: message.notification?.body ?? 'You have a new alert',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // ✅ Initialize notification service (local + push)
  await NotificationService.init();

  // ✅ Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const AlertMateApp());
}

class AlertMateApp extends StatelessWidget {
  const AlertMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlertMate 360',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      routes: {
        '/login': (_) => const LoginScreen(), // ← added
        '/voice-test': (_) => const PorcupineTestScreen(),
      },
    );
  }
}
