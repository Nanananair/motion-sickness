import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/sensor_state.dart';

class HorizonPainter extends CustomPainter {
  HorizonPainter({
    required ValueListenable<SensorState> state,
    required List<Offset> dotSeeds,
    this.dotSensitivity = 28.0,
    this.pitchPixelsPerRadian = 220.0,
  })  : _state = state,
        _dotSeeds = dotSeeds,
        super(repaint: state);

  final ValueListenable<SensorState> _state;
  final List<Offset> _dotSeeds;
  final double dotSensitivity;
  final double pitchPixelsPerRadian;

  static const _sky = Color(0xFF103A66);
  static const _ground = Color(0xFF5A3A18);
  static const _line = Color(0xFFFFFFFF);
  static const _tick = Color(0xFFE6E6E6);
  static const _dot = Color(0xFFFFFFFF);

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

    final skyPaint = Paint()..color = _sky;
    final groundPaint = Paint()..color = _ground;
    canvas.drawRect(Rect.fromLTRB(-halfW, -halfH, halfW, 0), skyPaint);
    canvas.drawRect(Rect.fromLTRB(-halfW, 0, halfW, halfH), groundPaint);

    final linePaint = Paint()
      ..color = _line
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(-halfW, 0), Offset(halfW, 0), linePaint);

    final tickPaint = Paint()
      ..color = _tick
      ..strokeWidth = 2.0;
    const ticksDeg = [-20, -10, 10, 20];
    final pxPerDeg = pitchPixelsPerRadian * math.pi / 180.0;
    for (final deg in ticksDeg) {
      final y = -deg * pxPerDeg;
      final w = deg.abs() == 10 ? 60.0 : 100.0;
      canvas.drawLine(Offset(-w, y), Offset(w, y), tickPaint);
    }

    canvas.restore();

    final dotPaint = Paint()..color = _dot;
    final dx = -s.ax * dotSensitivity;
    final dy = s.ay * dotSensitivity;
    for (final seed in _dotSeeds) {
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
        oldDelegate.pitchPixelsPerRadian != pitchPixelsPerRadian;
  }
}

List<Offset> generateDotSeeds({int count = 40, int seed = 42}) {
  final rng = math.Random(seed);
  return List.generate(
    count,
    (_) => Offset(rng.nextDouble(), rng.nextDouble()),
  );
}
