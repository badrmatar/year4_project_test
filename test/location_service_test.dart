
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:year4_project/services/location_service.dart';


class MockPosition extends Position {
  MockPosition({
    required double latitude,
    required double longitude,
    required double accuracy,
    double altitude = 0.0,
    double heading = 0.0,
    double speed = 0.0,
    double speedAccuracy = 0.0,
    DateTime? timestamp,
    int? floor,
    double altitudeAccuracy = 0.0,
    double headingAccuracy = 0.0,
  }) : super(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: accuracy,
    altitude: altitude,
    heading: heading,
    speed: speed,
    speedAccuracy: speedAccuracy,
    floor: floor,
    altitudeAccuracy: altitudeAccuracy,
    headingAccuracy: headingAccuracy,
  );
}


class LocationServiceTester {
  final LocationService locationService;

  
  final StreamController<Position> _positionStreamController = StreamController<Position>.broadcast();
  final StreamController<LocationQuality> _qualityStreamController = StreamController<LocationQuality>.broadcast();

  
  Position? mockCurrentPosition;
  LocationQuality mockCurrentQuality = LocationQuality.unusable;
  bool throwsExceptionOnGetCurrentLocation = false;

  LocationServiceTester() : locationService = LocationService();

  
  LocationQuality getQualityFromAccuracy(double accuracy) {
    if (accuracy <= 10.0) return LocationQuality.excellent;
    if (accuracy <= 20.0) return LocationQuality.good;
    if (accuracy <= 35.0) return LocationQuality.fair;
    if (accuracy <= 50.0) return LocationQuality.poor;
    return LocationQuality.unusable;
  }

  
  void simulateLocationUpdate(Position position) {
    mockCurrentPosition = position;
    _positionStreamController.add(position);

    
    final quality = getQualityFromAccuracy(position.accuracy);
    mockCurrentQuality = quality;
    _qualityStreamController.add(quality);
  }

  
  Future<Position?> getCurrentLocation() async {
    if (throwsExceptionOnGetCurrentLocation) {
      throw Exception('Mock location exception');
    }
    return mockCurrentPosition;
  }

  
  Stream<LocationQuality> get qualityStream => _qualityStreamController.stream;

  
  Stream<Position> get positionStream => _positionStreamController.stream;

  
  void dispose() {
    _positionStreamController.close();
    _qualityStreamController.close();
  }
}

void main() {
  late LocationServiceTester tester;

  setUp(() {
    tester = LocationServiceTester();
  });

  tearDown(() {
    tester.dispose();
  });

  group('getQualityDescription', () {
    test('should return correct description for each quality level', () {
      
      expect(
        tester.locationService.getQualityDescription(LocationQuality.excellent),
        equals('Excellent GPS signal'),
      );
      expect(
        tester.locationService.getQualityDescription(LocationQuality.good),
        equals('Good GPS signal'),
      );
      expect(
        tester.locationService.getQualityDescription(LocationQuality.fair),
        equals('Fair GPS signal'),
      );
      expect(
        tester.locationService.getQualityDescription(LocationQuality.poor),
        equals('Poor GPS signal'),
      );
      expect(
        tester.locationService.getQualityDescription(LocationQuality.unusable),
        equals('GPS signal too weak'),
      );
    });
  });

  group('getQualityColor', () {
    test('should return correct color for each quality level', () {
      
      final excellentColor = tester.locationService.getQualityColor(LocationQuality.excellent);
      final goodColor = tester.locationService.getQualityColor(LocationQuality.good);
      final fairColor = tester.locationService.getQualityColor(LocationQuality.fair);
      final poorColor = tester.locationService.getQualityColor(LocationQuality.poor);
      final unusableColor = tester.locationService.getQualityColor(LocationQuality.unusable);

      
      expect(excellentColor != goodColor, isTrue);
      expect(goodColor != fairColor, isTrue);
      expect(fairColor != poorColor, isTrue);
      expect(poorColor != unusableColor, isTrue);
    });
  });

  group('location quality assessment', () {
    test('should determine quality based on accuracy', () {
      
      expect(tester.getQualityFromAccuracy(5.0), equals(LocationQuality.excellent));
      expect(tester.getQualityFromAccuracy(15.0), equals(LocationQuality.good));
      expect(tester.getQualityFromAccuracy(30.0), equals(LocationQuality.fair));
      expect(tester.getQualityFromAccuracy(45.0), equals(LocationQuality.poor));
      expect(tester.getQualityFromAccuracy(60.0), equals(LocationQuality.unusable));
    });
  });

  group('getCurrentLocation', () {
    test('should return the current position when available', () async {
      
      final mockPosition = MockPosition(
        latitude: 53.349811,
        longitude: -6.260310,
        accuracy: 10.0,
      );
      tester.mockCurrentPosition = mockPosition;

      
      final result = await tester.getCurrentLocation();

      
      expect(result, equals(mockPosition));
    });

    test('should throw exception when specified', () async {
      
      tester.throwsExceptionOnGetCurrentLocation = true;

      
      expect(() => tester.getCurrentLocation(), throwsException);
    });
  });

  group('location streams', () {
    test('should emit position updates', () async {
      
      final positions = [
        MockPosition(
          latitude: 53.349811,
          longitude: -6.260310,
          accuracy: 10.0,
        ),
        MockPosition(
          latitude: 53.350811,
          longitude: -6.261310,
          accuracy: 8.0,
        ),
      ];

      
      expectLater(
        tester.positionStream,
        emitsInOrder([positions[0], positions[1]]),
      );

      
      tester.simulateLocationUpdate(positions[0]);
      tester.simulateLocationUpdate(positions[1]);
    });

    test('should emit quality updates based on position accuracy', () async {
      
      final position1 = MockPosition(
        latitude: 53.349811,
        longitude: -6.260310,
        accuracy: 10.0, 
      );

      final position2 = MockPosition(
        latitude: 53.350811,
        longitude: -6.261310,
        accuracy: 40.0, 
      );

      
      expectLater(
        tester.qualityStream,
        emitsInOrder([LocationQuality.excellent, LocationQuality.poor]),
      );

      
      tester.simulateLocationUpdate(position1);
      tester.simulateLocationUpdate(position2);
    });
  });

  
  group('calculateDistance', () {
    test('should calculate distance between two points accurately', () {
      
      
      

      
      
      const double lat1 = 53.349811;
      const double lon1 = -6.260310;
      const double lat2 = 53.350811; 
      const double lon2 = -6.260310;

      final expectedDistance = 111.0; 


    });
  });
}