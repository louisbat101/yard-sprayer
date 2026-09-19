# Architecture

## Control chain

```
GPS speed ──► required GPM ──► rate controller ──► valve command ──► simulated
               (GPA×MPH×W/495)      (FF + PI)        (0-100%)         valve
                                                                        │
                                                                        ▼
        rate controller ◄── flow feedback ◄── flow meter ◄── simulated flow
```

- **GPS determines the *required* flow only.** Ground speed drives the target
  GPM; position/heading drive guidance + coverage.
- **The flow meter determines the *actual* feedback.** The controller compares
  required vs. actual and adjusts the valve. Actual GPA is *derived* from actual
  flow (never from GPS alone).

## Modules

| Module | File | Role |
|---|---|---|
| `SprayerEngine` | `core/sprayer_engine.dart` | 100 ms control loop; sequences all subsystems |
| `RateController` | `core/rate_controller.dart` | feed-forward + PI, deadband, slew limit, anti-windup |
| `SimulatedFlowMeter` | `core/flow_meter.dart` | filtered flow with noise + injectable error |
| `ProportionalValve` | `core/proportional_valve.dart` | normalized 0-100% command, slew-limited position |
| `SimulatedPressureSensor` | `core/pressure_sensor.dart` | pressure display + protection only |
| `SectionController` | `core/section_controller.dart` | ON/OFF states → active boom width |
| `PumpController` | `core/pump_controller.dart` | run = master ON && any section ON |
| `SafetyMonitor` | `core/safety_monitor.dart` | high/low pressure + debounced loss-of-flow |
| `Guidance` | `core/guidance.dart` | A-B line math (V2 UI) |
| `CoverageMap` | `core/coverage_map.dart` | sprayed-area accumulator (V2 UI) |
| `JobLogger` | `core/job_logger.dart` | job record model + store (V2 UI) |
| `GpsSource` / `GeolocatorGpsSource` | `services/` | GPS abstraction + real receiver |
| `SprayerViewModel` | `state/sprayer_view_model.dart` | ChangeNotifier; owns tick + GPS + mode switches |

## Portability to the ESP32-S3

`lib/core/` contains **no Flutter imports**. The ESP32-S3 firmware will reuse:

- `SprayMath` (GPA/GPM/feed-forward formulas) verbatim.
- `RateController` (gains, deadband, slew limit, anti-windup) — the same loop.
- `SectionController`, `PumpController`, `SafetyMonitor` state machines.

Only the I/O differs on hardware:

| Prototype (Android) | ESP32-S3 hardware (PWM Solenoid) |
|---|---|
| `GeolocatorGpsSource` | u-blox M10 GPS (UART) |
| `SimulatedFlowMeter` | Turbine flow meter (frequency input, GPIO interrupt) |
| `SimulatedPressureSensor` | Pressure transducer (0-5V ADC) |
| valve command 0-100% | **PWM duty cycle (20Hz, GPIO 25) → 12V solenoid coil** |
| `PumpController` flag | Pump relay (GPIO 14) |
| `SectionController` flags | Left/right section relays (GPIO 26/27) |

**Valve Control (Key Change):**
- **NOT a proportional valve** (complex, expensive $80-150)
- **Simple PWM solenoid** (cheap, proven $20-50)
- Rate controller already outputs 0-100% → maps directly to PWM duty cycle
- 20 Hz PWM gives smooth opening + acceptable solenoid buzz
- See [esp32-pwm-solenoid.md](esp32-pwm-solenoid.md) for firmware details

## Concurrency / tick

- `SprayerViewModel` runs a `Timer.periodic(100 ms)` that calls
  `engine.tick(0.1)` then notifies listeners.
- GPS fixes arrive asynchronously and are stored via `engine.applyGpsFix()`.
- The controller is intentionally a fixed-rate loop: on the ESP32 it will run on
  a hardware timer at the same 10 Hz.
