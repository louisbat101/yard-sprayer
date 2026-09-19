#include <Arduino.h>
#include <WiFi.h>
#include <config.h>
#include <control_engine.h>
#include <display.h>

// Globals
SprayerEngine engine;
uint32_t lastTickMs = 0;
uint32_t lastTabletActivityMs = 0;  // for connection status
uint32_t lastDisplayMs = 0;

// WiFi
WiFiServer tcpServer(WIFI_PORT);
WiFiClient tcpClient;

// External valve override: when the tablet sends VALVE:<pct>, the ESP outputs
// that duty directly (tablet = brain, ESP = actuator). Falls back to the
// ESP's own closed-loop command after 3 s of silence.
volatile float extValvePct = 0.0;
uint32_t lastValveCmdMs = 0;
volatile float valveOutputPct = 0.0;  // what is actually written to PWM

// Flow meter ISR
volatile uint32_t flowPulseCount = 0;

void IRAM_ATTR onFlowPulse() {
  flowPulseCount++;
}

// ============================================================================
// SETUP
// ============================================================================

void setupPwm() {
  // Configure LED PWM for solenoid valve (modern ESP32 Arduino API)
  // Use ledcAttach (newer) instead of ledcAttachPin
  ledcAttach(PIN_VALVE_PWM, VALVE_PWM_FREQ, VALVE_PWM_RESOLUTION);
  ledcWrite(PIN_VALVE_PWM, 0);  // Start closed (0/1023)
  Serial.println("[PWM] Solenoid valve configured: 20 Hz, 10-bit");
}

void setupRelays() {
  pinMode(PIN_PUMP_RELAY, OUTPUT);
  pinMode(PIN_SECTION_L, OUTPUT);
  pinMode(PIN_SECTION_R, OUTPUT);
  
  digitalWrite(PIN_PUMP_RELAY, LOW);
  digitalWrite(PIN_SECTION_L, LOW);
  digitalWrite(PIN_SECTION_R, LOW);
  
  Serial.println("[RELAY] Pump and sections configured (all OFF)");
}

void setupFlowMeter() {
  pinMode(PIN_FLOW_METER, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(PIN_FLOW_METER), onFlowPulse, RISING);
  Serial.println("[FLOW] Meter interrupt configured on GPIO32 (INPUT_PULLUP)");
}

void setupWifi() {
  WiFi.mode(WIFI_AP);
  bool ok = WiFi.softAP(WIFI_SSID, WIFI_PASSWORD);
  tcpServer.begin();
  Serial.printf("[WiFi] AP '%s' %s, IP %s, TCP port %d\n",
                WIFI_SSID,
                ok ? "started" : "FAILED",
                WiFi.softAPIP().toString().c_str(),
                WIFI_PORT);
}

void setup() {
  // Debug serial (USB CH340)
  Serial.begin(115200);
  delay(100);
  
  Serial.println("\n========================================");
  Serial.println("Yard Sprayer ESP32 Firmware v1.0");
  Serial.println("========================================\n");
  
  setupPwm();
  setupRelays();
  setupFlowMeter();
  displayInit();
  setupWifi();
  
  Serial.println("\n[INIT] All systems ready. Waiting for commands...\n");
  lastTickMs = millis();
}

// ============================================================================
// SENSOR READING
// ============================================================================

float readFlowGpm() {
  static uint32_t lastCount = 0;
  uint32_t pulses = flowPulseCount - lastCount;
  lastCount = flowPulseCount;
  
  // 100 ms interval between calls
  float litersPerSec = (pulses / FLOW_K_FACTOR) / 0.1;
  float gpm = litersPerSec * 0.264172;  // L/s to GPM
  
  return fmax(0.0, gpm);  // Clamp to >= 0
}

// Ground speed + satellite count come from the tablet's built-in GPS
// over serial (SPEED: and SATS: commands). No external GPS on the ESP32.
volatile float tabletSpeedMph = 0.0;
volatile uint8_t tabletGpsSats = 0;
volatile float tabletGpm = 0.0;  // tablet's simulated/measured flow for display

// ============================================================================
// COMMAND PROCESSING (from tablet via WiFi TCP or USB Serial)
// ============================================================================

void sendResponse(const String& msg) {
  Serial.println(msg);
  if (tcpClient && tcpClient.connected()) {
    tcpClient.println(msg);
  }
}

void handleCommand(String cmd) {
  cmd.trim();
  if (cmd.length() == 0) return;
  
  // Any traffic from the tablet = connected
  lastTabletActivityMs = millis();
  
  if (cmd == "PING") {
    sendResponse("{\"ack\":\"PONG\"}");
  }
  else if (cmd == "SPRAY_ON") {
    engine.setSprayOn(true);
    sendResponse("{\"ack\":\"SPRAY_ON\"}");
  } 
  else if (cmd == "SPRAY_OFF") {
    engine.setSprayOn(false);
    sendResponse("{\"ack\":\"SPRAY_OFF\"}");
  }
  else if (cmd == "SECTION_L_ON") {
    engine.setSectionLeft(true);
    sendResponse("{\"ack\":\"SECTION_L_ON\"}");
  }
  else if (cmd == "SECTION_L_OFF") {
    engine.setSectionLeft(false);
    sendResponse("{\"ack\":\"SECTION_L_OFF\"}");
  }
  else if (cmd == "SECTION_R_ON") {
    engine.setSectionRight(true);
    sendResponse("{\"ack\":\"SECTION_R_ON\"}");
  }
  else if (cmd == "SECTION_R_OFF") {
    engine.setSectionRight(false);
    sendResponse("{\"ack\":\"SECTION_R_OFF\"}");
  }
  else if (cmd.startsWith("TARGET_GPA:")) {
    float gpa = cmd.substring(11).toFloat();
    engine.setTargetGpa(gpa);
    sendResponse("{\"ack\":\"TARGET_GPA:" + String(gpa, 1) + "\"}");
  }
  else if (cmd.startsWith("SPEED:")) {
    tabletSpeedMph = cmd.substring(6).toFloat();
    sendResponse("{\"ack\":\"SPEED:" + String(tabletSpeedMph, 1) + "\"}");
  }
  else if (cmd.startsWith("SATS:")) {
    tabletGpsSats = (uint8_t)cmd.substring(5).toInt();
    sendResponse("{\"ack\":\"SATS:" + String(tabletGpsSats) + "\"}");
  }
  else if (cmd.startsWith("VALVE:")) {
    extValvePct = cmd.substring(6).toFloat();
    lastValveCmdMs = millis();
    sendResponse("{\"ack\":\"VALVE:" + String(extValvePct, 1) + "\"}");
  }
  else if (cmd.startsWith("GPM:")) {
    tabletGpm = cmd.substring(4).toFloat();
    sendResponse("{\"ack\":\"GPM:" + String(tabletGpm, 2) + "\"}");
  }
  else if (cmd == "STATUS") {
    const SprayerTelemetry& t = engine.getTelemetry();
    char buf[160];
    snprintf(buf, sizeof(buf),
      "{\"speed\":%.1f,\"target_gpa\":%.1f,\"actual_gpm\":%.2f,"
      "\"valve\":%.1f,\"spray\":%s,\"sats\":%d}",
      t.groundSpeedMph,
      t.targetGpa,
      t.actualGpm,
      t.valveCommandPct,
      t.sprayOn ? "true" : "false",
      t.gpsSatellites);
    sendResponse(String(buf));
  }
}

// ============================================================================
// CONTROL LOOP (100 ms tick)
// ============================================================================

void loop() {
  uint32_t now = millis();
  uint32_t elapsed = now - lastTickMs;
  
  if (elapsed >= CONTROL_LOOP_MS) {
    lastTickMs = now;
    
    // Read sensors
    float flowGpm = readFlowGpm();
    float speedMph = tabletSpeedMph;
    uint8_t gpsSats = tabletGpsSats;
    
    // Update engine (pressure not used yet → 0.0)
    float dt = CONTROL_LOOP_MS / 1000.0;
    engine.tick(dt, speedMph, flowGpm, 0.0, gpsSats, -1.0);
    
    // Apply outputs
    const SprayerTelemetry& tel = engine.getTelemetry();
    
    // Valve: external override (tablet) if recent, else engine's own command
    float valveOut = tel.valveCommandPct;
    if (millis() - lastValveCmdMs < 3000) {
      valveOut = extValvePct;
    }
    valveOut = constrain(valveOut, 0.0f, 100.0f);
    valveOutputPct = valveOut;

    // Valve: convert 0-100% to 0-1023
    int valveDuty = (int)(valveOut * 10.23);
    valveDuty = constrain(valveDuty, 0, 1023);
    ledcWrite(PIN_VALVE_PWM, valveDuty);
    
    // Relays
    digitalWrite(PIN_PUMP_RELAY, tel.pumpOn ? HIGH : LOW);
    digitalWrite(PIN_SECTION_L, tel.sectionLActive ? HIGH : LOW);
    digitalWrite(PIN_SECTION_R, tel.sectionRActive ? HIGH : LOW);
    
    // Optional: print status every 1 second (10 ticks)
    static int tickCount = 0;
    if (++tickCount >= 10) {
      tickCount = 0;
      Serial.printf(
        "TICK: speed=%.1f mph, gpm=%.2f, valve=%.1f%%\n",
        tel.groundSpeedMph,
        tabletGpm,
        valveOutputPct
      );
    }
  }
  
  // Refresh display every 500 ms
  if (now - lastDisplayMs >= 500) {
    lastDisplayMs = now;
    bool connected = (tcpClient && tcpClient.connected()) ||
                     (millis() - lastTabletActivityMs) < 3000;
    displayUpdate(engine.getTelemetry(), connected, valveOutputPct, tabletGpm);
  }
  
  // ---- WiFi: accept new tablet connection (drop any stale client) -------
  WiFiClient incoming = tcpServer.available();
  if (incoming) {
    if (tcpClient) tcpClient.stop();
    tcpClient = incoming;
    Serial.println("[WiFi] Tablet connected");
  }
  if (tcpClient && !tcpClient.connected()) {
    tcpClient.stop();
    Serial.println("[WiFi] Tablet disconnected");
  }
  
  // ---- WiFi: read commands ----
  while (tcpClient && tcpClient.connected() && tcpClient.available()) {
    String line = tcpClient.readStringUntil('\n');
    handleCommand(line);
  }
  
  // ---- USB serial: read commands (debug / fallback) ----
  while (Serial.available()) {
    String line = Serial.readStringUntil('\n');
    handleCommand(line);
  }
  
  delay(5);  // Prevent watchdog reset
}
