import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/sensor_service.dart';
import '../widgets/horizon_painter.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _HorizonOverlayApp());
}

class _HorizonOverlayApp extends StatefulWidget {
  const _HorizonOverlayApp();

  @override
  State<_HorizonOverlayApp> createState() => _HorizonOverlayAppState();
}

class _HorizonOverlayAppState extends State<_HorizonOverlayApp> {
  final SensorService _sensors = SensorService();
  final List<Offset> _dots = generateDotSeeds(count: 20);

  @override
  void initState() {
    super.initState();
    _sensors.setSamplingRate(SensorInterval.uiInterval);
    _sensors.start();

    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        final roll = (event['rollOffset'] as num?)?.toDouble();
        final pitch = (event['pitchOffset'] as num?)?.toDouble();
        if (roll != null && pitch != null) {
          _sensors.applyCalibration(rollOffset: roll, pitchOffset: pitch);
        }
      }
    });
  }

  @override
  void dispose() {
    _sensors.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        type: MaterialType.transparency,
        child: IgnorePointer(
          child: SizedBox.expand(
            child: CustomPaint(
              painter: HorizonPainter(
                state: _sensors.state,
                dotSeeds: _dots,
                overlayMode: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
