import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class SettingsService {
  // -------------------------------
  // LOCAL SETTINGS (SharedPreferences)
  // -------------------------------
  static const String _voiceTriggerKey = 'voice_trigger_enabled';
  static const String _speechLanguageKey = 'speech_language';

  /// Get voice trigger state
  Future<bool> isVoiceTriggerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_voiceTriggerKey) ?? false;
  }

  /// Save voice trigger state
  Future<void> setVoiceTriggerEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceTriggerKey, enabled);
  }

  /// Get selected speech language (default: en_US)
  Future<String> getSpeechLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_speechLanguageKey) ?? 'en_US';
  }

  /// Save selected speech language
  Future<void> setSpeechLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_speechLanguageKey, languageCode);
  }

  // -------------------------------
  // REMOTE SETTINGS (Firebase Realtime Database)
  // -------------------------------

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Get currently authenticated user's UID
  String _uid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }
    return user.uid;
  }

  /// Load geofence settings for authenticated user
  Future<Map<String, dynamic>?> getGeofence() async {
    final uid = _uid();
    final snap = await _db.child("users/$uid/geofence").get();

    if (!snap.exists) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  /// Save geofence settings for authenticated user
  Future<void> saveGeofence({
    required double latitude,
    required double longitude,
    required int radius,
    int hysteresisMeters = 10,
    int notifyCooldownMs = 100000,
  }) async {
    final uid = _uid();

    final data = {
      "latitude": latitude,
      "longitude": longitude,
      "radius": radius,
      "hysteresisMeters": hysteresisMeters,
      "notifyCooldownMs": notifyCooldownMs,
    };

    await _db.child("users/$uid/geofence").set(data);
  }
}
