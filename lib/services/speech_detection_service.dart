import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class SpeechDetectionService {
  final Function() onHelpDetected;
  final Function(String) onError;
  final Function(String) onStatusUpdate;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _lastWords = '';

  SpeechDetectionService({
    required this.onHelpDetected,
    required this.onError,
    required this.onStatusUpdate,
  }) {
    _speech = stt.SpeechToText();
  }

  Future<bool> initialize() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        onError('Microphone permission not granted');
        return false;
      }

      // Initialize speech to text
      _speechAvailable = await _speech.initialize(
        onStatus: (status) => onStatusUpdate(status),
        onError: (error) => onError(error.errorMsg),
      );

      if (!_speechAvailable) {
        onError('Speech recognition not available');
        return false;
      }

      return true;
    } catch (e) {
      onError('Failed to initialize speech detection: $e');
      return false;
    }
  }

  void startListening() {
    if (_speechAvailable && !_isListening) {
      _speech.listen(
        onResult: (result) => _onSpeechResult(result),
        listenFor: Duration(minutes: 5), // Extended listening period
        pauseFor: Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
        onSoundLevelChange: (level) {},
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
      _isListening = true;
    }
  }

  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
    }
  }

  void _onSpeechResult(dynamic result) {
    // Use the correct property names based on the speech_to_text package version

    final recognizedWords = result.recognizedWords as String;
    final isFinal = result.finalResult as bool;

    if (isFinal) {
      _lastWords = recognizedWords.toLowerCase();
      onStatusUpdate('Final result: $_lastWords');

      // Check if "help" was detected
      if (_lastWords.contains('help')) {
        onHelpDetected();
        // Restart listening after a brief pause
        Future.delayed(Duration(seconds: 2), () {
          if (_isListening) {
            _speech.stop();
            startListening();
          }
        });
      }
    } else {
      // Process partial results for faster detection
      final partialText = recognizedWords.toLowerCase();
      onStatusUpdate('Listening: $partialText');

      // Quick detection from partial results
      if (partialText.contains('help')) {
        onHelpDetected();
        // Restart listening
        Future.delayed(Duration(seconds: 2), () {
          if (_isListening) {
            _speech.stop();
            startListening();
          }
        });
      }
    }
  }

  void dispose() {
    stopListening();
  }

  bool get isListening => _isListening;
  bool get isAvailable => _speechAvailable;
}
