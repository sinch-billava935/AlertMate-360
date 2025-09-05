import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _voiceTriggerKey = 'voice_trigger_enabled';
  static const String _speechLanguageKey = 'speech_language';

  Future<bool> isVoiceTriggerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_voiceTriggerKey) ?? false;
  }

  Future<void> setVoiceTriggerEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceTriggerKey, enabled);
  }

  Future<String> getSpeechLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_speechLanguageKey) ?? 'en_US';
  }

  Future<void> setSpeechLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_speechLanguageKey, languageCode);
  }
}
