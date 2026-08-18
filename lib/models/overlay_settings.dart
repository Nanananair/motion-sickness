import 'package:flutter/foundation.dart';

/// Tuning for the dot field.
///
/// [sensitivity], [dotSize] and [opacity] are multipliers around a hand-tuned baseline rather
/// than absolute values, so the defaults keep their meaning if the baseline is ever retuned.
///
/// The bounds here mirror `OverlaySettings.sanitised()` on the Android side — the service
/// re-clamps everything it reads, because it reads from SharedPreferences, not from us.
@immutable
class OverlaySettings {
  const OverlaySettings({
    required this.dotCount,
    required this.sensitivity,
    required this.dotSize,
    required this.opacity,
  });

  /// Total dots seeded. The field extends past every screen edge, so roughly 45% of these are
  /// visible at rest — 90 seeded reads as about 40 on screen.
  final int dotCount;
  final double sensitivity;
  final double dotSize;
  final double opacity;

  static const minDots = 30;
  static const maxDots = 200;

  static const defaults = OverlaySettings(
    dotCount: 90,
    sensitivity: 1.0,
    dotSize: 1.0,
    opacity: 0.55,
  );

  factory OverlaySettings.fromMap(Map<Object?, Object?> map) {
    double read(String key, double fallback) {
      final value = map[key];
      return value is num ? value.toDouble() : fallback;
    }

    final count = map['dotCount'];
    return OverlaySettings(
      dotCount: count is num ? count.toInt() : defaults.dotCount,
      sensitivity: read('sensitivity', defaults.sensitivity),
      dotSize: read('dotSize', defaults.dotSize),
      opacity: read('opacity', defaults.opacity),
    );
  }

  Map<String, Object?> toMap() => {
        'dotCount': dotCount,
        'sensitivity': sensitivity,
        'dotSize': dotSize,
        'opacity': opacity,
      };

  OverlaySettings copyWith({
    int? dotCount,
    double? sensitivity,
    double? dotSize,
    double? opacity,
  }) {
    return OverlaySettings(
      dotCount: dotCount ?? this.dotCount,
      sensitivity: sensitivity ?? this.sensitivity,
      dotSize: dotSize ?? this.dotSize,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OverlaySettings &&
        other.dotCount == dotCount &&
        other.sensitivity == sensitivity &&
        other.dotSize == dotSize &&
        other.opacity == opacity;
  }

  @override
  int get hashCode => Object.hash(dotCount, sensitivity, dotSize, opacity);
}
