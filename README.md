# Kinetosis Horizon

A free, simple Android app that helps reduce motion sickness (kinetosis) for passengers in moving vehicles.

## Why

Motion sickness is caused by a mismatch between vestibular (inner ear) and visual signals. Looking at a book or phone while riding tells your eyes "nothing is moving," but your inner ear disagrees — your brain treats the conflict as a toxin and induces nausea.

This app renders a live horizon on your screen that stays level with gravity while the phone tilts, plus drifting dots that react to acceleration and turns. Your eyes and inner ear now agree, and the nausea drops.

A commercial app called **Kinestop** does the same thing but is paywalled. This is the free, simple alternative.

## How it works

- **Tilt-compensated horizon.** The accelerometer measures gravity; the app derives roll/pitch and rotates the sky/ground split on-screen in the opposite direction, so the horizon line always appears level with earth.
- **Motion dots.** A field of dots drifts in the opposite direction of the vehicle's linear acceleration (forward/back, left/right), giving your eyes a matching visual cue for what your body feels.
- **Low-pass filtering** keeps the horizon steady without adding perceptible lag.

## First-time setup

Flutter SDK required locally (>= 3.19). From the repo root:

```
flutter create --platforms=android --org com.kinetosis .
flutter pub get
flutter run
```

`flutter create .` in an existing directory is additive — it only generates the Android platform files under `android/`. It will **not** overwrite `pubspec.yaml` or anything under `lib/`.

## Project layout

```
lib/
  main.dart                     # Entry: orientation, immersive mode
  horizon_page.dart             # Single screen: wakelock, calibrate button
  services/sensor_service.dart  # Sensor streams + low-pass filter
  models/sensor_state.dart      # Immutable sensor snapshot
  widgets/horizon_painter.dart  # CustomPainter: horizon, pitch ladder, dots
```

## Usage

1. Open the app in the car.
2. Hold or mount the phone however feels natural.
3. Tap **Calibrate** to zero out your current tilt (useful for dash mounts).
4. Keep your eyes on the horizon.
5. Tap **Reset** to clear calibration.

Screen stays awake while the app is open.

## Tuning

- `lib/services/sensor_service.dart`: `_gravityAlpha` (horizon smoothness) and `_linearAlpha` (dot responsiveness).
- `lib/widgets/horizon_painter.dart`: `dotSensitivity` (how far dots drift per g).

## Roadmap

- [ ] Day/night theme toggle
- [ ] Sensitivity slider in UI
- [ ] Gyro complementary filter for banked turns
- [ ] iOS support
