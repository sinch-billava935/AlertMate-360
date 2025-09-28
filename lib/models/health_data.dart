class HealthData {
  final double heartRate;
  final double spo2;
  final double environmentTemperatureC;
  final double humanTemperatureF;
  final double humidity;
  final double latitude;
  final double longitude;
  final int timestamp;

  HealthData({
    required this.heartRate,
    required this.spo2,
    required this.environmentTemperatureC,
    required this.humanTemperatureF,
    required this.humidity,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}
