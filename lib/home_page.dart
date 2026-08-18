import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'horizon_page.dart';
import 'models/overlay_settings.dart';
import 'models/sensor_state.dart';
import 'overlay_controller.dart';
import 'services/sensor_service.dart';
import 'widgets/dot_field_painter.dart';

/// Control panel for the overlay.
///
/// The overlay itself is a native foreground service — this screen only grants it permission,
/// switches it on and off, and tunes it. State always comes back from the platform, never from
/// local memory, because the user can stop the overlay from its notification without us hearing.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final SensorService _sensors = SensorService();

  OverlaySettings _settings = OverlaySettings.defaults;
  bool _canDrawOverlays = false;
  bool _running = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sensors.start();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sensors.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The permission is granted in system settings and the overlay is stopped from a
    // notification, so both can change while we are backgrounded.
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _load() async {
    final settings = await OverlayController.readSettings();
    if (!mounted) return;
    setState(() => _settings = settings);
    await _refresh();
  }

  Future<void> _refresh() async {
    final canDraw = await OverlayController.canDrawOverlays();
    final running = await OverlayController.isRunning();
    if (!mounted) return;
    setState(() {
      _canDrawOverlays = canDraw;
      _running = running;
    });
  }

  Future<void> _setRunning(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!value) {
        await OverlayController.stop();
        return;
      }

      if (!_canDrawOverlays) {
        await OverlayController.requestOverlayPermission();
        return;
      }

      if (!(await OverlayController.canPostNotifications())) {
        // The service posts an ongoing notification; without this the Stop action is invisible.
        await OverlayController.requestNotificationPermission();
      }

      await OverlayController.start();
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Could not start the overlay.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  void _previewSetting(OverlaySettings next) {
    setState(() => _settings = next);
  }

  Future<void> _commitSettings() => OverlayController.updateSettings(_settings);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            Text('Kinetosis Horizon', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'A motion cue that keeps drifting over your other apps, so your eyes agree '
              'with your inner ear while you read.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            _PreviewCard(state: _sensors.state, settings: _settings),
            const SizedBox(height: 20),
            if (!_canDrawOverlays) ...[
              _PermissionCard(
                onGrant: () => OverlayController.requestOverlayPermission(),
              ),
              const SizedBox(height: 16),
            ],
            _ToggleCard(
              running: _running,
              enabled: !_busy,
              onChanged: _setRunning,
            ),
            const SizedBox(height: 28),
            Text('Tuning', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _SettingSlider(
              label: 'Dots',
              value: _settings.dotCount.toDouble(),
              min: OverlaySettings.minDots.toDouble(),
              max: OverlaySettings.maxDots.toDouble(),
              display: '${_settings.dotCount}',
              onChanged: (v) =>
                  _previewSetting(_settings.copyWith(dotCount: v.round())),
              onChangeEnd: (_) => _commitSettings(),
            ),
            _SettingSlider(
              label: 'Motion sensitivity',
              value: _settings.sensitivity,
              min: 0.2,
              max: 3.0,
              display: '${_settings.sensitivity.toStringAsFixed(1)}x',
              onChanged: (v) =>
                  _previewSetting(_settings.copyWith(sensitivity: v)),
              onChangeEnd: (_) => _commitSettings(),
            ),
            _SettingSlider(
              label: 'Dot size',
              value: _settings.dotSize,
              min: 0.4,
              max: 3.0,
              display: '${_settings.dotSize.toStringAsFixed(1)}x',
              onChanged: (v) => _previewSetting(_settings.copyWith(dotSize: v)),
              onChangeEnd: (_) => _commitSettings(),
            ),
            _SettingSlider(
              label: 'Opacity',
              value: _settings.opacity,
              min: 0.05,
              max: 1.0,
              display: '${(_settings.opacity * 100).round()}%',
              onChanged: (v) => _previewSetting(_settings.copyWith(opacity: v)),
              onChangeEnd: (_) => _commitSettings(),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HorizonPage()),
              ),
              icon: const Icon(Icons.landscape_outlined),
              label: const Text('Fullscreen horizon'),
            ),
            const SizedBox(height: 24),
            _Footnote(onOpenSettings: () => OverlayController.openAppSettings()),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.state, required this.settings});

  final ValueListenable<SensorState> state;
  final OverlaySettings settings;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 220,
        color: const Color(0xFF101010),
        child: Stack(
          children: [
            Positioned.fill(
              child: DotFieldPreview(state: state, settings: settings),
            ),
            Positioned(
              left: 14,
              top: 12,
              child: Text(
                'PREVIEW',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white38,
                      letterSpacing: 1.6,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2110),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers_outlined, color: Color(0xFFE7B85C)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Allow drawing over other apps',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Android needs this before the dots can appear on top of the app you are '
              'actually using. Nothing is recorded, and taps still go straight through.',
              style: TextStyle(color: Colors.white70),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onGrant, child: const Text('Grant access')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.running,
    required this.enabled,
    required this.onChanged,
  });

  final bool running;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile.adaptive(
        value: running,
        onChanged: enabled ? onChanged : null,
        title: const Text('Draw over other apps'),
        subtitle: Text(
          running
              ? 'Running. Switch apps and the dots stay with you.'
              : 'Off. The cue only shows inside this app.',
          style: const TextStyle(color: Colors.white70),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(display, style: const TextStyle(color: Colors.white54)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.onOpenSettings});

  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Android hides every overlay over system permission dialogs and some banking or '
          'DRM screens — that is the OS, not a bug here. Xiaomi, Oppo and Vivo also need '
          '"Display pop-up windows while running in background" enabled separately.',
          style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => onOpenSettings(),
            child: const Text('Open app settings'),
          ),
        ),
      ],
    );
  }
}
