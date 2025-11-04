import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/pop.dart';

/// Helper class to create custom markers from widgets
class MapPopOverlay {
  /// Converts a widget to a BitmapDescriptor for use as a custom marker
  /// Based on Figma design with emoji, username, message, time, and likes
  static Future<BitmapDescriptor> createCustomMarker({
    required Pop pop,
    required Size size,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final cardColor = Color(pop.category.color);

    // Draw shadow first
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 2, size.width, size.height),
      const Radius.circular(12),
    );
    canvas.drawRRect(shadowRect, shadowPaint);

    // Draw main card background
    final paint = Paint()
      ..color = cardColor
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, paint);

    double yOffset = 10;

    // Draw category emoji
    final emojiPainter = TextPainter(
      text: TextSpan(
        text: pop.category.emoji,
        style: const TextStyle(fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    emojiPainter.layout();
    emojiPainter.paint(canvas, Offset(10, yOffset));

    // Draw username
    final namePainter = TextPainter(
      text: TextSpan(
        text: pop.userName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    namePainter.layout(maxWidth: size.width - 36);
    namePainter.paint(canvas, Offset(30, yOffset + 2));

    yOffset += 26;

    // Draw message
    final messagePainter = TextPainter(
      text: TextSpan(
        text: pop.message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    );
    messagePainter.layout(maxWidth: size.width - 20);
    messagePainter.paint(canvas, Offset(10, yOffset));

    yOffset += messagePainter.height + 8;

    // Draw time icon
    _drawIcon(canvas, Icons.access_time, Offset(10, yOffset), 12, Colors.white);

    // Draw time text
    final timePainter = TextPainter(
      text: TextSpan(
        text: pop.timeAgo,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    timePainter.layout();
    timePainter.paint(canvas, Offset(26, yOffset + 1));

    // Draw heart icon
    _drawIcon(
      canvas,
      Icons.favorite,
      Offset(size.width - 40, yOffset),
      12,
      Colors.white,
    );

    // Draw likes count
    final likesPainter = TextPainter(
      text: TextSpan(
        text: '${pop.likeCount}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    likesPainter.layout();
    likesPainter.paint(canvas, Offset(size.width - 24, yOffset + 1));

    // Draw pin pointer at bottom
    final pinPath = Path()
      ..moveTo(size.width / 2 - 8, size.height)
      ..lineTo(size.width / 2, size.height + 8)
      ..lineTo(size.width / 2 + 8, size.height)
      ..close();
    canvas.drawPath(pinPath, paint);

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      (size.height + 10).toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(bytes);
  }

  /// Helper method to draw Material Icons on canvas
  static void _drawIcon(
    Canvas canvas,
    IconData icon,
    Offset position,
    double size,
    Color color,
  ) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, position);
  }
}
