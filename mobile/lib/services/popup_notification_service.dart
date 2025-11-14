import 'package:flutter/material.dart';
import '../models/notification_history.dart';
import '../widgets/popup_notification.dart';
import '../main.dart'; // Import navigatorKey

/// Service for showing popup notifications globally using overlay
class PopupNotificationService {
  static final PopupNotificationService _instance =
      PopupNotificationService._internal();
  factory PopupNotificationService() => _instance;
  PopupNotificationService._internal();

  OverlayEntry? _currentOverlay;

  /// Show a popup notification
  void show({
    required String title,
    required String body,
    required NotificationType type,
    String? mapLink,
    VoidCallback? onTap,
  }) {
    // Dismiss any existing popup
    dismiss();

    // Get current context from navigator key
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      print('[PopupNotificationService] Context not available or not mounted');
      return;
    }

    print('[PopupNotificationService] Showing popup: $title');

    try {
      // Check if overlay is available
      final overlayState = Overlay.maybeOf(context, rootOverlay: true);
      if (overlayState == null) {
        print('[PopupNotificationService] Overlay not available (app may be in background or not fully initialized)');
        return;
      }

      _currentOverlay = OverlayEntry(
        builder: (context) => Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: PopupNotification(
            title: title,
            body: body,
            type: type,
            mapLink: mapLink,
            onDismiss: dismiss,
            onTap: onTap,
          ),
        ),
      );

      // Insert overlay using the root overlay (MaterialApp level)
      overlayState.insert(_currentOverlay!);
      print('[PopupNotificationService] ✓ Popup inserted into overlay');
    } catch (e) {
      print('[PopupNotificationService] ✗ Failed to show popup: $e');
      print('[PopupNotificationService] This is expected when app is in background');
      _currentOverlay = null;
    }
  }

  /// Dismiss current popup
  void dismiss() {
    if (_currentOverlay != null) {
      print('[PopupNotificationService] Dismissing popup');
      _currentOverlay?.remove();
      _currentOverlay = null;
    }
  }

  /// Show notification from FCM RemoteMessage data
  void showFromFCM(Map<String, dynamic> data, {VoidCallback? onTap}) {
    try {
      final title = data['title'] as String? ?? '通知';
      final body = data['body'] as String? ?? '';
      final typeStr = data['type'] as String? ?? 'arrival';
      final mapLink = data['map_link'] as String?;

      final type = NotificationType.fromString(typeStr);

      show(
        title: title,
        body: body,
        type: type,
        mapLink: mapLink,
        onTap: onTap,
      );
    } catch (e) {
      print('[PopupNotificationService] Error parsing FCM data: $e');
    }
  }
}
