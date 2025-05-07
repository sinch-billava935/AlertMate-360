import 'package:alertmate360/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart'; // <-- add this

void main() {
  runApp(AlertMateApp());
}

class AlertMateApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlertMate 360',
      theme: ThemeData(primarySwatch: Colors.red),
      home: SplashScreen(), // <-- start from login
    );
  }
}
