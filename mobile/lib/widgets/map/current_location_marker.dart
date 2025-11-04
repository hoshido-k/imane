import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Helper to create a custom current location marker
class CurrentLocationMarker {
  /// Creates a blue circular marker for current location
  static Future<BitmapDescriptor> create() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const size = 60.0;
    const center = Offset(size / 2, size / 2);

    // Draw outer pulse circle (light blue, semi-transparent)
    final outerPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 28, outerPaint);

    // Draw middle circle (blue, semi-transparent)
    final middlePaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 20, middlePaint);

    // Draw inner circle (solid blue with white border)
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 14, borderPaint);

    final innerPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 11, innerPaint);

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(bytes);
  }
}
