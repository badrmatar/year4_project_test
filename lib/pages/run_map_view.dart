
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RunMapView extends StatelessWidget {
  final List<dynamic> routeData; 

  const RunMapView({Key? key, required this.routeData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    
    if (routeData.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Run Route')),
        body: const Center(
          child: Text('No route data available for this run'),
        ),
      );
    }

    
    final List<LatLng> points = routeData.map<LatLng>((point) {
      try {
        final latitude = (point['latitude'] as num?)?.toDouble() ?? 0.0;
        final longitude = (point['longitude'] as num?)?.toDouble() ?? 0.0;
        return LatLng(latitude, longitude);
      } catch (e) {
        
        return const LatLng(0, 0);
      }
    }).toList();

    
    if (points.isEmpty || (points.length == 1 && points[0].latitude == 0 && points[0].longitude == 0)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Run Route')),
        body: const Center(
          child: Text('Invalid route data for this run'),
        ),
      );
    }

    final polyline = Polyline(
      polylineId: const PolylineId('run_route'),
      points: points,
      color: Colors.blue,
      width: 5,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Run Route')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: points.first,
          zoom: 15,
        ),
        polylines: {polyline},
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}