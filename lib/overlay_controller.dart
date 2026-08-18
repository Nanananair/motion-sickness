import 'package:flutter/services.dart';

import 'models/overlay_settings.dart';

/// Bridge to the Android foreground service that owns the overlay window.
///
/// Nothing here keeps state: the service outlives this isolate, so the platform side is the only
/// source of truth for whether the overlay is running and what it is running with.
class OverlayController {
  const OverlayController._();

  static const _channel =
      MethodChannel('com.kinetosis.kinetosis_horizon/overlay');

  /// Whether "Display over other apps" has been granted.
  static Future<bool> canDrawOverlays() async {
    return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
  }

  /// Opens the system grant screen. The user comes back through the lifecycle, not a result.
  static Future<void> requestOverlayPermission() {
    return _channel.invokeMethod<void>('requestOverlayPermission');
  }

  static Future<bool> canPostNotifications() async {
    return await _channel.invokeMethod<bool>('canPostNotifications') ?? true;
  }

  static Future<void> requestNotificationPermission() {
    return _channel.invokeMethod<void>('requestNotificationPermission');
  }

  /// Opens this app's system settings page, for the OEM background permissions Android has no
  /// standard intent for.
  static Future<void> openAppSettings() {
    return _channel.invokeMethod<void>('openAppSettings');
  }

  static Future<bool> isRunning() async {
    return await _channel.invokeMethod<bool>('isRunning') ?? false;
  }

  static Future<OverlaySettings> readSettings() async {
    final map = await _channel.invokeMapMethod<String, Object?>('readSettings');
    if (map == null) return OverlaySettings.defaults;
    return OverlaySettings.fromMap(map);
  }

  /// Persists [settings] and hot-applies them if the overlay is already up.
  static Future<void> updateSettings(OverlaySettings settings) {
    return _channel.invokeMethod<void>('updateSettings', settings.toMap());
  }

  /// Throws a [PlatformException] with code `permission_denied` if the grant is missing.
  static Future<bool> start() async {
    return await _channel.invokeMethod<bool>('start') ?? false;
  }

  static Future<bool> stop() async {
    return await _channel.invokeMethod<bool>('stop') ?? false;
  }
}
