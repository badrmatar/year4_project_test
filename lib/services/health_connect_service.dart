import 'package:flutter/services.dart';

class HealthConnectService {
  static const MethodChannel _channel =
  MethodChannel('com.example.year4_project/health_connect');

  Future<bool> isHealthConnectAvailable() async {
    final bool isAvailable =
        await _channel.invokeMethod('checkAvailability') ?? false;
    return isAvailable;
  }

  Future<int> getStepCount(DateTime startTime, DateTime endTime) async {
    final int steps = await _channel.invokeMethod('getStepCount', {
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
    });
    return steps;
  }
}