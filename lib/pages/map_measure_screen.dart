import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // For handling the file from image picker
import 'dart:math';

class MapMeasureApp extends StatefulWidget {
  @override
  _MapMeasureAppState createState() => _MapMeasureAppState();
}

class _MapMeasureAppState extends State<MapMeasureApp> {
  File? _mapImage; // Store the user-uploaded image
  List<Offset> selectedPoints = [];
  List<List<Offset>> segments = []; // List of line segments
  double calculatedArea = 0;
  double realWorldArea = 0; // Real-world area in square feet
  double lastDistance = 0; // Distance between the last two points

  final ImagePicker _picker = ImagePicker();

  // Map scale conversion (from image)
  final double mapInchesPerMile = 16;
  final double inchesToFeet = 330; // 1 inch = 330 feet

  // Function to calculate polygon area using Shoelace Theorem (in map units)
  double calculatePolygonArea(List<Offset> points) {
    if (points.length < 3) {
      return 0; // Need at least 3 points to form a polygon
    }
    double area = 0;
    int n = points.length;

    for (int i = 0; i < n; i++) {
      int j = (i + 1) % n;
      area += points[i].dx * points[j].dy;
      area -= points[j].dx * points[i].dy;
    }

    return area.abs() / 2.0; // Absolute value of the calculated area
  }

  // Function to calculate real-world area based on the selected points
  double convertMapAreaToRealWorldArea(double mapArea) {
    // Convert the map area (in square map inches) to real-world area (in square feet)
    double areaInSquareInches = mapArea; // Assume each unit is 1 pixel
    double scaleFactor = inchesToFeet; // 1 map inch = 330 feet
    double areaInSquareFeet = (areaInSquareInches * scaleFactor * scaleFactor) / (mapInchesPerMile / 16);

    return areaInSquareFeet; // Real-world area in square feet
  }

  // Function to calculate the distance between two points
  double calculateDistance(Offset p1, Offset p2) {
    return sqrt(pow(p2.dx - p1.dx, 2) + pow(p2.dy - p1.dy, 2));
  }

  // Function to allow the user to pick an image from the gallery
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _mapImage = File(pickedFile.path);
        selectedPoints.clear();
        segments.clear(); // Clear the segments when a new image is picked
        calculatedArea = 0;
        realWorldArea = 0;
        lastDistance = 0; // Reset the distance
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'Map Area: ${calculatedArea.toStringAsFixed(2)} sq units',
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
            Text(
              'Real Area: ${realWorldArea.toStringAsFixed(2)} sq feet',
              style: TextStyle(color: Colors.blue, fontSize: 16),
            ),
            if (lastDistance > 0)
              Text(
                'Distance: ${lastDistance.toStringAsFixed(2)} units',
                style: TextStyle(color: Colors.green, fontSize: 16),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.photo_library),
            onPressed: _pickImage, // Call image picker when the button is pressed
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              setState(() {
                if (segments.isNotEmpty) {
                  // Remove the last segment
                  segments.removeLast();
                  // Optionally remove the last point
                  selectedPoints.removeLast();
                } else if (selectedPoints.isNotEmpty) {
                  // If there are points but no segments, just remove the last point
                  selectedPoints.removeLast();
                }

                // Recalculate area and distance
                if (selectedPoints.length >= 3) {
                  calculatedArea = calculatePolygonArea(selectedPoints);
                  realWorldArea = convertMapAreaToRealWorldArea(calculatedArea);
                } else {
                  calculatedArea = 0;
                  realWorldArea = 0;
                }

                // Update distance if there are at least two points
                if (selectedPoints.length >= 2) {
                  lastDistance = calculateDistance(
                    selectedPoints[selectedPoints.length - 2],
                    selectedPoints.last,
                  );
                } else {
                  lastDistance = 0;
                }
              });
            },
          ),
        ],
      ),
      body: _mapImage == null
          ? Center(child: Text("Please upload a map image to start"))
          : InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: GestureDetector(
          onTapDown: (details) {
            setState(() {
              selectedPoints.add(details.localPosition);

              // Create segments between points
              if (selectedPoints.length > 1) {
                segments.add([selectedPoints[selectedPoints.length - 2], selectedPoints.last]);
              }

              // Calculate the distance between the last two points
              if (selectedPoints.length >= 2) {
                lastDistance = calculateDistance(
                  selectedPoints[selectedPoints.length - 2],
                  selectedPoints.last,
                );
              }

              // Calculate the area once enough points are selected (at least 3)
              if (selectedPoints.length >= 3) {
                calculatedArea = calculatePolygonArea(selectedPoints);
                realWorldArea = convertMapAreaToRealWorldArea(calculatedArea);
              }
            });
          },
          child: Stack(
            children: [
              // Display the uploaded map image
              Image.file(
                _mapImage!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),

              // Custom painter to draw lines and points (dots) on the image
              CustomPaint(
                painter: MapPainter(selectedPoints, segments),
                size: Size(double.infinity, double.infinity),
              ),

              // Display the area result
              if (calculatedArea > 0)
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    color: Colors.black.withOpacity(0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Map Area: ${calculatedArea.toStringAsFixed(2)} sq units',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          'Real Area: ${realWorldArea.toStringAsFixed(2)} sq feet',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        if (lastDistance > 0)
                          Text(
                            'Distance: ${lastDistance.toStringAsFixed(2)} units',
                            style: TextStyle(color: Colors.green, fontSize: 16),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// CustomPainter to draw dots and lines on the map image
class MapPainter extends CustomPainter {
  final List<Offset> points;
  final List<List<Offset>> segments;
  MapPainter(this.points, this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.0 // Thinner lines for visibility
      ..style = PaintingStyle.stroke;

    final paintLine = Paint()
      ..color = Colors.blue
      ..strokeWidth = .5;

    // Draw the points as dots
    for (var point in points) {
      canvas.drawCircle(point, 1, linePaint);
    }

    // Draw segments (lines connecting points)
    for (var segment in segments) {
      canvas.drawLine(segment[0], segment[1], paintLine);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Repaint whenever points or segments change
  }
}
