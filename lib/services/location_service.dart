
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService() {
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
  }

  Future<Position?> getCurrentLocation() async {
    try {
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        
        return null;
      }

      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        
        timeLimit: defaultTargetPlatform == TargetPlatform.iOS
            ? const Duration(seconds: 15)
            : const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  
  Stream<Position> trackLocation() {
    
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
      
      timeLimit: defaultTargetPlatform == TargetPlatform.iOS
          ? const Duration(seconds: 10)
          : null,
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}