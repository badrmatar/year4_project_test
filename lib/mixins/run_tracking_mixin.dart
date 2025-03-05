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

  
  final double minDistanceThreshold = 2.0;

  
  void startRun(Position initialPosition) {
    print('RunTrackingMixin: Starting run with initial position: ${initialPosition.latitude}, ${initialPosition.longitude}');

    
    locationSubscription?.cancel();
    runTimer?.cancel();

    setState(() {
      startLocation = initialPosition;
      currentLocation = initialPosition;
      isTracking = true;
      distanceCovered = 0.0;
      secondsElapsed = 0;
      autoPaused = false;
      stillCounter = 0;

      
      routePoints.clear();
      final startPoint = LatLng(initialPosition.latitude, initialPosition.longitude);
      routePoints.add(startPoint);
      lastRecordedLocation = startPoint;

      
      routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.orange,
        width: 5,
        points: [startPoint],
      );

      print('RunTrackingMixin: Route initialized with start point, polyline created');
    });

    
    runTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!autoPaused && mounted && isTracking) {
        setState(() {
          secondsElapsed++;
          if (secondsElapsed % 10 == 0) {
            print('RunTrackingMixin: Run in progress - ${secondsElapsed}s elapsed, ${(distanceCovered/1000).toStringAsFixed(2)}km covered');
          }
        });
      }
    });

    
    locationSubscription = locationService.trackLocation().listen((position) {
      if (mounted && isTracking) {
        _handleLocationUpdate(position);
      }
    });

    print('RunTrackingMixin: Location tracking started');

    
    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(initialPosition.latitude, initialPosition.longitude),
          16,
        ),
      );
      print('RunTrackingMixin: Map camera moved to initial position');
    }
  }

  void _handleLocationUpdate(Position position) {
    if (!isTracking) {
      print('RunTrackingMixin: Ignoring location update as tracking is off');
      return;
    }

    print('RunTrackingMixin: Received location: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m, speed: ${position.speed}m/s');

    
    final speed = position.speed >= 0 ? position.speed : 0.0;
    _handleAutoPauseLogic(speed);

    
    setState(() {
      currentLocation = position;
    });

    
    final newPoint = LatLng(position.latitude, position.longitude);

    
    if (!autoPaused && lastRecordedLocation != null) {
      final distanceFromLast = _calculateDistanceBetweenPoints(
          lastRecordedLocation!,
          newPoint
      );

      print('RunTrackingMixin: Distance from last point: ${distanceFromLast.toStringAsFixed(2)}m, threshold: ${minDistanceThreshold}m');

      
      if (distanceFromLast > minDistanceThreshold) {
        setState(() {
          
          distanceCovered += distanceFromLast;

          
          routePoints.add(newPoint);

          print('RunTrackingMixin: Updated path - added point #${routePoints.length}, total distance: ${distanceCovered.toStringAsFixed(2)}m');

          
          routePolyline = Polyline(
            polylineId: const PolylineId('route'),
            color: Colors.orange,
            width: 5,
            points: List.from(routePoints),
          );

          
          lastRecordedLocation = newPoint;
        });
      } else {
        print('RunTrackingMixin: Skipped point - too close to previous');
      }
    } else {
      if (autoPaused) {
        print('RunTrackingMixin: Not updating path - run is auto-paused');
      } else if (lastRecordedLocation == null) {
        print('RunTrackingMixin: No last location recorded yet');
      }
    }

    
    _animateToCurrentLocation(position);
  }

  void _animateToCurrentLocation(Position position) {
    if (mapController != null) {
      mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude))
      );
    }
  }

  
  double _calculateDistanceBetweenPoints(LatLng start, LatLng end) {
    try {
      
      final distance = Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude
      );

      
      print('Distance calculation: from (${start.latitude}, ${start.longitude}) to (${end.latitude}, ${end.longitude}) = ${distance.toStringAsFixed(2)}m');

      return distance;
    } catch (e) {
      print('Error calculating distance: $e');

      
      const double earthRadius = 6371000.0; 
      final startLat = start.latitude;
      final startLng = start.longitude;
      final endLat = end.latitude;
      final endLng = end.longitude;

      final dLat = (endLat - startLat) * (pi / 180);
      final dLng = (endLng - startLng) * (pi / 180);
      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(startLat * (pi / 180)) * cos(endLat * (pi / 180)) *
              sin(dLng / 2) * sin(dLng / 2);
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      return earthRadius * c;
    }
  }

  
  void endRun() {
    runTimer?.cancel();
    locationSubscription?.cancel();
    isTracking = false;
    endLocation = currentLocation;
  }

  
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    const double earthRadius = 6371000.0;
    final dLat = (endLat - startLat) * (pi / 180);
    final dLng = (endLng - startLng) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(startLat * (pi / 180)) * cos(endLat * (pi / 180)) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  
  void _handleAutoPauseLogic(double speed) {
    if (autoPaused) {
      if (speed > resumeThreshold) {
        setState(() {
          autoPaused = false;
          stillCounter = 0;
        });
        print('Run resumed: speed = $speed m/s');
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
    super.dispose();
  }
}