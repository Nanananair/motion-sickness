import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/sensor_state.dart';

class HorizonPainter extends CustomPainter {
  HorizonPainter({
    required ValueListenable<SensorState> state,
    required List<Offset> dotSeeds,
    this.dotSensitivity = 28.0,
    this.pitchPixelsPerRadian = 220.0,
    this.overlayMode = false,
  })  : _state = state,
        _dotSeeds = dotSeeds,
        super(repaint: state);

  final ValueListenable<SensorState> _state;
  final List<Offset> _dotSeeds;
  final double dotSensitivity;
  final double pitchPixelsPerRadian;
  final bool overlayMode;

  static const _sky = Color(0xFF103A66);
  static const _ground = Color(0xFF5A3A18);
  static const _line = Color(0xFFFFFFFF);
  static const _tick = Color(0xFFE6E6E6);
  static const _dot = Color(0xFFFFFFFF);

  static final _overlayLine = Colors.white.withOpacity(0.55);
  static final _overlayTick = Colors.white.withOpacity(0.45);
  static final _overlayDot = Colors.white.withOpacity(0.35);
  static final _overlayShadow = Colors.black.withOpacity(0.45);

  @override
  void paint(Canvas canvas, Size size) {
    final s = _state.value;
    final center = size.center(Offset.zero);
    final diag = math.sqrt(size.width * size.width + size.height * size.height);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-s.roll);

    final pitchOffset = (s.pitch * pitchPixelsPerRadian).clamp(-diag, diag);
    canvas.translate(0, pitchOffset);

    final halfW = diag;
    final halfH = diag;

    if (!overlayMode) {
      final skyPaint = Paint()..color = _sky;
      final groundPaint = Paint()..color = _ground;
      canvas.drawRect(Rect.fromLTRB(-halfW, -halfH, halfW, 0), skyPaint);
      canvas.drawRect(Rect.fromLTRB(-halfW, 0, halfW, halfH), groundPaint);
    }

    if (overlayMode) {
      final shadowPaint = Paint()
        ..color = _overlayShadow
        ..strokeWidth = 5.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawLine(Offset(-halfW, 1), Offset(halfW, 1), shadowPaint);
    }

    final linePaint = Paint()
      ..color = overlayMode ? _overlayLine : _line
      ..strokeWidth = overlayMode ? 3.0 : 3.0;
    canvas.drawLine(Offset(-halfW, 0), Offset(halfW, 0), linePaint);

    final tickPaint = Paint()
      ..color = overlayMode ? _overlayTick : _tick
      ..strokeWidth = 2.0;
    final ticksDeg = overlayMode ? const [-30, 30] : const [-20, -10, 10, 20];
    final pxPerDeg = pitchPixelsPerRadian * math.pi / 180.0;
    for (final deg in ticksDeg) {
      final y = -deg * pxPerDeg;
      final w = overlayMode ? 80.0 : (deg.abs() == 10 ? 60.0 : 100.0);
      canvas.drawLine(Offset(-w, y), Offset(w, y), tickPaint);
    }

    canvas.restore();

    final dotPaint = Paint()..color = overlayMode ? _overlayDot : _dot;
    final dx = -s.ax * dotSensitivity;
    final dy = s.ay * dotSensitivity;
    final step = overlayMode ? 2 : 1;
    for (var i = 0; i < _dotSeeds.length; i += step) {
      final seed = _dotSeeds[i];
      final pos = Offset(seed.dx * size.width, seed.dy * size.height) +
          Offset(dx, dy);
      canvas.drawCircle(pos, 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HorizonPainter oldDelegate) {
    return oldDelegate._state != _state ||
        oldDelegate._dotSeeds != _dotSeeds ||
        oldDelegate.dotSensitivity != dotSensitivity ||
        oldDelegate.pitchPixelsPerRadian != pitchPixelsPerRadian ||
        oldDelegate.overlayMode != overlayMode;
  }
}

List<Offset> generateDotSeeds({int count = 40, int seed = 42}) {
  final rng = math.Random(seed);
  return List.generate(
    count,
    (_) => Offset(rng.nextDouble(), rng.nextDouble()),
  );
}
