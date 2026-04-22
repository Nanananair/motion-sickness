import 'package:flutter/foundation.dart';

@immutable
class SensorState {
  final double roll;
  final double pitch;
  final double ax;
  final double ay;

  const SensorState({
    required this.roll,
    required this.pitch,
    required this.ax,
    required this.ay,
  });

  static const zero = SensorState(roll: 0, pitch: 0, ax: 0, ay: 0);

  SensorState copyWith({double? roll, double? pitch, double? ax, double? ay}) {
    return SensorState(
      roll: roll ?? this.roll,
      pitch: pitch ?? this.pitch,
      ax: ax ?? this.ax,
      ay: ay ?? this.ay,
    );
  }
}
