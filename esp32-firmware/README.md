# ESP32 Yard Sprayer Firmware

**Status:** ✅ Compiles, boots, and serves a WiFi hotspot + status display
**Device:** ESP32-D0WDQ6 (classic ESP32, dual-core 240MHz) — LilyGO T-Display (ST7789 135×240)
**USB Port:** `/dev/cu.usbserial-5B0A0072491` (CH340 UART converter)

## WiFi Link (tablet → ESP)

- **SSID:** `YardSprayer`
- **Password:** `sprayer1234`
- **IP:** `192.168.4.1`
- **TCP port:** `8266`

The ESP hosts a hotspot. The Flutter tablet app connects to it and sends
newline-delimited text commands (same protocol as USB serial).

## Quick Start

### Build
```bash
cd /Users/louismacpro/Projects/esp32-yard-sprayer
python3 -m platformio run -e esp32doit-devkit-v1
```

### Flash
```bash
python3 -m platformio run -e esp32doit-devkit-v1 -t upload
```

### Monitor Serial Output
```bash
python3 -m platformio device monitor -p /dev/cu.usbserial-5B0A0072491 -b 115200
```

---

## Architecture

### Core Components

#### 1. **Control Engine** (`include/control_engine.h`)
- Pure C++ port of `lib/core/sprayer_engine.dart`
- Rate controller (feed-forward + PI)
- Valve command 0-100%
- GPS satellite tracking
- Telemetry struct for sensor data

#### 2. **GPIO Configuration** (`include/config.h`)
- Pin assignments for all I/O
- PWM, ADC, interrupt configuration
- Default tuning parameters

#### 3. **Main Loop** (`src/main.cpp`)
- 100 ms tick (10 Hz) = same as Flutter app
- Sensor reading → control → output
- Serial command processing (from tablet)
- Telemetry transmission (JSON)

### Wiring (ESP32 pins)

| Function | GPIO | Device | Voltage |
|----------|------|--------|---------|
| PWM Valve | 25 | Solenoid (via MOSFET) | 12V |
| Pump Relay | 14 | Relay coil | 12V |
| Section L | 26 | Relay coil | 12V |
| Section R | 27 | Relay coil | 12V |
| Flow Meter | 35 | Turbine sensor input | 3.3V |

> **GPS:** Uses the **tablet's built-in GPS** (sent over serial as `SPEED:` / `SATS:`).
> **Pressure:** Not wired yet (placeholder `0.0`).

---

## Features (Implemented)

✅ **PWM Solenoid Control**
- 20 Hz frequency (per solenoid spec ≤ 20 Hz)
- 0-100% mapped to 0-1023 duty cycle
- Slew limiting (500%/sec)

✅ **WiFi Hotspot + TCP server**
- SoftAP `YardSprayer` @ 192.168.4.1:8266
- Tablet connects wirelessly, no cable needed
- Same protocol over TCP and USB serial

✅ **ST7789 Status Display**
- Shows `CONNECTED` (green) when tablet link is active, `WAITING` (red) otherwise
- Live speed, GPM, valve %, target GPA, spray state, satellite count

✅ **Sensor Reading**
- Flow meter: interrupt counting → GPM
- GPS: tablet's built-in GPS via `SPEED:`/`SATS:` commands
- Pressure: skipped for now (passes 0.0 to engine)

✅ **Relay Outputs**
- Pump master, Section L, Section R
- Active-high (LOW = off, HIGH = on)

✅ **Control Loop**
- 100 ms tick (same as Flutter)
- PI controller with anti-windup
- Integrator reset on SPRAY_OFF
- Deadband (2 GPM)

✅ **Serial Command Protocol**
```
PING            → {"ack":"PONG"}
SPRAY_ON        → {"ack":"SPRAY_ON"}
SPRAY_OFF       → {"ack":"SPRAY_OFF"}
SECTION_L_ON    → {"ack":"SECTION_L_ON"}
SECTION_L_OFF   → {"ack":"SECTION_L_OFF"}
SECTION_R_ON    → {"ack":"SECTION_R_ON"}
SECTION_R_OFF   → {"ack":"SECTION_R_OFF"}
TARGET_GPA:150  → {"ack":"TARGET_GPA:150.0"}
SPEED:5.0       → {"ack":"SPEED:5.0"}       (from tablet GPS)
SATS:8          → {"ack":"SATS:8"}          (from tablet GPS)
VALVE:50.0      → {"ack":"VALVE:50.0"}      (direct valve duty 0-100%)
GPM:1.25        → {"ack":"GPM:1.25"}         (tablet's flow, for display)
STATUS          → JSON telemetry (speed, gpa, gpm, valve, spray, sats)
```

> The same protocol works over **WiFi TCP (8266)** and **USB serial**.

---

## Tablet App Integration

The Flutter app (`~/Projects/yard-sprayer`) connects automatically:
- `lib/services/esp32_link.dart` → TCP client (192.168.4.1:8266)
- `lib/state/sprayer_view_model.dart` → 1 Hz heartbeat:
  `PING` + `SPEED:` + `SATS:` + `SPRAY_ON/OFF` + `SECTION_*` + `TARGET_GPA:` + `VALVE:`
- `VALVE:<pct>` overrides the ESP's PWM directly (tablet = brain, ESP = actuator);
  falls back to the ESP's own rate controller after 3 s without a VALVE command.
- Join the `YardSprayer` WiFi on the tablet first, then launch the app.

---

## Features (TODO)

🟡 **GPS Parsing**
- Read UART2 from u-blox M10
- Parse $GPRMC for speed (knots → mph)
- Parse $GPGSV for satellite count
- Parse $GPGGA for accuracy

🟡 **Pressure Sensor** (deferred)
- 0-400 PSI transducer → GPIO 36 ADC
- Wiring + calibration later

🟡 **Safety Features**
- High/low pressure alarms
- Loss-of-flow detection
- E-stop button (GPIO input TODO)
- Watchdog timer

🟡 **Tablet Integration**
- Send telemetry JSON every 100 ms
- Receive commands over Serial/WiFi
- Real-time dashboard display

---

## GPIO Board Reference

```
ESP32-D0WDQ6 Pinout (CH340 breakout)

USB (CH340)
   │
   ├─ RX0/TX0 (Debug serial, 115200)
   │
GND ◄─────────► GND (common with solenoid/relays)
+5V ◄─────────► +5V (for CH340, NOT ESP32 logic)
+3.3V ◄───────► +3.3V (ESP32 logic voltage)

PWM Output (GPIO 25)
   └─ MOSFET Gate ─ IRF3205 ─ 12V Solenoid

ADC Input (GPIO 36 / ADC1_CH0)
   └─ Pressure transducer (0-5V via 4.7k/4.7k divider)

Digital Input (GPIO 35)
   └─ Flow meter frequency

UART (GPIO 4=TX, GPIO 5=RX)
   └─ u-blox M10 GPS module (115200 baud)

Relays (GPIO 14, 26, 27)
   └─ 12V solenoids via driving transistors
```

---

## Testing Checklist

- [ ] Serial monitor shows continuous "TICK:" output (100 ms interval)
- [ ] Send `SPRAY_ON` command → GPIO 14 pump relay activates (HIGH)
- [ ] Send `SECTION_L_ON` command → GPIO 26 section L activates (HIGH)
- [ ] Send `TARGET_GPA:100` → engine updates target (check with STATUS)
- [ ] Apply 12V to solenoid, measure PWM on GPIO 25 with oscilloscope (should be 20 Hz)
- [ ] Connect flow meter, count pulses vs. manual volume test
- [ ] Connect pressure transducer, verify 0-400 PSI ADC reading
- [ ] Connect u-blox GPS, verify UART data arrives
- [ ] Test rate control in SIM mode on tablet (Flutter app sends commands)

---

## Known Issues

- **Boot messages not captured:** First serial output happens before monitor attaches. Reset ESP with button to see startup.
- **GPS not parsing:** UART2 is configured but $GPRMC/etc. parsing not implemented yet.
- **No E-stop:** Safety cutoff requires external button wiring (GPIO input TODO).

---

## Next Steps

1. **Connect real sensors** (flow meter, pressure transducer, GPS)
2. **Calibrate flow meter K-factor** (count pulses during measured flow)
3. **Tune pressure ADC offset** (read at 0 PSI, offset accordingly)
4. **Parse GPS NMEA** (speed from $GPRMC, accuracy from $GPGGA)
5. **Connect tablet via Serial USB** (send commands, receive telemetry)
6. **Field test** with tablet app sending commands, observe rate control response
7. **Add safety features** (alarms, watchdog, estop)
8. **Swap tablet UI to LVGL** on ESP32-P4 (same firmware, no changes needed)

---

## Code References

- **Dart control logic:** [~/Projects/yard-sprayer/lib/core/](../../yard-sprayer/lib/core/)
- **Hardware specs:** [~/Projects/yard-sprayer/docs/esp32-pwm-solenoid.md](../../yard-sprayer/docs/esp32-pwm-solenoid.md)
- **Main app:** [~/Projects/yard-sprayer/](../../yard-sprayer/)
