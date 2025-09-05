import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';

class PorcupineTestScreen extends StatefulWidget {
  const PorcupineTestScreen({super.key});

  @override
  State<PorcupineTestScreen> createState() => _PorcupineTestScreenState();
}

class _PorcupineTestScreenState extends State<PorcupineTestScreen> {
  // TODO: paste your real key
  static const String _accessKey =
      'MCdrhdpD3gGsL/LldVIznS4BKBTsn1Ex4KztAdLdJ2Arhjf8wKN0Bg==';

  PorcupineManager? _manager;
  bool _listening = false;
  String _log = 'Idle';

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> _startListening() async {
    if (_listening) return;
    final ok = await _ensureMicPermission();
    if (!ok) {
      setState(() => _log = 'Microphone permission denied');
      return;
    }

    try {
      // Path to the keyword asset we added in pubspec.yaml
      const keywordAssetPath = 'assets/keywords/help_android.ppn';

      _manager = await PorcupineManager.fromKeywordPaths(
        _accessKey,
        [keywordAssetPath],
        _wakeWordCallback,
        // optional: tweak sensitivity 0..1 (higher = more sensitive, more false positives)
        sensitivities: [0.6],
        errorCallback: (e) {
          setState(() => _log = 'Porcupine error: ${e.message}');
        },
      );

      await _manager!.start();
      setState(() {
        _listening = true;
        _log = 'Listening for “help”…';
      });
    } on PorcupineInvalidArgumentException catch (e) {
      setState(() => _log = 'Invalid args: ${e.message}');
    } on PorcupineActivationException {
      setState(() => _log = 'Invalid AccessKey');
    } on PorcupineActivationRefusedException {
      setState(() => _log = 'AccessKey refused/limited');
    } on PorcupineActivationLimitException {
      setState(() => _log = 'AccessKey reached limit');
    } on PorcupineException catch (e) {
      setState(() => _log = 'Init failed: ${e.message}');
    } catch (e) {
      setState(() => _log = 'Unexpected error: $e');
    }
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    try {
      await _manager?.stop();
    } finally {
      setState(() {
        _listening = false;
        _log = 'Stopped';
      });
    }
  }

  void _wakeWordCallback(int keywordIndex) {
    // Only one keyword, index will be 0 on detection
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('🗣️ Detected: “help”')));
    setState(() => _log = 'Detected “help” at ${DateTime.now()}');
  }

  @override
  void dispose() {
    _manager?.stop();
    _manager?.delete(); // free native resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Porcupine Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_log),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _listening ? null : _startListening,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Listening'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _listening ? _stopListening : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Tip: test on a physical Android device, not an emulator.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
