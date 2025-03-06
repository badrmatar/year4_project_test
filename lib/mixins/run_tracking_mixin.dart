import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import '../services/location_service.dart';

mixin RunTrackingMixin<T extends StatefulWidget> on State<T> {
  
  final LocationService locationService = LocationService();
  Position? currentLocation;
  Position? startLocation;
  Position? endLocation;
  double distanceCovered = 0.0;
  int secondsElapsed = 0;
  Timer? runTimer;
  bool isTracking = false;
  bool autoPaused = false;
  StreamSubscription<Position>? locationSubscription;
  StreamSubscription<Position>? trackingSubscription;

  
  final List<LatLng> routePoints = [];
  Polyline routePolyline = const Polyline(
    polylineId: PolylineId('route'),
    color: Colors.orange,
    width: 5,
    points: [],
  );
  GoogleMapController? mapController;

  
  int stillCounter = 0;
  final double pauseThreshold = 0.5;
  final double resumeThreshold = 1.0;
  LatLng? lastRecordedLocation;

  
  final double minDistanceThreshold = 5.0; 

  
  void startRun(Position initialPosition) {
    print('RunTrackingMixin: Starting run with initial position');

    
    runTimer?.cancel();
    locationSubscription?.cancel();
    trackingSubscription?.cancel();

    setState(() {
      startLocation = initialPosition;
      currentLocation = initialPosition;
      isTracking = true;
      distanceCovered = 0.0;
      secondsElapsed = 0;
      autoPaused = false;
      routePoints.clear();

      final startPoint = LatLng(initialPosition.latitude, initialPosition.longitude);
      routePoints.add(startPoint);
      routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.orange,
        width: 5,
        points: [startPoint],
      );
      lastRecordedLocation = startPoint;
    });

    
    runTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!autoPaused && mounted) {
        setState(() => secondsElapsed++);
      }
    });

    
    
    trackingSubscription = locationService.trackLocation().listen((position) {
      if (!isTracking) return;

      
      final speed = position.speed.clamp(0.0, double.infinity);
      _handleAutoPauseLogic(speed);

      
      if (!autoPaused && lastRecordedLocation != null) {
        final distanceFromLast = _calculateDistance(
          lastRecordedLocation!.latitude,
          lastRecordedLocation!.longitude,
          position.latitude,
          position.longitude,
        );

        
        if (distanceFromLast > minDistanceThreshold) {
          setState(() {
            
            distanceCovered += distanceFromLast;
            print('New distance: $distanceCovered meters (added $distanceFromLast)');

            
            lastRecordedLocation = LatLng(position.latitude, position.longitude);
          });
        }
      }

      
      setState(() {
        currentLocation = position;

        
        final newPoint = LatLng(position.latitude, position.longitude);
        routePoints.add(newPoint);

        
        routePolyline = Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.orange,
          width: 5,
          points: List.from(routePoints),
        );
      });

      
      mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    });
  }

  
  void endRun() {
    runTimer?.cancel();
    locationSubscription?.cancel();
    trackingSubscription?.cancel();
    isTracking = false;
    endLocation = currentLocation;
  }

  
  double _calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  
  void _handleAutoPauseLogic(double speed) {
    if (autoPaused) {
      if (speed > resumeThreshold) {
        setState(() {
          autoPaused = false;
          stillCounter = 0;
        });
        print('Run resumed at speed: $speed m/s');
      }
    } else {
      if (speed < pauseThreshold) {
        stillCounter++;
        if (stillCounter >= 5) {
          setState(() => autoPaused = true);
          print('Run auto-paused: low speed detected');
        }
      } else {
        stillCounter = 0;
      }
    }
  }

  @override
  void dispose() {
    runTimer?.cancel();
    locationSubscription?.cancel();
    trackingSubscription?.cancel();
    super.dispose();
  }
}