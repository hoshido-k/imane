import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/pop.dart';
import 'pop_card.dart';

/// Widget that displays an animated PopCard on the map at a specific location
class AnimatedMapPop extends StatelessWidget {
  final Pop pop;
  final GoogleMapController? mapController;
  final VoidCallback? onTap;

  const AnimatedMapPop({
    super.key,
    required this.pop,
    required this.mapController,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ScreenCoordinate?>(
      future: _getScreenPosition(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final screenPos = snapshot.data!;

        return Positioned(
          left: screenPos.x.toDouble() - 70, // Center the card (width / 2)
          top: screenPos.y.toDouble() - 100, // Position above the point
          child: PopCard(
            pop: pop,
            enableAnimation: true,
            onTap: onTap,
          ),
        );
      },
    );
  }

  Future<ScreenCoordinate?> _getScreenPosition() async {
    if (mapController == null) return null;

    try {
      final screenCoordinate = await mapController!.getScreenCoordinate(pop.location);
      return screenCoordinate;
    } catch (e) {
      return null;
    }
  }
}
