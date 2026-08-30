# Rate-control design

## Core equation

```
Required GPM = GPA × MPH × activeWidthFt / 495
```

Examples (10 GPA):

| Speed | Active width | Required GPM |
|---|---|---|
| 5 MPH | 10 ft | 1.01 |
| 3 MPH | 10 ft | 0.61 |
| 5 MPH | 5 ft | 0.51 |

## Controller

The `RateController` combines three terms each tick:

```
valve% = feedForward% + Kp·error + Ki·∫error dt
```

- **feed-forward** `= requiredGpm / valveMaxFlowGpm × 100` — opens the valve to
  roughly the right place immediately (fast response to speed changes).
- **proportional (Kp)** — trims against the flow-meter error.
- **integral (Ki)** — removes steady-state error and is clamped (anti-windup).

Guards:

- **Deadband** (default ±0.02 GPM): errors inside the band are treated as zero
  so the valve doesn't hunt around the target.
- **Max correction rate** (default 25%/s): bounds how fast the command moves.
- **Valve limits** (default 5..100%): the command is clamped to the hardware.
- **Startup:** on master ON the controller starts closed and ramps up under the
  slew limit; on master OFF it resets and the valve returns to the closed safe
  position.

## Tuning

All gains are adjustable in **Settings**:

| Parameter | Default | Effect |
|---|---|---|
| Kp | 3.0 | faster trim, possible overshoot if too high |
| Ki | 2.0 | removes steady-state error |
| Deadband | 0.02 GPM | larger = less hunting, more steady error |
| Max correction | 25%/s | lower = smoother but slower |

## Loss-of-flow detection

The alarm trips only when the valve is nearly wide open (`lossOfFlowValvePct`,
default 90%) yet the flow meter still reads below `lossOfFlowFraction` (default
30%) of the required flow, sustained for `lossOfFlowSeconds` (default 2 s). This
debounce avoids false alarms during startup ramps.

## Pressure

Pressure is **not** a rate-control input. It is modeled as a fixed-RPM pump
throttled by the valve (`pressure ≈ idlePsi − dropPerGpm × flow`) and is used
only for display plus high/low protection.

## Verification

`test/rate_control_test.dart` encodes the spec's section-19 checks:
required-flow examples, active-width halving, speed-response, low-flow
correction (valve opens), high-flow correction (valve closes), and the
all-sections-off safe state.
