import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Service managing the Android floating desk companion presence (Step 7).
class PipOverlayManager {
  PipOverlayManager._();

  /// Checks if SYSTEM_ALERT_WINDOW permission is granted.
  static Future<bool> isPermissionGranted() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  /// Requests overlay permission by opening system settings.
  static Future<bool?> requestPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return await FlutterOverlayWindow.requestPermission();
  }

  /// Shows the always-visible compact Pip floating overlay.
  static Future<void> showOverlay() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      final req = await FlutterOverlayWindow.requestPermission();
      if (req != true) return;
    }

    if (await FlutterOverlayWindow.isActive()) return;

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "Pip Companion",
      overlayContent: "Pip desk companion active",
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: 84,
      width: 84,
    );
  }

  /// Closes the overlay window.
  static Future<void> closeOverlay() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  /// Sends state updates from main app to overlay window.
  static Future<void> shareData(dynamic data) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await FlutterOverlayWindow.shareData(data);
  }
}
