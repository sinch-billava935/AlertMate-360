import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // auto-generated
import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/account_details_screen.dart';
import 'voice/porcupine_test_screen.dart'; // import the test screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize Firebase if it's not already initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

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