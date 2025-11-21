import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool initialVoiceTriggerState;
  final Function(bool) onVoiceTriggerChanged;

  const SettingsScreen({
    super.key,
    required this.initialVoiceTriggerState,
    required this.onVoiceTriggerChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _voiceTriggerEnabled;
  final SettingsService _settingsService = SettingsService();

  // Geofence form
  final _formKey = GlobalKey<FormState>();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _hysteresisCtrl = TextEditingController(text: '10');
  final _cooldownCtrl = TextEditingController(text: '100000');

  bool _loadingGeofence = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _voiceTriggerEnabled = widget.initialVoiceTriggerState;
    _loadExistingGeofence();
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    _hysteresisCtrl.dispose();
    _cooldownCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingGeofence() async {
    try {
      final data = await _settingsService.getGeofence();
      if (data != null) {
        _latCtrl.text = (data['latitude'] ?? '').toString();
        _lngCtrl.text = (data['longitude'] ?? '').toString();
        _radiusCtrl.text = (data['radius'] ?? '').toString();
        _hysteresisCtrl.text = (data['hysteresisMeters'] ?? 10).toString();
        _cooldownCtrl.text = (data['notifyCooldownMs'] ?? 100000).toString();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load geofence: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingGeofence = false);
    }
  }

  String? _validateDouble(String? v, {required String field}) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    final d = double.tryParse(v.trim());
    if (d == null) return '$field must be a number';
    return null;
  }

  String? _validateLatitude(String? v) {
    final err = _validateDouble(v, field: 'Latitude');
    if (err != null) return err;
    final d = double.parse(v!.trim());
    if (d < -90 || d > 90) return 'Latitude must be between -90 and 90';
    return null;
  }

  String? _validateLongitude(String? v) {
    final err = _validateDouble(v, field: 'Longitude');
    if (err != null) return err;
    final d = double.parse(v!.trim());
    if (d < -180 || d > 180) return 'Longitude must be between -180 and 180';
    return null;
  }

  String? _validateInt(String? v, {required String field, int min = 0}) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    final n = int.tryParse(v.trim());
    if (n == null) return '$field must be an integer';
    if (n < min) return '$field must be ≥ $min';
    return null;
  }

  Future<void> _saveGeofence() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _settingsService.saveGeofence(
        latitude: double.parse(_latCtrl.text.trim()),
        longitude: double.parse(_lngCtrl.text.trim()),
        radius: int.parse(_radiusCtrl.text.trim()),
        hysteresisMeters: int.parse(_hysteresisCtrl.text.trim()),
        notifyCooldownMs: int.parse(_cooldownCtrl.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geofence saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save geofence: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget pillCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
    margin: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF3E82C6).withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF3E82C6);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: accentColor,
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F6FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Padding(
              padding: const EdgeInsets.only(top: 2.0, bottom: 12.0),
              child: Text(
                'App Preferences',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ),

            // Voice Trigger (pill card)
            pillCard(
              child: Row(
                children: [
                  Icon(Icons.mic, color: accentColor),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Voice Trigger',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Enable hands-free SOS with "help" command',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _voiceTriggerEnabled,
                    onChanged: (value) async {
                      setState(() => _voiceTriggerEnabled = value);
                      await _settingsService.setVoiceTriggerEnabled(value);
                      widget.onVoiceTriggerChanged(value);
                    },
                    activeColor: accentColor,
                  ),
                ],
              ),
            ),

            // Geofence Section Title
            Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
              child: Text(
                'Geofence',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ),

            // Geofence pill card (form)
            _loadingGeofence
                ? pillCard(
                  child: const Center(child: CircularProgressIndicator()),
                )
                : Form(
                  key: _formKey,
                  child: pillCard(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _latCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            hintText: 'e.g., 12.3466',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          validator: _validateLatitude,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _lngCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            hintText: 'e.g., 77.6054',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          validator: _validateLongitude,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _radiusCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Radius (meters)',
                            hintText: 'e.g., 300',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator:
                              (v) => _validateInt(v, field: 'Radius', min: 10),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _hysteresisCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Hysteresis (meters)',
                            hintText: 'Default 10',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator:
                              (v) =>
                                  _validateInt(v, field: 'Hysteresis', min: 0),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _cooldownCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Notify Cooldown (ms)',
                            hintText: 'Default 100000',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator:
                              (v) => _validateInt(
                                v,
                                field: 'Notify Cooldown',
                                min: 0,
                              ),
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _saveGeofence,
                            icon:
                                _saving
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.save),
                            label: const Text('Save'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}
