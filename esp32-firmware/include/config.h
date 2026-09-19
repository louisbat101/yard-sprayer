#pragma once

// GPIO Pin Assignments (ESP32-D0WDQ6 on CH340 breakout)

// PWM Solenoid Valve Control
#define PIN_VALVE_PWM 25        // GPIO25 → PWM solenoid (12V via MOSFET)
#define VALVE_PWM_FREQ 20       // 20 Hz (per solenoid spec ≤ 20 Hz)
#define VALVE_PWM_RESOLUTION 10 // 10-bit (0-1023)
#define VALVE_PWM_CHANNEL 0     // LEDC channel 0

// Relay Control
#define PIN_PUMP_RELAY 14       // GPIO14 → Pump master relay
#define PIN_SECTION_L 26        // GPIO26 → Left boom relay
#define PIN_SECTION_R 27        // GPIO27 → Right boom relay

// Sensor Inputs
#define PIN_FLOW_METER 32       // GPIO32 → Flow meter pulse input (interrupt, INPUT_PULLUP)

// GPS: comes from the tablet's built-in GPS over serial (SPEED:/SATS: commands).
// No external GPS or pressure sensor wired yet.

// Debug Serial (USB UART, already on CH340 converter)
// Uses default Serial (UART0) on RX0/TX0

// Control Loop Timing
#define CONTROL_LOOP_HZ 10      // 100 ms tick
#define CONTROL_LOOP_MS (1000 / CONTROL_LOOP_HZ)

// WiFi Access Point (tablet connects to this hotspot)
#define WIFI_SSID     "YardSprayer"
#define WIFI_PASSWORD "sprayer1234"
#define WIFI_PORT     8266       // TCP port for tablet link

// Solenoid Valve Configuration
#define VALVE_MIN_PCT 12.0      // Min duty (10-15% to overcome static friction)
#define VALVE_MAX_PCT 90.0      // Max duty (limit for coil thermal safety)
#define VALVE_MAX_SLEW 500.0    // Max % per second (slew limit)

// Flow Meter Configuration
#define FLOW_K_FACTOR 7.5       // Pulses per liter (turbine sensor typical)

// Default Control Parameters (from Flutter app)
#define DEFAULT_TARGET_GPA 150.0    // GPA setpoint
#define DEFAULT_BOOM_WIDTH_FT 10.0  // 2 × 5ft sections
#define DEFAULT_PI_KP 1.0           // Proportional gain
#define DEFAULT_PI_KI 0.5           // Integral gain
