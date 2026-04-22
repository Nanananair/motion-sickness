import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/sensor_state.dart';

class SensorService {
  static const _gravityAlpha = 0.10;
  static const _linearAlpha = 0.25;

  final ValueNotifier<SensorState> state =
      ValueNotifier<SensorState>(SensorState.zero);

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<UserAccelerometerEvent>? _userAccelSub;

  double _gx = 0, _gy = 0, _gz = 9.81;
  double _ax = 0, _ay = 0;

  double _rollOffset = 0;
  double _pitchOffset = 0;

  void start() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onAccelerometer);

    _userAccelSub = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onUserAccelerometer);
  }

  Future<void> stop() async {
    await _accelSub?.cancel();
    await _userAccelSub?.cancel();
    _accelSub = null;
    _userAccelSub = null;
  }

  void dispose() {
    stop();
    state.dispose();
  }

  /// Captures the current tilt as the zero reference. Useful when the phone
  /// is mounted at an angle (e.g. in a dash cradle).
  void calibrate() {
    _rollOffset = _computeRoll(_gx, _gy, _gz);
    _pitchOffset = _computePitch(_gx, _gy, _gz);
  }

  void resetCalibration() {
    _rollOffset = 0;
    _pitchOffset = 0;
  }

  void _onAccelerometer(AccelerometerEvent e) {
    _gx = _lowPass(_gx, e.x, _gravityAlpha);
    _gy = _lowPass(_gy, e.y, _gravityAlpha);
    _gz = _lowPass(_gz, e.z, _gravityAlpha);
    _emit();
  }

  void _onUserAccelerometer(UserAccelerometerEvent e) {
    _ax = _lowPass(_ax, e.x, _linearAlpha);
    _ay = _lowPass(_ay, e.y, _linearAlpha);
    _emit();
  }

  void _emit() {
    final roll = _computeRoll(_gx, _gy, _gz) - _rollOffset;
    final pitch = _computePitch(_gx, _gy, _gz) - _pitchOffset;
    state.value = SensorState(roll: roll, pitch: pitch, ax: _ax, ay: _ay);
  }

  static double _lowPass(double prev, double raw, double alpha) {
    return alpha * raw + (1 - alpha) * prev;
  }

  static double _computeRoll(double x, double y, double z) {
    return math.atan2(x, math.sqrt(y * y + z * z));
  }

  static double _computePitch(double x, double y, double z) {
    return math.atan2(y, math.sqrt(x * x + z * z));
  }
}
