import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'services/sensor_service.dart';
import 'widgets/horizon_painter.dart';

/// The original fullscreen mode: sky, ground and a pitch ladder, for when you can give the
/// screen your whole attention. The overlay on the home screen is the everyday cue.
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
    // Immersive and landscape-capable only here; the control panel wants normal chrome.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _sensors.start();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
            left: 16,
            top: 24,
            child: _PillButton(
              label: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
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
