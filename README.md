# Kinetosis Horizon

A free Android app that reduces motion sickness (kinetosis) for passengers by drawing a live motion
cue **over whatever app you are actually using**.

## Why

Motion sickness is a mismatch between vestibular (inner ear) and visual signals. Reading your phone
in a moving car tells your eyes "nothing is moving" while your inner ear disagrees — your brain
treats the conflict as a toxin and induces nausea.

The fix only works if the cue is visible *while you read*. So the dots are not a screen you have to
sit and stare at: they are a transparent overlay that floats above Messages, Maps, Photos, anything.
Turn it on once and forget it.

A commercial app called **Kinestop** does the same thing but is paywalled. This is the free
alternative.

## How it works

- **A system overlay, not a screen.** A foreground service owns a `TYPE_APPLICATION_OVERLAY` window
  flagged `FLAG_NOT_TOUCHABLE`, so the dots draw on top of every app and every one of your taps
  still lands on the app underneath.
- **Depth parallax.** Each dot sits at a depth. Near dots are drawn larger and displaced further
  than far ones, so the field reads as a world outside the car rather than as decoration painted on
  the glass.
- **Earth-referenced.** The whole field counter-rotates against the device's roll, so it stays level
  with gravity while the phone tilts.
- **Damped springs.** Dots chase their displaced target through a critically damped spring, turning
  noisy accelerometer input into a glide that settles instead of a jitter.
- **Idle when dark.** Sensors and the vsync loop shut down on screen-off and resume on wake, so a
  whole journey with the phone pocketed costs nothing.

## Setup

Flutter SDK required locally (Flutter 3.24.x, Dart 3.5+). From the repo root:

```
flutter pub get
flutter run
```

JDK 17 is recommended — Gradle 8.3 in the wrapper does not support JDK 21. `minSdk` is 26, the API
level that introduced `TYPE_APPLICATION_OVERLAY`.

To build an installable APK:

```
flutter build apk --release
```

CI also builds an APK on every push to `main` and to `claude/**`, downloadable from the run's
artifacts. Pushes to `main` additionally cut a GitHub Release tagged from the `pubspec.yaml`
version, with `app-release.apk` attached.

## Usage

1. Open the app and grant **Display over other apps** when prompted.
2. Flip **Draw over other apps** on. An ongoing notification appears with a **Stop** action.
3. Leave the app and use your phone normally. The dots stay.
4. Tune dot count, sensitivity, size and opacity from the home screen; the preview above the
   sliders shows exactly what the overlay will do, and changes apply live.
5. **Fullscreen horizon** is still there for when you can give the screen your whole attention: a
   tilt-compensated sky/ground split with a pitch ladder and a calibrate button for dash mounts.

## Project layout

```
lib/
  main.dart                       # app shell
  home_page.dart                  # control panel: toggle, permissions, tuning, live preview
  overlay_controller.dart         # MethodChannel bridge to the Android service
  models/overlay_settings.dart    # tuning knobs
  models/sensor_state.dart        # immutable sensor snapshot
  services/sensor_service.dart    # sensor streams + low-pass filter (in-app only)
  widgets/dot_field_painter.dart  # Dart twin of the overlay renderer, used by the preview
  horizon_page.dart               # optional fullscreen horizon mode
  widgets/horizon_painter.dart    # sky, ground, pitch ladder

android/app/src/main/kotlin/com/kinetosis/kinetosis_horizon/
  MainActivity.kt                 # MethodChannel + permission intents
  overlay/OverlayService.kt       # foreground service, notification, window lifecycle
  overlay/DotFieldView.kt         # the overlay's renderer, on a Choreographer loop
  overlay/MotionEngine.kt         # sensors -> roll + surge/sway, in screen space
  overlay/DotField.kt             # dot model, depth parallax, spring physics
  overlay/OverlayPrefs.kt         # settings the service can read with no Flutter engine alive
```

Settings live in `SharedPreferences` on the Android side rather than being pushed from Dart on
demand: while you are in another app the Flutter engine is gone, so the service has to be able to
read its own configuration.

## Tuning

Everything user-facing is on the home screen. The baselines the multipliers scale from:

- `DotFieldView.PIXELS_PER_ACCELERATION_UNIT` — drift in px per m/s², at unit depth.
- `DotFieldView.BASE_RADIUS_DP` — dot radius at the far plane.
- `DotField.STIFFNESS` / `MIN_DEPTH` — spring feel and how deep the field goes.
- `MotionEngine.GRAVITY_ALPHA` / `LINEAR_ALPHA` — horizon smoothness and dot responsiveness.

The Dart preview in `lib/widgets/dot_field_painter.dart` mirrors these constants; change both or the
preview stops telling the truth.

## Known platform limits

- Android hides every overlay over system permission dialogs and some banking or DRM screens. That
  is the OS, not a bug here.
- Xiaomi, Oppo and Vivo need **Display pop-up windows while running in background** enabled
  separately, beyond the standard grant. The home screen links out to app settings for this.
- iOS has no equivalent of `SYSTEM_ALERT_WINDOW`, so this approach cannot be ported. An iOS build
  would have to fall back to the fullscreen horizon mode.

## Roadmap

- [ ] Quick Settings tile to toggle the overlay without opening the app
- [ ] Auto-start on detected driving (activity recognition)
- [ ] Gyro complementary filter for banked turns
- [ ] Themes beyond monochrome
