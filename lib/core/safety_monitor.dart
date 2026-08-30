import 'sprayer_config.dart';

/// Safety / protection monitor.
///
/// Flags high pressure, low pressure and loss-of-flow conditions. It only
/// monitors: taking protective action (e.g. forcing the valve closed) is the
/// engine's job, so this class stays a pure sensor-logic module.
class SafetyMonitor {
  bool highPressureAlarm = false;
  bool lowPressureAlarm = false;
  bool lossOfFlowAlarm = false;

  double _lossOfFlowTimer = 0;

  bool get anyAlarm => highPressureAlarm || lowPressureAlarm || lossOfFlowAlarm;

  void reset() {
    highPressureAlarm = false;
    lowPressureAlarm = false;
    lossOfFlowAlarm = false;
    _lossOfFlowTimer = 0;
  }

  void update({
    required bool spraying,
    required double requiredGpm,
    required double actualGpm,
    required double valvePct,
    required double pressurePsi,
    required double dt,
    required SprayerConfig cfg,
  }) {
    if (!spraying) {
      reset();
      return;
    }

    highPressureAlarm = pressurePsi >= cfg.pressureAlarmHighPsi;
    lowPressureAlarm = pressurePsi <= cfg.pressureAlarmLowPsi;

    // Loss of flow: the valve is nearly wide open yet the meter reads far
    // below the required flow. Debounced so a startup transient doesn't trip.
    final bool valveOpenNearMax = valvePct >= cfg.lossOfFlowValvePct;
    final bool flowTooLow =
        requiredGpm > 0.05 && actualGpm < requiredGpm * cfg.lossOfFlowFraction;
    if (valveOpenNearMax && flowTooLow) {
      _lossOfFlowTimer += dt;
    } else {
      _lossOfFlowTimer = 0;
    }
    lossOfFlowAlarm = _lossOfFlowTimer >= cfg.lossOfFlowSeconds;
  }
}
