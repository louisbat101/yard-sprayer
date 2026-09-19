# Yard Sprayer — Rate-Control Test App

Software prototype for an automatic agricultural / yard sprayer controller.
This app **proves the rate-control, section-control, GPS and guidance logic**
before the **ESP32-S3 hardware** is built. It needs no external hardware: it uses the device's built-in GPS and a simulated flow meter, solenoid valve and pressure sensor.

## Hardware Target (ESP32-S3)

**Valve Control:** 12V PWM solenoid coils (cheap, proven, NOT proportional valve)
- 20 Hz PWM duty cycle (0-100%) directly maps to flow
- Cost: $20-50 vs $150 for proportional valve
- See [docs/esp32-pwm-solenoid.md](docs/esp32-pwm-solenoid.md) for firmware details

**Other I/O:**
- GPS: u-blox M10 (±5m accuracy, ~$40)
- Flow meter: turbine sensor (frequency input, ~$60)
- Pressure: 0-400 PSI transducer (0-5V ADC, ~$35)
- Relays: pump master + section solenoids (GPIO outputs)

**Total BOM: ~$270** (electronics only)

## What it does (Version 1)

- Main operator screen: target/actual rate (GPA), speed, required/actual flow
  (GPM), pressure (PSI), valve command (%), GPS status.
- Live GPS (built-in phone/tablet GPS via `geolocator`, browser geolocation on
  web) **and** an indoor Simulation mode.
- Rate-control math: `GPM = GPA × MPH × active width / 495`.
- Two 5-ft boom sections (left/right) with automatic active-width recalculation.
- Closed-loop controller (feed-forward + PI, deadband, slew limit, anti-windup)
  driving a simulated proportional valve from simulated flow-meter feedback.
- Safety monitoring: high/low pressure and debounced loss-of-flow alarms.
- Settings for boom width, section count, target rate, valve limits, controller
  gains and alarm thresholds.

## Run it

```sh
flutter run -d chrome          # quickest way to try it on a Mac (web)
flutter run                    # on an Android phone/tablet
```

The app starts in **Simulation mode** so it can be tested indoors. To drive the
controller, open the **SIM** tab, turn on `SPRAY`, and move the *Flow error*
slider — the valve command will open/close to bring actual flow back to target.

## Project layout

```
lib/
  core/        # framework-free control logic (portable to the ESP32-S3)
    sprayer_engine.dart   # 100 ms control loop that sequences everything
    rate_controller.dart  # feed-forward + PI closed-loop controller
    flow_meter.dart       # simulated flow meter (noise + injectable error)
    proportional_valve.dart
    pressure_sensor.dart
    section_controller.dart
    pump_controller.dart
    safety_monitor.dart
    guidance.dart         # A-B line math (V2 UI pending)
    coverage_map.dart     # coverage accumulator (V2 UI pending)
    job_logger.dart       # job record model + store (V2 UI pending)
  services/    # GPS abstraction + geolocator implementation
  state/       # SprayerViewModel (ChangeNotifier + tick loop + GPS wiring)
  ui/          # screens and widgets
test/          # rate-control verification (spec section 19)
docs/          # architecture + control-design notes
```

The `core/` directory has **no Flutter imports** on purpose — the same logic
translates directly to the ESP32-S3 firmware.

## Milestones

- **V1 (this repo):** main screen, GPS, speed, 10-ft/2-section config, GPA/GPM
  math, sections, simulated flow meter + valve, closed-loop controller.
- **V2:** A-B guidance UI, live coverage map, job recording + replay.
- **V3:** hardware I/O architecture (ESP32-S3 ↔ flow meter, pressure sensor,
  proportional valve, pump + section relays).

See `docs/architecture.md` and `docs/rate-control.md` for details.

