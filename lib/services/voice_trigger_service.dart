import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceTriggerService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  Future<bool> init() async {
    _available = await _speech.initialize(onStatus: (s) {}, onError: (e) {});
    return _available;
  }

  Future<void> startListening({
    required void Function(String finalText) onFinalResult,
    Duration listenFor = const Duration(seconds: 8),
    String? localeId, // e.g. 'en_US', 'hi_IN', 'kn_IN'
  }) async {
    if (!_available) {
      final ok = await init();
      if (!ok) return;
    }
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onFinalResult(result.recognizedWords);
        }
      },
      listenFor: listenFor,
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      cancelOnError: true,
      localeId: localeId,
    );
  }

  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();

  /// Basic keyword matcher
  bool matchesTrigger(String text, List<String> keywords) {
    final t = text.toLowerCase();
    return keywords.any((k) => t.contains(k.toLowerCase()));
  }
}
