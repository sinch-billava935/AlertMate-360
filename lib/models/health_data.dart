class HealthData {
  final double heartRate;
  final double spo2;
  final double temperature;
  final double humidity;
  final int timestamp;

  HealthData({
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.humidity,
    required this.timestamp,
  });
}