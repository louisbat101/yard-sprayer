# ESP32-S3 PWM Solenoid Valve Control

## Overview

This controller uses **PWM (Pulse Width Modulation)** to drive 12V solenoid coils for flow control instead of an analog proportional valve. The rate controller calculates a command in **0-100%** which maps directly to PWM duty cycle.

---

## Hardware Wiring

```
ESP32 (T-Display, 3.3V logic)
  GPIO 25 (PWM output, 20 Hz)
         │
         ├─ 100Ω ─→ Gate
         │        │
         │        └─→ N-Channel MOSFET (IRLZ44N — LOGIC-LEVEL, not IRF3205)
         │               │
         │               ├─ Source → GND (common with 12V supply GND)
         │               └─ Drain  → one side of coil
         │
   12V supply (+) ──────→ other side of coil
         │
         └─ Flyback Diode (1N4007) ACROSS the coil
            ├─ Cathode (band) → +12V
            └─ Anode   → Drain side

Power Supply: 12V, 2A is plenty (coil only draws ~310 mA)
```

> **MOSFET choice matters:** use a **logic-level** MOSFET (`IRLZ44N`, `AO3400`,
> or a "D4184" driver module). `IRF3205` is a standard-level FET that needs
> ~10 V on the gate — it will NOT fully turn on from a 3.3 V GPIO and will get
> hot. Tie ESP GND, MOSFET source, and 12V supply GND together.

**Pin Assignments:**
- GPIO 25: PWM solenoid valve
- GPIO 26: Section 1 (left boom) relay
- GPIO 27: Section 2 (right boom) relay
- GPIO 14: Pump master relay
- GPIO 35: Flow meter input (frequency counter)
- GPIO 36: Pressure sensor ADC
- GPIO 16: GPS RX (UART)
- GPIO 17: GPS TX (UART)

---

## PWM Configuration (Arduino/PlatformIO)

```cpp
#include <Arduino.h>

const int PWM_PIN = 25;
const int PWM_FREQ = 20;            // 20 Hz (standard solenoid frequency)
const int PWM_RESOLUTION = 10;      // 0-1023 range (10-bit)
const int PWM_CHANNEL = 0;          // LEDC channel 0

void setupValvePWM() {
  // Configure PWM: 20 Hz, 10-bit resolution (0-1023)
  ledcSetup(PWM_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
  ledcAttachPin(PWM_PIN, PWM_CHANNEL);
  ledcWrite(PWM_CHANNEL, 0);  // Start closed
}

// Called from main control loop (100ms)
void setValveDutyCycle(float percentCommand) {
  // Convert 0-100% to 0-1023 range
  int duty = (int)(percentCommand * 10.23);
  duty = constrain(duty, 0, 1023);
  ledcWrite(PWM_CHANNEL, duty);
  
  // Debug: print duty cycle
  // Serial.printf("Valve: %.1f%% → duty %d\n", percentCommand, duty);
}

// Example: Valve command from rate controller
void controlLoop() {
  // valveCommandPct comes from the portable rate controller (0-100)
  // Direct mapping: 50% command = 50% duty cycle
  setValveDutyCycle(valveCommandPct);
}
```

---

## PWM Frequency Considerations

| Frequency | Effect | Recommended |
|-----------|--------|-------------|
| 5 Hz | Very coarse, heavy buzzing | ❌ Too slow |
| 20 Hz | Audible buzz, good linearity | ✅ **Standard** |
| 50 Hz | Less buzzing, still audible | ✅ Quieter |
| 100 Hz | Very quiet, crisp response | ✅ **Best** |
| 500+ Hz | Near silent | Use if low noise required |

**Recommendation:** Start at **20 Hz**, upgrade to **50 Hz** if noise is an issue.

---

## Flow Meter Calibration

The flow meter (turbine sensor) outputs frequency (pulses/second).

```cpp
const float FLOW_K_FACTOR = 7.5;  // pulses per liter (from sensor datasheet)

// Interrupt handler (triggered on rising edge)
volatile uint32_t flowPulseCount = 0;

void IRAM_ATTR onFlowPulse() {
  flowPulseCount++;
}

// Called every 100 ms
float readFlowGpm() {
  static uint32_t lastCount = 0;
  uint32_t pulses = flowPulseCount - lastCount;
  lastCount = flowPulseCount;
  
  // 100 ms = 0.1 sec interval
  float litersPerSec = (pulses / FLOW_K_FACTOR) / 0.1;
  float gpm = litersPerSec * 0.264172;  // L/s to GPM conversion
  return gpm;
}

void setup() {
  attachInterrupt(digitalPinToInterrupt(35), onFlowPulse, RISING);
}
```

---

## Solenoid Opening Behavior

**Important:** Solenoid response is **nonlinear** vs PWM duty cycle.

```
PWM Duty   Solenoid State         Flow Response
0-10%      OFF (no pull)          0% flow (dead zone)
10-30%     Partially energized    ~5-20% flow
30-70%     Proportional pull      ~20-80% flow (linear)
70-100%    Fully energized        ~80-100% flow
```

**Mitigation:**
1. Use **hysteresis** in the rate controller (already in place)
2. Calibrate `valveMinPct` and `valveMaxPct` in config (tune empirically)
3. Dither the solenoid (~2% amplitude) to overcome static friction

---

## Temperature Considerations

Continuous 100% duty = solenoid coil gets hot (~80-100°C).

**Solutions:**
- Limit duty to 90% in calibration if used long-term
- Add heatsink to coil (epoxy thermal paste)
- Use intermittent spray mode (standard practice)
- Monitor coil temperature with thermistor if available

---

## System Diagram (Portability)

```
Yard-Sprayer App (Flutter tablet)
        │
        ├─ lib/core/ (portable, NO Flutter imports)
        │  • SprayerEngine (100ms tick)
        │  • RateController (FF + PI)
        │  • SectionController
        │  • SafetyMonitor
        │  └─ outputs: valveCommandPct (0-100%)
        │
ESP32-S3 Firmware
  ├─ UART: GPS receiver (u-blox M10)
  ├─ GPIO 35: Flow meter (frequency input)
  ├─ GPIO 36: Pressure ADC (0-5V)
  ├─ PWM: Solenoid valve (20/50/100 Hz)
  ├─ GPIO 26/27: Section relays (left/right)
  ├─ GPIO 14: Pump relay
  └─ WiFi: Telemetry back to tablet (optional)
```

**Key Point:** The rate control logic (`lib/core/sprayer_engine.dart`, `rate_controller.dart`) is **100% reusable**. Only the I/O layer changes (proportional valve → PWM solenoid).

---

## Tuning Parameters (sprayer_config.dart)

```dart
class SprayerConfig {
  // ... existing fields ...
  
  /// Min PWM duty for solenoid to pull (0-100%)
  /// Typical: 10-15% (overcome static friction)
  final double valveMinPct = 12.0;
  
  /// Max PWM duty (0-100%)
  /// Limit to 90% for long-term reliability
  final double valveMaxPct = 90.0;
  
  /// Max flow at 100% duty (GPM)
  /// Depends on orifice size and pressure
  /// Typical: 8-15 GPM for lawn sprayer
  final double valveMaxFlowGpm = 12.0;
  
  /// Valve opening/closing speed (% per second)
  /// Solenoids open instantly; use 0 or very high
  /// But slew limit prevents controller jitter
  final double valveMaxSlewPctPerSec = 500.0;
}
```

---

## Testing Checklist

- [ ] PWM outputs on scope: verify 20 Hz frequency, clean rise/fall
- [ ] Solenoid buzzes at 50% duty (good sign of activation)
- [ ] Flow meter counts pulses correctly (compare to manual volume test)
- [ ] Pressure sensor reads 0-400 PSI accurately
- [ ] Valve opens/closes smoothly (no chatter or dead zones)
- [ ] Rate controller maintains target GPA ±10% in SIM mode
- [ ] Sections (left/right) toggle correctly
- [ ] Pump relay clicks on when spray is ON and sections are active
- [ ] Field test: drive at 5 MPH, verify actual GPA = target GPA

---

## Solenoid Valve Specifications

**Verified Component:** 12V DC Solenoid (Trencher brand, common agricultural)

| Parameter | Spec | Notes |
|-----------|------|-------|
| **Rated Voltage** | DC 12V | Standard |
| **Operating Range** | DC 10.8-13.2V | ±10% tolerance |
| **Coil Resistance** | 43.3 ± 0.5 Ω | Affects MOSFET current |
| **Minimum Current** | 310 mA | Must reach this to open |
| **Power Consumption** | 0.9A / 10W @ 12V | Safe for 12V 10A supply |
| **Switching Frequency** | ≤ 20 Hz | **Maximum** → do not exceed |
| **Switch Type** | NC (normally closed) | Opens when powered |
| **Electrical Strength** | 500V / 50Hz, 1mA max leak | Coil isolation certified |
| **Pressure Rating** | 1.2 MPa / 5 min | Handles hydraulic pressure |

**MOSFET Calculation:**
- Coil resistance: 43.3 Ω
- At 12V: I = 12 / 43.3 = 277 mA (nominal)
- Peak with PWM: ~310 mA (min to open per spec)
- **MOSFET selection:** `IRLZ44N` (logic-level N-Ch, 47A, Vgs(th) 1-2 V) — turns fully on from the 3.3 V GPIO. `IRF3205` is NOT logic-level and will not work correctly here.

---

## Cost Breakdown (BOM)

| Item | Qty | Cost | Notes |
|------|-----|------|-------|
| ESP32 dev board (T-Display) | 1 | $25 | LilyGO T-Display or similar |
| 12V solenoid coils | 2 | $40 | DC NC, 43.3 Ω, 310 mA min, ≤20 Hz |
| N-Ch MOSFET (IRLZ44N) | 2 | $4 | **Logic-level** (3.3V gate), or D4184 modules |
| 1N4007 flyback diodes | 2 | $0.50 | Protect MOSFETs |
| 12V relay (pump) | 1 | $8 | 10A, SPDT |
| u-blox M10 GPS | 1 | $45 | UART, ±5m accuracy (optional — tablet GPS used now) |
| Turbine flow meter | 1 | $60 | 7.5 K-factor typical |
| Pressure transducer | 1 | $35 | 0-400 PSI, 0-5V output (deferred) |
| 12V 2A PSU | 1 | $12 | Regulated, fused (310 mA coil) |
| Connectors, wiring, heatsink | — | $20 | Miscellaneous |
| **Total** | — | **$270** | Ready to spray! |

---

## References

- **ESP32 PWM:** https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-reference/peripherals/ledc.html
- **Solenoid valve 101:** Flyback diode essential! See MOSFET application note.
- **u-blox M10:** M10U-10SA module, ~115200 baud, NMEA+UBX protocol
- **Turbine flow meter:** Typically 5.5-7.5 K-factor, ≤600 PSI rated
