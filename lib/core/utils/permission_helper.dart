import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Request location and notification permissions across supported mobile platforms.
  /// On Web and Desktop (Windows/Linux/macOS), permissions are managed by the browser/OS natively.
  static Future<bool> requestAllPermissions() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid || Platform.isIOS) {
      final notificationStatus = await Permission.notification.request();
      final locationStatus = await Permission.locationWhenInUse.request();

      return notificationStatus.isGranted && locationStatus.isGranted;
    }

    return true;
  }

  static Future<bool> requestLocation() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return true;
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  static Future<bool> requestNotification() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
