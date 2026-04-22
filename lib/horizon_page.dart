import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'services/sensor_service.dart';
import 'widgets/horizon_painter.dart';

class HorizonPage extends StatefulWidget {
  const HorizonPage({super.key});

  @override
  State<HorizonPage> createState() => _HorizonPageState();
}

class _HorizonPageState extends State<HorizonPage> {
  final SensorService _sensors = SensorService();
  final _dots = generateDotSeeds();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _sensors.start();
  }

  @override
  void dispose() {
    _sensors.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: HorizonPainter(
                state: _sensors.state,
                dotSeeds: _dots,
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PillButton(
                  label: 'Reset',
                  onPressed: _sensors.resetCalibration,
                ),
                const SizedBox(width: 8),
                _PillButton(
                  label: 'Calibrate',
                  onPressed: _sensors.calibrate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x2EFFFFFF),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
