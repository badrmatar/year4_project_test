import 'package:flutter/material.dart';
import 'dart:async';
import '../services/health_connect_service.dart';

class ActiveRunPage extends StatefulWidget {
  const ActiveRunPage({Key? key}) : super(key: key);

  @override
  State<ActiveRunPage> createState() => _ActiveRunPageState();
}

class _ActiveRunPageState extends State<ActiveRunPage> {
  final HealthConnectService _healthConnectService = HealthConnectService();

  
  Timer? _timer;

  
  DateTime _runStartTime = DateTime.now();
  int _elapsedSeconds = 0;
  int _initialStepCount = 0;
  int _currentStepCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeHealthConnect();
  }

  
  Future<void> _initializeHealthConnect() async {
    final isAvailable = await _healthConnectService.isHealthConnectAvailable();
    if (!isAvailable) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health Connect is unavailable.')),
      );
      Navigator.pop(context);
      return;
    }

    
    try {
      
      _initialStepCount = await _healthConnectService.getStepCount(
        _runStartTime.subtract(const Duration(hours: 1)),
        _runStartTime,
      );
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading initial steps: $e')),
      );
      Navigator.pop(context);
      return;
    }

    
    _startTracking();
  }

  
  void _startTracking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      setState(() {
        _elapsedSeconds++;
      });

      
      try {
        final steps = await _healthConnectService.getStepCount(
          _runStartTime,
          DateTime.now(),
        );
        setState(() {
          _currentStepCount = steps - _initialStepCount;
        });
      } catch (e) {
        
        print('Error reading steps: $e');
      }
    });
  }

  
  void _stopTracking() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    final distanceKm = _currentStepCount * 0.00075;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Run'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Time: $_elapsedSeconds s'),
            Text('Steps: $_currentStepCount'),
            Text('Distance: ${distanceKm.toStringAsFixed(2)} km'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _stopTracking();
                Navigator.pop(context);
              },
              child: const Text('End Run'),
            ),
          ],
        ),
      ),
    );
  }
}
