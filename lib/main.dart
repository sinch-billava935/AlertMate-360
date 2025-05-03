import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(AlertMateApp());
}

class AlertMateApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlertMate 360',
      theme: ThemeData(primarySwatch: Colors.red),
      home: HomeScreen(),
    );
  }
}
