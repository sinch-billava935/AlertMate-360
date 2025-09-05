import 'dart:async';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class PorcupineService {
  PorcupineManager? _porcupineManager;
  final Function() onHelpDetected;
  final Function(String) onError;

  PorcupineService({required this.onHelpDetected, required this.onError});

  // Replace with your actual Picovoice AccessKey
  static const String accessKey =
      'MCdrhdpD3gGsL/LldVIznS4BKBTsn1Ex4KztAdLdJ2Arhjf8wKN0Bg==';
  Future<bool> initPorcupine() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        onError('Microphone permission not granted');
        return false;
      }

      // Initialize Porcupine with the "help" keyword
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        accessKey,
        ["assets/keywords/help.ppn"],
        _wakeWordCallback,
        errorCallback: _errorCallback,
      );

      return true;
    } catch (e) {
      onError('Failed to initialize Porcupine: $e');
      return false;
    }
  }

  void _wakeWordCallback(int keywordIndex) {
    // "help" detected
    onHelpDetected();
  }

  // Add this to your PorcupineService to check if you're getting quota errors
  void _errorCallback(Object error) {
    print('[Porcupine] Error: $error');

    // Check for quota/authentication errors
    if (error.toString().contains('quota') ||
        error.toString().contains('limit') ||
        error.toString().contains('authentication')) {
      onError(
        'Picovoice quota/authentication error: $error. Check your account limits.',
      );
    } else {
      onError('Porcupine error: $error');
    }
  }

  Future<void> startListening() async {
    try {
      await _porcupineManager?.start();
    } catch (e) {
      onError('Failed to start listening: $e');
    }
  }

  Future<void> stopListening() async {
    try {
      await _porcupineManager?.stop();
    } catch (e) {
      onError('Failed to stop listening: $e');
    }
  }

  Future<void> dispose() async {
    await _porcupineManager?.delete();
  }
}
