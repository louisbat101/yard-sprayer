#pragma once

#include <stdint.h>
#include <cmath>

// Portable control engine (no platform-specific code)
// Mirrors lib/core/sprayer_engine.dart logic in C++

struct RateControllerConfig {
  double proportionalGain = 1.0;
  double integralGain = 0.5;
  double integralLimit = 50.0;  // Anti-windup
  double deadband = 2.0;         // Ignore errors < 2 GPM
  double maxSlewPerSec = 500.0;  // Max valve % change/sec
};

struct RateController {
  RateControllerConfig config;
  double integralError = 0.0;
  double lastValveCommandPct = 0.0;
  
  // Feed-forward + PI control
  // Returns valve command 0-100%
  double update(
    double targetGpm,
    double actualGpm,
    double groundSpeedMph,
    double boomWidthFt,
    double dt
  ) {
    // Error
    double error = targetGpm - actualGpm;
    
    // Deadband
    if (fabs(error) < config.deadband) {
      error = 0.0;
    }
    
    // Integral with anti-windup
    integralError += error * dt;
    if (integralError > config.integralLimit) {
      integralError = config.integralLimit;
    }
    if (integralError < -config.integralLimit) {
      integralError = -config.integralLimit;
    }
    
    // PI output (0-100%)
    double commandPct = 
      config.proportionalGain * error + 
      config.integralGain * integralError;
    
    // Clamp 0-100
    commandPct = fmax(0.0, fmin(100.0, commandPct));
    
    // Slew limiting
    double maxChange = config.maxSlewPerSec * dt;
    double change = commandPct - lastValveCommandPct;
    if (change > maxChange) {
      commandPct = lastValveCommandPct + maxChange;
    } else if (change < -maxChange) {
      commandPct = lastValveCommandPct - maxChange;
    }
    
    lastValveCommandPct = commandPct;
    return commandPct;
  }
};

struct SprayerTelemetry {
  float groundSpeedMph = 0.0;
  float targetGpa = 150.0;
  float actualGpa = 0.0;
  float actualGpm = 0.0;
  float requiredGpm = 0.0;
  float pressurePsi = 0.0;
  float valveCommandPct = 0.0;
  bool sprayOn = false;
  bool sectionLActive = false;
  bool sectionRActive = false;
  bool pumpOn = false;
  uint8_t gpsSatellites = 0;
  float gpsAccuracyM = -1.0;  // -1 = no fix
};

class SprayerEngine {
public:
  SprayerEngine() : rateCfg(), controller({rateCfg}) {}
  
  // Called every CONTROL_LOOP_MS
  void tick(float dt, 
            float groundSpeedMph,
            float actualGpm,
            float pressurePsi,
            uint8_t gpsSatellites,
            float gpsAccuracyM) {
    
    telemetry.groundSpeedMph = groundSpeedMph;
    telemetry.gpsSatellites = gpsSatellites;
    telemetry.gpsAccuracyM = gpsAccuracyM;
    telemetry.pressurePsi = pressurePsi;
    telemetry.actualGpm = actualGpm;
    
    // Required flow: GPM = GPA × MPH × width / 495
    telemetry.requiredGpm = 
      (telemetry.targetGpa * groundSpeedMph * boomWidthFt) / 495.0;
    
    // Rate control
    if (telemetry.sprayOn) {
      telemetry.valveCommandPct = controller.update(
        telemetry.requiredGpm,
        actualGpm,
        groundSpeedMph,
        boomWidthFt,
        dt
      );
    } else {
      telemetry.valveCommandPct = 0.0;
    }
    
    // Pump on if spray is on
    telemetry.pumpOn = telemetry.sprayOn && 
                       (telemetry.sectionLActive || telemetry.sectionRActive);
  }
  
  void setSprayOn(bool on) {
    telemetry.sprayOn = on;
    if (!on) {
      controller.integralError = 0.0;  // Reset integrator
    }
  }
  
  void setTargetGpa(float gpa) {
    telemetry.targetGpa = gpa;
  }
  
  void setSectionLeft(bool active) {
    telemetry.sectionLActive = active;
  }
  
  void setSectionRight(bool active) {
    telemetry.sectionRActive = active;
  }
  
  void setBoomWidth(float ft) {
    boomWidthFt = ft;
  }
  
  const SprayerTelemetry& getTelemetry() const {
    return telemetry;
  }

private:
  RateControllerConfig rateCfg;
  RateController controller;
  SprayerTelemetry telemetry;
  float boomWidthFt = 10.0;  // Default: 2 × 5ft sections
};
