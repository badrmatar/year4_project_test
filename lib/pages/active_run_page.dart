import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../mixins/run_tracking_mixin.dart';
import '../services/ios_location_bridge.dart';

class ActiveRunPage extends StatefulWidget {
  final Position initialPosition;
  final String journeyType;
  final int challengeId;

  const ActiveRunPage({
    Key? key,
    required this.initialPosition,
    required this.journeyType,
    required this.challengeId,
  }) : super(key: key);

  @override
  ActiveRunPageState createState() => ActiveRunPageState();
}

class ActiveRunPageState extends State<ActiveRunPage> with RunTrackingMixin {
  bool _isLoading = true;
  StreamSubscription? _iosLocationSubscription;
  final IOSLocationBridge _iosBridge = IOSLocationBridge();
  Map<String, dynamic>? _runSummary;

  @override
  void initState() {
    super.initState();

    
    if (Platform.isIOS) {
      _initializeIOSLocationBridge();
    }

    _initializeRun();
  }

  Future<void> _initializeIOSLocationBridge() async {
    await _iosBridge.initialize();
    await _iosBridge.startBackgroundLocationUpdates();

    _iosLocationSubscription = _iosBridge.locationStream.listen((position) {
      if (!mounted || !isTracking) return;

      print('iOS background location update: ${position.latitude}, ${position.longitude}');

      
      if (currentLocation == null || position.accuracy < currentLocation!.accuracy) {
        setState(() {
          currentLocation = position;
        });
      }
    });
  }

  Future<void> _initializeRun() async {
    setState(() {
      _isLoading = false;
    });

    
    startRun(widget.initialPosition);
  }

  Future<void> _endRunAndSave() async {
    if (routePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot end run without any location data')),
      );
      return;
    }

    
    endRun();

    
    if (Platform.isIOS) {
      _iosLocationSubscription?.cancel();
      await _iosBridge.stopBackgroundLocationUpdates();
    }

    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Saving your run..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      await _saveRunData();

      
      if (mounted) Navigator.of(context).pop();

      
      if (_runSummary != null) {
        _showRunSummary();
      } else {
        
        Navigator.of(context).pushReplacementNamed('/challenges');
      }
    } catch (e) {
      
      if (mounted) Navigator.of(context).pop();

      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving run: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _saveRunData() async {
    final user = Provider.of<UserModel>(context, listen: false);

    if (user.id == 0 || routePoints.isEmpty) {
      throw Exception("Missing required data to save run");
    }

    final startPoint = routePoints.first;
    final endPoint = routePoints.last;

    print('Saving run with distance: ${distanceCovered.toStringAsFixed(2)}m');

    final distance = double.parse(distanceCovered.toStringAsFixed(2));
    final startTime = startLocation?.timestamp?.toUtc().toIso8601String()
        ?? DateTime.now().subtract(Duration(seconds: secondsElapsed)).toUtc().toIso8601String();
    final endTime = DateTime.now().toUtc().toIso8601String();

    final routeJson = routePoints
        .map((point) => {'latitude': point.latitude, 'longitude': point.longitude})
        .toList();

    final requestBody = {
      'user_id': user.id,
      'start_time': startTime,
      'end_time': endTime,
      'start_latitude': startPoint.latitude,
      'start_longitude': startPoint.longitude,
      'end_latitude': endPoint.latitude,
      'end_longitude': endPoint.longitude,
      'distance_covered': distance,
      'route': routeJson,
      'journey_type': widget.journeyType,
    };

    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['SUPABASE_URL']}/functions/v1/create_user_contribution'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['BEARER_TOKEN']}',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);

        setState(() {
          _runSummary = {
            'distanceKm': distance / 1000,
            'durationSeconds': secondsElapsed,
            'caloriesBurned': _calculateCalories(distance / 1000),
            'completed': data['data']['challenge_completed'] ?? false,
            'teamProgress': data['data']['total_distance_km'] ?? 0,
            'requiredDistance': data['data']['required_distance_km'] ?? 0,
          };
        });
      } else {
        throw Exception("Failed to save run: ${response.body}");
      }
    } catch (e) {
      throw Exception("An error occurred: ${e.toString()}");
    }
  }

  int _calculateCalories(double distanceKm) {
    
    return (distanceKm * 60).round();
  }

  void _showRunSummary() {
    if (_runSummary == null) return;

    
    final duration = Duration(seconds: secondsElapsed);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final durationText = hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    
    double paceValue = 0;
    if (_runSummary!['distanceKm'] > 0) {
      paceValue = secondsElapsed / 60 / _runSummary!['distanceKm'];
    }
    final paceMinutes = paceValue.floor();
    final paceSeconds = ((paceValue - paceMinutes) * 60).round();
    final paceText = '$paceMinutes:${paceSeconds.toString().padLeft(2, '0')} min/km';

    
    final distanceText = '${(_runSummary!['distanceKm'] as double).toStringAsFixed(2)} km';

    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Run Completed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_runSummary!['completed'] == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        '🎉 Challenge Complete! 🎉',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      if (mapController != null)
                        Container(
                          height: 200,
                          margin: const EdgeInsets.only(bottom: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: routePoints.isNotEmpty
                                    ? routePoints[routePoints.length ~/ 2]
                                    : LatLng(widget.initialPosition.latitude, widget.initialPosition.longitude),
                                zoom: 15,
                              ),
                              polylines: {routePolyline},
                              zoomControlsEnabled: false,
                              myLocationEnabled: false,
                              myLocationButtonEnabled: false,
                              onMapCreated: (controller) {},
                            ),
                          ),
                        ),

                      
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 15,
                        crossAxisSpacing: 15,
                        childAspectRatio: 1.5,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStatCard('Distance', distanceText, Icons.straighten),
                          _buildStatCard('Duration', durationText, Icons.timer),
                          _buildStatCard('Avg. Pace', paceText, Icons.speed),
                          _buildStatCard('Calories', '${_runSummary!['caloriesBurned']} kcal', Icons.local_fire_department),
                        ],
                      ),

                      const SizedBox(height: 20),

                      
                      const Text(
                        'Challenge Progress',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 10),

                      LinearProgressIndicator(
                        value: _runSummary!['teamProgress'] / _runSummary!['requiredDistance'],
                        minHeight: 20,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(_runSummary!['completed'] ? Colors.green : Colors.blue),
                        borderRadius: BorderRadius.circular(10),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        '${(_runSummary!["teamProgress"] as double).toStringAsFixed(2)}/${_runSummary!["requiredDistance"].toStringAsFixed(2)} km',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 20),

                      
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); 
                            Navigator.of(context).pushReplacementNamed('/challenges');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: const Text(
                            'Back to Challenges',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue, size: 16),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    if (Platform.isIOS) {
      _iosLocationSubscription?.cancel();
      _iosBridge.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final distanceKm = distanceCovered / 1000;

    return Scaffold(
      body: Stack(
        children: [
          
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.initialPosition.latitude,
                widget.initialPosition.longitude,
              ),
              zoom: 16,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            polylines: {routePolyline},
            onMapCreated: (controller) {
              setState(() {
                mapController = controller;
              });
            },
          ),

          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).padding.top,
              color: Colors.black.withOpacity(0.5),
            ),
          ),

          
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.black.withOpacity(0.5),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('End Run?'),
                          content: const Text('Are you sure you want to end your run?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _endRunAndSave();
                              },
                              child: const Text('End Run'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Active Run',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      autoPaused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        autoPaused = !autoPaused;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  
                  if (autoPaused)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'PAUSED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('DISTANCE', '${distanceKm.toStringAsFixed(2)} km'),
                      _buildStatItem('TIME', _formatTime(secondsElapsed)),
                      _buildStatItem(
                          'PACE',
                          secondsElapsed > 0 && distanceKm > 0
                              ? '${(secondsElapsed / 60 / distanceKm).floor()}:${(((secondsElapsed / 60 / distanceKm) % 1) * 60).round().toString().padLeft(2, '0')}'
                              : '--:--'
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _endRunAndSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'END RUN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}