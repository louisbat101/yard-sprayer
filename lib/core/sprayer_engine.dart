import 'dart:math' as math;

import 'gps_fix.dart';
import 'flow_meter.dart';
import 'pressure_sensor.dart';
import 'proportional_valve.dart';
import 'pump_controller.dart';
import 'rate_controller.dart';
import 'safety_monitor.dart';
import 'section_controller.dart';
import 'sprayer_config.dart';
import 'units.dart';

/// Where the speed/position inputs come from.
enum SprayerMode { simulation, live }

/// The heart of the rate-control prototype.
///
/// Orchestrates every subsystem on a fixed tick (100 ms) and exposes the
/// resulting state as plain fields the UI can read. It is framework-free:
/// the same sequencing can be translated to the ESP32-S3 control loop.
///
/// Control chain:
///   GPS speed -> required GPM -> rate controller -> valve command
///     -> simulated flow -> flow meter -> feedback -> rate controller
class SprayerEngine {
  SprayerConfig config;

  final SectionController sections;
  final ProportionalValve valve;
  final SimulatedFlowMeter flowMeter;
  final SimulatedPressureSensor pressureSensor;
  final RateController rateController;
  final PumpController pump;
  final SafetyMonitor safety;

  // --- Master / mode state -------------------------------------------------
  bool sprayOn = false;
  bool manualValveOverride = false; // open-loop valve control (sim only)
  SprayerMode mode = SprayerMode.simulation;

  // --- Live GPS inputs -----------------------------------------------------
  GpsFix? lastFix;
  double gpsSpeedMph = 0;
  double gpsHeadingDeg = 0;
  double gpsAccuracyM = 0;
  double gpsLat = 0;
  double gpsLon = 0;
  bool gpsFixOk = false;
  int satellites = 0;

  // --- Simulation inputs ---------------------------------------------------
  double simSpeedMph = 5.0;
  double simHeadingDeg = 0;
  double flowErrorGpm = 0; // deliberate disturbance (test the controller)
  double manualValvePct = 0;
  double pressureBiasPsi = 0;
  double simLat = 40.0; // seed position for the simulated vehicle
  double simLon = -90.0;

  // --- Computed outputs (read by the UI) -----------------------------------
  double speedMph = 0;
  double headingDeg = 0;
  double requiredGpm = 0;
  double actualGpm = 0;
  double valveCommandPct = 0;
  double valvePositionPct = 0;
  double pressurePsi = 0;
  double actualGpa = 0;
  double activeWidthFt = 0;

  SprayerEngine({SprayerConfig? config})
    : config = config ?? const SprayerConfig(),
      sections = SectionController(config?.sectionCount ?? 2),
      valve = ProportionalValve(),
      flowMeter = SimulatedFlowMeter(),
      pressureSensor = SimulatedPressureSensor(),
      rateController = RateController(),
      pump = PumpController(),
      safety = SafetyMonitor();

  double get targetGpa => config.targetGpa;
  bool get pumpRunning => pump.running;

  /// Current position/heading used by guidance, coverage and job recording.
  double get currentLat => mode == SprayerMode.live ? gpsLat : simLat;
  double get currentLon => mode == SprayerMode.live ? gpsLon : simLon;
  double get currentHeadingDeg => headingDeg;

  /// Satellites in view (reported by the native GNSS listener when live;
  /// simulated count in SIM mode).
  int get satelliteCount => mode == SprayerMode.simulation ? 12 : satellites;

  /// Feed a new GPS sample from the live receiver.
  void applyGpsFix(GpsFix fix) {
    lastFix = fix;
    gpsFixOk = fix.hasFix;
    if (fix.hasFix) {
      gpsLat = fix.latitude;
      gpsLon = fix.longitude;
      gpsSpeedMph = fix.speedMph;
      gpsHeadingDeg = fix.headingDeg;
      gpsAccuracyM = fix.accuracyM;
      satellites = fix.satellites ?? satellites;
    }
  }

  /// Master spray switch. Turning OFF drives the valve to its safe (closed)
  /// position and resets the controller and safety monitors.
  void setSprayOn(bool on) {
    sprayOn = on;
    if (!on) {
      rateController.reset(valvePct: 0);
      safety.reset();
    }
  }

  /// Change config (e.g. from the Settings screen) and keep the section
  /// states in sync with any change to the section count.
  void applyConfig(SprayerConfig next) {
    config = next;
    sections.resize(next.sectionCount);
  }

  /// Advance the whole system by [dt] seconds.
  void tick(double dt) {
    // 1) Speed / heading source --------------------------------------------
    if (mode == SprayerMode.simulation) {
      speedMph = SprayMath.ema(speedMph, simSpeedMph, config.speedFilterAlpha);
      headingDeg = simHeadingDeg;
      _advanceSimulation(dt);
    } else {
      speedMph = SprayMath.ema(
        speedMph,
        gpsFixOk ? gpsSpeedMph : 0,
        config.speedFilterAlpha,
      );
      headingDeg = gpsHeadingDeg;
      simLat = gpsLat; // keep the mirror position for the UI
      simLon = gpsLon;
    }

    // 2) Active boom width --------------------------------------------------
    activeWidthFt = sprayOn
        ? sections.activeWidthFt(config.sectionWidthsFt)
        : 0.0;

    // 3) Required flow (GPS + geometry only; NOT the flow meter) ------------
    requiredGpm = SprayMath.requiredGpm(
      targetGpa: config.targetGpa,
      speedMph: speedMph,
      activeWidthFt: activeWidthFt,
    );

    // 4) Pump ---------------------------------------------------------------
    pump.update(sprayOn: sprayOn, anySectionOn: sections.anyOn);

    // 5) Valve command ------------------------------------------------------
    if (manualValveOverride) {
      double cmd = manualValvePct;
      if (cmd > config.valveMaxPct) cmd = config.valveMaxPct;
      if (cmd < config.valveMinPct) cmd = config.valveMinPct;
      valveCommandPct = cmd;
      rateController.reset(valvePct: cmd);
    } else if (!sprayOn || requiredGpm <= 0) {
      rateController.reset(valvePct: 0);
      valveCommandPct = 0;
    } else {
      final double ff = SprayMath.feedforwardValvePct(
        requiredGpm,
        config.valveMaxFlowGpm,
      );
      valveCommandPct = rateController.update(
        requiredGpm: requiredGpm,
        actualGpm: actualGpm,
        ffPct: ff,
        dt: dt,
        cfg: config,
      );
    }

    // 6) Valve position follows the command (slew-limited) -------------------
    valve.update(
      commandPct: valveCommandPct,
      dt: dt,
      maxSlewPctPerSec: config.valveMaxSlewPctPerSec,
    );
    valvePositionPct = valve.positionPct;

    // 7) Flow meter ---------------------------------------------------------
    // Flow only exists while the pump runs (or during manual override).
    if (pump.running || manualValveOverride) {
      actualGpm = flowMeter.measure(
        valvePositionPct: valvePositionPct,
        maxFlowGpm: config.valveMaxFlowGpm,
        errorOffsetGpm: flowErrorGpm,
        alpha: config.flowFilterAlpha,
      );
    } else {
      actualGpm = 0;
      flowMeter.reset();
    }

    // 8) Pressure (display + protection only) --------------------------------
    pressurePsi = pressureSensor.measure(
      flowGpm: actualGpm,
      pumpRunning: pump.running,
      biasPsi: pressureBiasPsi,
      idlePsi: config.pressureIdlePsi,
      dropPerGpm: config.pressureDropPerGpm,
    );

    // 9) Safety --------------------------------------------------------------
    safety.update(
      spraying: sprayOn,
      requiredGpm: requiredGpm,
      actualGpm: actualGpm,
      valvePct: valvePositionPct,
      pressurePsi: pressurePsi,
      dt: dt,
      cfg: config,
    );

    // 10) Actual applied rate (from flow feedback, smoothed) -----------------
    final double instantGpa = SprayMath.actualGpa(
      flowGpm: actualGpm,
      speedMph: speedMph,
      activeWidthFt: activeWidthFt,
    );
    actualGpa = SprayMath.ema(actualGpa, instantGpa, config.gpaFilterAlpha);
  }

  /// Move the simulated vehicle along [simHeadingDeg] at [simSpeedMph].
  void _advanceSimulation(double dt) {
    final double distM = SprayMath.mphPerMps * simSpeedMph * dt;
    final double rad = simHeadingDeg * math.pi / 180.0;
    final double cosLat = math.max(0.01, math.cos(simLat * math.pi / 180.0));
    simLat += math.cos(rad) * distM / 111320.0;
    simLon += math.sin(rad) * distM / (111320.0 * cosLat);
  }
}
