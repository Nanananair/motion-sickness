import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'sensor_service.dart';

/// Orchestrates sensor lifecycle, wakelock, overlay window, and the
/// foreground service across app states. Single source of truth for the
/// invariant: at most one active [SensorService] subscription at a time.
class AppLifecycleCoordinator with WidgetsBindingObserver {
  AppLifecycleCoordinator({required this.sensors});

  final SensorService sensors;

  final ValueNotifier<bool> overlayActive = ValueNotifier<bool>(false);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  bool _attached = false;
  StreamSubscription? _overlayListenerSub;

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    _initForegroundTask();
    WakelockPlus.enable();
    sensors.setSamplingRate(SensorInterval.gameInterval);
    sensors.start();
  }

  Future<void> detach() async {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
    await _overlayListenerSub?.cancel();
    _overlayListenerSub = null;
    await sensors.stop();
    await WakelockPlus.disable();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
    overlayActive.dispose();
    lastError.dispose();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'kinetosis_horizon_fg',
        channelName: 'Horizon overlay',
        channelDescription:
            'Keeps the horizon overlay running while you use other apps.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  Future<bool> _ensureOverlayPermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (granted) return true;
    final result = await FlutterOverlayWindow.requestPermission();
    return result ?? false;
  }

  Future<bool> _ensureNotificationPermission() async {
    final status = await FlutterForegroundTask.checkNotificationPermission();
    if (status == NotificationPermission.granted) return true;
    final result = await FlutterForegroundTask.requestNotificationPermission();
    return result == NotificationPermission.granted;
  }

  Future<void> startOverlay() async {
    if (overlayActive.value) return;

    if (!await _ensureOverlayPermission()) {
      lastError.value = 'Display-over-other-apps permission is required.';
      return;
    }
    if (!await _ensureNotificationPermission()) {
      lastError.value = 'Notification permission is required.';
      return;
    }

    if (!await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.startService(
        notificationTitle: 'Horizon overlay is on',
        notificationText: 'Tap to open Kinetosis Horizon',
        callback: horizonForegroundTaskCallback,
      );
      if (result is ServiceRequestFailure) {
        lastError.value =
            'Could not start foreground service: ${result.error}';
        return;
      }
    }

    await sensors.stop();

    await FlutterOverlayWindow.showOverlay(
      enableDrag: false,
      overlayTitle: 'Kinetosis Horizon',
      overlayContent: 'Horizon overlay active',
      flag: OverlayFlag.clickThrough,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.none,
      height: WindowSize.fullCover,
      width: WindowSize.fullCover,
    );

    await _shareCalibration();

    _overlayListenerSub?.cancel();
    _overlayListenerSub = FlutterOverlayWindow.overlayListener.listen((_) {});

    overlayActive.value = true;
    lastError.value = null;
  }

  Future<void> stopOverlay() async {
    if (!overlayActive.value) return;

    await _overlayListenerSub?.cancel();
    _overlayListenerSub = null;

    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }

    overlayActive.value = false;

    final appForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (appForeground) {
      sensors.setSamplingRate(SensorInterval.gameInterval);
      sensors.start();
      await WakelockPlus.enable();
    }
  }

  /// Called from [HorizonPage] after the user taps Calibrate or Reset while
  /// the overlay is active, so the overlay isolate can update its offsets.
  Future<void> pushCalibrationToOverlay() async {
    if (!overlayActive.value) return;
    await _shareCalibration();
  }

  Future<void> _shareCalibration() async {
    await FlutterOverlayWindow.shareData({
      'rollOffset': sensors.rollOffset,
      'pitchOffset': sensors.pitchOffset,
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!overlayActive.value) {
          sensors.setSamplingRate(SensorInterval.gameInterval);
          sensors.start();
          WakelockPlus.enable();
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (!overlayActive.value) {
          sensors.stop();
          WakelockPlus.disable();
        } else {
          WakelockPlus.disable();
        }
        break;
      case AppLifecycleState.detached:
        sensors.stop();
        WakelockPlus.disable();
        if (overlayActive.value) {
          FlutterOverlayWindow.closeOverlay();
          FlutterForegroundTask.stopService();
        }
        break;
    }
  }
}

/// Minimal foreground-task callback. We don't run sensor work here — the
/// service exists only to keep the process alive and display the ongoing
/// notification. The main/overlay isolate owns the sensor subscription.
@pragma('vm:entry-point')
void horizonForegroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_HorizonTaskHandler());
}

class _HorizonTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, TaskStarter starter) {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
