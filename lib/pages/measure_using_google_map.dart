import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latLng2;

class MapAreaCalculator extends StatefulWidget {
  @override
  _MapAreaCalculatorState createState() => _MapAreaCalculatorState();
}

class _MapAreaCalculatorState extends State<MapAreaCalculator> {
  GoogleMapController? _mapController;
  List<LatLng> selectedPoints = [];
  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  double area = 0.0;

  void _onMapTapped(LatLng point) {
    setState(() {
      selectedPoints.add(point);
      _markers.add(Marker(markerId: MarkerId(point.toString()), position: point));
      _drawPolygon();
      _calculateArea();
    });
  }

  void _drawPolygon() {
    if (selectedPoints.length > 2) {
      setState(() {
        _polygons.clear();
        _polygons.add(
          Polygon(
            polygonId: PolygonId("area"),
            points: selectedPoints,
            strokeColor: Colors.blue,
            strokeWidth: 3,
            fillColor: Colors.blue.withOpacity(0.2),
          ),
        );
      });
    }
  }

  void _calculateArea() {
    if (selectedPoints.length > 2) {
      double area = 0.0;
      for (int i = 0; i < selectedPoints.length; i++) {
        final latLng2.LatLng point1 = latLng2.LatLng(
            selectedPoints[i].latitude, selectedPoints[i].longitude);
        final latLng2.LatLng point2 = latLng2.LatLng(
            selectedPoints[(i + 1) % selectedPoints.length].latitude,
            selectedPoints[(i + 1) % selectedPoints.length].longitude);
        area += (point1.longitude * point2.latitude) -
            (point2.longitude * point1.latitude);
      }
      area = area.abs() / 2.0;
      setState(() {
        this.area = area;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Land Area Measurement')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(23.8041, 90.4152), // San Francisco
                zoom: 10,
              ),
              onTap: _onMapTapped,
              markers: _markers,
              polygons: _polygons,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Area: ${area.toStringAsFixed(2)} sq meters'),
          ),
        ],
      ),
    );
  }
}
