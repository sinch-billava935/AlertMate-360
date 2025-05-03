import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("AlertMate 360")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Welcome to AlertMate 360"),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigate to SOS or Health Stats later
              },
              child: Text("Trigger SOS"),
            ),
          ],
        ),
      ),
    );
  }
}
