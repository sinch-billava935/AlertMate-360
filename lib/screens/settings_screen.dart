import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool initialVoiceTriggerState;
  final Function(bool) onVoiceTriggerChanged;

  const SettingsScreen({
    Key? key,
    required this.initialVoiceTriggerState,
    required this.onVoiceTriggerChanged,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _voiceTriggerEnabled;
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _voiceTriggerEnabled = widget.initialVoiceTriggerState;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF3E82C6),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Preferences',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              child: SwitchListTile(
                title: const Text('Voice Trigger'),
                subtitle: const Text(
                  'Enable hands-free SOS with "help" command',
                ),
                value: _voiceTriggerEnabled,
                onChanged: (value) async {
                  setState(() {
                    _voiceTriggerEnabled = value;
                  });
                  await _settingsService.setVoiceTriggerEnabled(value);
                  widget.onVoiceTriggerChanged(value);
                },
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'When enabled, the app will listen for the "help" command to trigger emergency alerts.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
