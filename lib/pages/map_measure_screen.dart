import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MapMeasureScreen extends StatefulWidget {
  @override
  _MapMeasureScreenState createState() => _MapMeasureScreenState();
}

class _MapMeasureScreenState extends State<MapMeasureScreen> {
  List<Offset> points = []; // Store points marked by the user
  List<Offset?> controlPoints = []; // Store control points for curves
  bool isCurveMode = false; // Toggle between straight line and curve mode
  double scale = 1.0; // Scale factor between map and real-world (e.g., pixels per foot)
  File? _selectedImage; // For the uploaded image
  final ImagePicker _picker = ImagePicker(); // Image picker instance

  // Function to calculate the area using the Shoelace formula
  double calculatePolygonArea(List<Offset> points) {
    if (points.length < 3) return 0.0;

    double area = 0.0;
    int n = points.length;

    for (int i = 0; i < n; i++) {
      int j = (i + 1) % n;
      area += points[i].dx * points[j].dy;
      area -= points[i].dy * points[j].dx;
    }

    area = area.abs() / 2.0;

    // Convert pixel area to square feet
    return area / (scale * scale); // scale should be in pixels per foot
  }

  // Function to calculate the distance between two points
  double calculateDistance(Offset p1, Offset p2) {
    return sqrt(pow(p2.dx - p1.dx, 2) + pow(p2.dy - p1.dy, 2)) / scale; // Convert pixel distance to feet
  }

  // Function to allow user to pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        points.clear(); // Reset points when a new image is picked
        controlPoints.clear(); // Reset control points as well
      });
    }
  }

  // Function to toggle between curve mode and straight line mode
  void _toggleCurveMode() {
    setState(() {
      isCurveMode = !isCurveMode;
    });
  }

  // Function to measure the curve between the last two points
  void _measureCurve() {
    if (points.length < 2) return;

    // Assuming we want to measure between the last two points
    Offset startPoint = points[points.length - 2];
    Offset endPoint = points[points.length - 1];
    double distance = calculateDistance(startPoint, endPoint);

    // Create a dialog to show the curve distance
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Measured Curve'),
          content: Text('The curve distance between points is ${distance.toStringAsFixed(2)} feet.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Function to add a new point
  void _addPoint(Offset point) {
    setState(() {
      points.add(point);
      controlPoints.add(null); // Add a corresponding control point placeholder

      if (points.length >= 2 && isCurveMode) {
        _measureCurve();
      }
    });
  }

  // Function to remove the last point
  void _removeLastPoint() {
    if (points.isNotEmpty) {
      setState(() {
        points.removeLast(); // Remove the last point
        controlPoints.removeLast(); // Remove the last control point placeholder

        // Clear control points if there are no more points
        if (points.isEmpty) {
          controlPoints.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Land Map Measure"),
        actions: [
          Switch(
            value: isCurveMode,
            onChanged: (value) {
              _toggleCurveMode();
            },
            activeColor: Colors.green,
            inactiveThumbColor: Colors.red,
            inactiveTrackColor: Colors.grey,
          ),
        ],
      ),
      body: _selectedImage == null
          ? Center(
        child: Text(
          'No map selected. Please upload a map to begin measuring.',
          textAlign: TextAlign.center,
        ),
      )
          : InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: GestureDetector(
          onTapUp: (details) {
            _addPoint(details.localPosition);
          },
          child: Stack(
            children: [
              Image.file(_selectedImage!), // Display the uploaded image
              CustomPaint(
                painter: MapPainter(points, controlPoints, isCurveMode),
                size: Size.infinite,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _pickImage, // Allow the user to pick an image
            child: Icon(Icons.image),
            tooltip: 'Upload Map',
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _removeLastPoint, // Remove the last point
            child: Icon(Icons.delete),
            tooltip: 'Remove Last Point',
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              if (points.isNotEmpty) {
                double area = calculatePolygonArea(points);
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Measured Area'),
                      content: Text('The area is ${area.toStringAsFixed(2)} square feet.'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            child: Icon(Icons.calculate),
            tooltip: 'Calculate Area',
          ),
        ],
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  final List<Offset> points;
  final List<Offset?> controlPoints;
  final bool isCurveMode;

  MapPainter(this.points, this.controlPoints, this.isCurveMode);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.0 // Thinner lines for visibility
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.0 // Thinner dots for visibility
      ..style = PaintingStyle.stroke;

    final controlPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12.0,
      fontWeight: FontWeight.bold,
    );

    // Draw the lines or curves between the points
    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        if (isCurveMode && controlPoints[i] != null) {
          // Draw a quadratic Bezier curve when in curve mode
          final controlPoint = controlPoints[i]!;
          Path path = Path();
          path.moveTo(points[i].dx, points[i].dy);
          path.quadraticBezierTo(
              controlPoint.dx, controlPoint.dy, points[i + 1].dx, points[i + 1].dy);
          canvas.drawPath(path, linePaint);
        } else {
          // Draw straight lines when not in curve mode
          canvas.drawLine(points[i], points[i + 1], linePaint);
        }

        // Calculate and display the distance between the two points
        double distance = calculateDistance(points[i], points[i + 1]);
        Offset midpoint = Offset(
          (points[i].dx + points[i + 1].dx) / 2,
          (points[i].dy + points[i + 1].dy) / 2,
        );
        TextSpan span = TextSpan(text: '${distance.toStringAsFixed(1)} feet', style: textStyle);
        TextPainter tp = TextPainter(text: span, textAlign: TextAlign.left, textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, midpoint);
      }
    }

    // Draw circles on each point where the user clicked
    for (var point in points) {
      canvas.drawCircle(point, 6.0, pointPaint);
    }

    // Draw control points for curves
    if (isCurveMode) {
      for (var controlPoint in controlPoints) {
        if (controlPoint != null) {
          canvas.drawCircle(controlPoint, 6.0, controlPaint);
        }
      }
    }
  }

  // Function to calculate the distance between two points
  double calculateDistance(Offset p1, Offset p2) {
    return sqrt(pow(p2.dx - p1.dx, 2) + pow(p2.dy - p1.dy, 2)); // Pixel distance
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
