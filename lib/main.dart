// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // already present
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'screens/home_screen.dart';
import 'voice/porcupine_test_screen.dart';
import 'services/notification_service.dart';

// Top-level background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // You can debug/log the message here
  print('Handling a background message: ${message.messageId}');
  // If needed, you can write to Realtime DB / Firestore here, but keep it small.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await NotificationService.init(); // ✅ Call this once
  // Register the background handler BEFORE runApp
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
      routes: {'/voice-test': (_) => const PorcupineTestScreen()},
    );
  }
}
