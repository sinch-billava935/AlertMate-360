import 'package:flutter/material.dart';

class SosScreen extends StatefulWidget {
  @override
  _SosScreenState createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool sosTriggered = false;

  void _triggerSos() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text("Confirm Emergency Alert"),
            content: Text("Are you sure you want to trigger the SOS alert?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => sosTriggered = true);

                  // Future: integrate Firebase / GSM logic here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("🚨 SOS Alert Triggered Successfully!"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                },
                child: Text("Yes, Trigger"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5F5),
      appBar: AppBar(
        title: Text("SOS Alert"),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            SizedBox(height: 30),
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 90),
            SizedBox(height: 20),
            Text(
              sosTriggered
                  ? "SOS Alert Already Sent!"
                  : "Tap the button below to send an emergency alert.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            ElevatedButton.icon(
              icon: Icon(Icons.emergency),
              label: Text("Trigger SOS"),
              onPressed: sosTriggered ? null : _triggerSos,
              style: ElevatedButton.styleFrom(
                backgroundColor: sosTriggered ? Colors.grey : Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: TextStyle(fontSize: 18),
              ),
            ),
            SizedBox(height: 40),
            if (sosTriggered)
              Text(
                "✅ Emergency alert sent. Help is on the way.",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            Spacer(),
            Text(
              "Stay calm. You're not alone.",
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
