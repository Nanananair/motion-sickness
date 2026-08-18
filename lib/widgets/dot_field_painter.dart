import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/overlay_settings.dart';
import '../models/sensor_state.dart';

/// Fraction of the viewport the field extends past each edge, so the corners stay populated once
/// the field counter-rotates against the device's roll.
const double kFieldMargin = 0.25;

const double kMinDepth = 0.35;

/// Pixels of drift per m/s^2, at unit depth and unit sensitivity. Carried over from
/// `dotSensitivity` in `HorizonPainter`, where it was tuned on the road.
const double kPixelsPerAccelerationUnit = 28.0;

const double kBaseRadius = 3.2;
const double kRingWidthRatio = 0.35;

/// The disc sits behind the ring, so it has to be dimmer or the dot turns into a blob.
const double kFillAlphaScale = 0.45;

const double _stiffness = 26.0;
final double _damping = 2 * math.sqrt(_stiffness);
const double _maxStepSeconds = 0.05;

class FieldDot {
  FieldDot({required this.homeX, required this.homeY, required this.depth});

  /// Home position in normalised field space, spanning [-kFieldMargin, 1 + kFieldMargin].
  final double homeX;
  final double homeY;

  /// 0.35 (near) .. 1.0 (far).
  final double depth;

  double offsetX = 0;
  double offsetY = 0;
  double velocityX = 0;
  double velocityY = 0;
}

/// Dart twin of the Kotlin `DotField`, so the in-app preview shows what the overlay will do.
///
/// Depth is what sells the effect: a near dot is drawn larger *and* displaced further than a far
/// one. Each dot chases its displaced target through a critically damped spring, turning noisy
/// sensor input into a glide that settles rather than a jitter.
class DotFieldSimulation {
  DotFieldSimulation({this.seed = 42}) {
    reseed(OverlaySettings.defaults.dotCount);
  }

  final int seed;

  List<FieldDot> dots = const [];
  int _seededCount = -1;

  void reseed(int count) {
    if (count == _seededCount) return;
    _seededCount = count;
    final rng = math.Random(seed);
    const span = 1 + 2 * kFieldMargin;
    dots = List.generate(
      count,
      (_) => FieldDot(
        homeX: -kFieldMargin + rng.nextDouble() * span,
        homeY: -kFieldMargin + rng.nextDouble() * span,
        depth: kMinDepth + rng.nextDouble() * (1 - kMinDepth),
      ),
    );
  }

  /// Advances the spring by [dtSeconds] towards a displacement of ([targetX], [targetY]) pixels
  /// at unit depth.
  void step(double dtSeconds, double targetX, double targetY) {
    // A dropped frame must not launch the dots across the screen.
    final dt = dtSeconds.clamp(0.0, _maxStepSeconds);
    if (dt <= 0) return;
    for (final dot in dots) {
      final tx = targetX / dot.depth;
      final ty = targetY / dot.depth;
      dot.velocityX += ((tx - dot.offsetX) * _stiffness - dot.velocityX * _damping) * dt;
      dot.velocityY += ((ty - dot.offsetY) * _stiffness - dot.velocityY * _damping) * dt;
      dot.offsetX += dot.velocityX * dt;
      dot.offsetY += dot.velocityY * dt;
    }
  }

  void recentre() {
    for (final dot in dots) {
      dot.offsetX = 0;
      dot.offsetY = 0;
      dot.velocityX = 0;
      dot.velocityY = 0;
    }
  }
}

class DotFieldPainter extends CustomPainter {
  DotFieldPainter({
    required this.simulation,
    required this.roll,
    required this.settings,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final DotFieldSimulation simulation;
  final double roll;
  final OverlaySettings settings;

  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _ring = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    const fieldSpan = 1 + 2 * kFieldMargin;
    final spanX = size.width * fieldSpan;
    final spanY = size.height * fieldSpan;
    final originX = -size.width * kFieldMargin;
    final originY = -size.height * kFieldMargin;
    final baseRadius = kBaseRadius * settings.dotSize;

    canvas.save();
    // Counter-rotate the whole field so it stays level with the earth while the phone tilts.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-roll);
    canvas.translate(-size.width / 2, -size.height / 2);

    for (final dot in simulation.dots) {
      final centre = Offset(
        _wrap(dot.homeX * size.width + dot.offsetX, originX, spanX),
        _wrap(dot.homeY * size.height + dot.offsetY, originY, spanY),
      );

      final radius = baseRadius / dot.depth;
      // Near dots read brighter, far dots recede.
      final depthAlpha = 0.5 + 0.5 * (1 - dot.depth);

      _fill.color = Colors.white
          .withOpacity((settings.opacity * depthAlpha * kFillAlphaScale).clamp(0.0, 1.0));
      canvas.drawCircle(centre, radius, _fill);

      _ring
        ..color = Colors.white.withOpacity((settings.opacity * depthAlpha).clamp(0.0, 1.0))
        ..strokeWidth = math.max(radius * kRingWidthRatio, 1.0);
      canvas.drawCircle(centre, radius, _ring);
    }

    canvas.restore();
  }

  /// Keeps a dot inside the field even under sustained acceleration.
  static double _wrap(double value, double origin, double span) {
    if (span <= 0) return value;
    var offset = (value - origin) % span;
    if (offset < 0) offset += span;
    return origin + offset;
  }

  @override
  bool shouldRepaint(covariant DotFieldPainter oldDelegate) {
    return oldDelegate.simulation != simulation ||
        oldDelegate.roll != roll ||
        oldDelegate.settings != settings;
  }
}

/// Live preview of the overlay, drawn inside our own app so settings can be tuned before the
/// user goes and grants a system permission.
class DotFieldPreview extends StatefulWidget {
  const DotFieldPreview({
    super.key,
    required this.state,
    required this.settings,
  });

  final ValueListenable<SensorState> state;
  final OverlaySettings settings;

  @override
  State<DotFieldPreview> createState() => _DotFieldPreviewState();
}

class _DotFieldPreviewState extends State<DotFieldPreview>
    with SingleTickerProviderStateMixin {
  final DotFieldSimulation _simulation = DotFieldSimulation();
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _simulation.reseed(widget.settings.dotCount);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant DotFieldPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.dotCount != widget.settings.dotCount) {
      _simulation.reseed(widget.settings.dotCount);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;

    final sensor = widget.state.value;
    // Dots drift *against* the acceleration: the vehicle pushes you forward, the world outside
    // slides back. Signs match DotFieldView on the Android side.
    final scale = kPixelsPerAccelerationUnit * widget.settings.sensitivity;
    _simulation.step(dt, -sensor.ax * scale, sensor.ay * scale);
    _frame.value++;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SensorState>(
      valueListenable: widget.state,
      builder: (context, sensor, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: DotFieldPainter(
            simulation: _simulation,
            roll: sensor.roll,
            settings: widget.settings,
            repaint: _frame,
          ),
        );
      },
    );
  }
}
