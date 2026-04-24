import 'package:flutter/material.dart';

import 'services/app_lifecycle_coordinator.dart';
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
  late final AppLifecycleCoordinator _coordinator =
      AppLifecycleCoordinator(sensors: _sensors);

  @override
  void initState() {
    super.initState();
    _coordinator.attach();
    _coordinator.lastError.addListener(_onError);
  }

  @override
  void dispose() {
    _coordinator.lastError.removeListener(_onError);
    _coordinator.detach();
    _sensors.dispose();
    super.dispose();
  }

  void _onError() {
    final msg = _coordinator.lastError.value;
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  void _onCalibrate() {
    _sensors.calibrate();
    _coordinator.pushCalibrationToOverlay();
  }

  void _onResetCalibration() {
    _sensors.resetCalibration();
    _coordinator.pushCalibrationToOverlay();
  }

  Future<void> _toggleOverlay() async {
    if (_coordinator.overlayActive.value) {
      await _coordinator.stopOverlay();
    } else {
      await _coordinator.startOverlay();
    }
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
                ValueListenableBuilder<bool>(
                  valueListenable: _coordinator.overlayActive,
                  builder: (context, active, _) => _PillButton(
                    label: active ? 'Overlay off' : 'Overlay on',
                    onPressed: _toggleOverlay,
                  ),
                ),
                const SizedBox(width: 8),
                _PillButton(
                  label: 'Reset',
                  onPressed: _onResetCalibration,
                ),
                const SizedBox(width: 8),
                _PillButton(
                  label: 'Calibrate',
                  onPressed: _onCalibrate,
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
