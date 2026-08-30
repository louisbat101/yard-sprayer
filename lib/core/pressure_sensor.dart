import 'dart:math' as math;

import 'units.dart';

/// Simulated pressure sensor.
///
/// Pressure is **not** primary rate-control feedback — flow is. Pressure is
/// used only for display and for high/low pressure protection, mirroring the
/// eventual real pressure transducer.
class SimulatedPressureSensor {
  final math.Random _rng = math.Random(777);
  double _value = 0;

  double get last => _value;

  void reset() => _value = 0;

  /// Pressure drops as flow increases (a fixed-RPM pump throttled by the
  /// valve), plus a small amount of sensor noise. Returns the smoothed PSI.
  double measure({
    required double flowGpm,
    required bool pumpRunning,
    required double biasPsi,
    required double idlePsi,
    required double dropPerGpm,
  }) {
    final double noise = (_rng.nextDouble() - 0.5) * 1.0; // ±0.5 PSI
    double target = pumpRunning ? (idlePsi - dropPerGpm * flowGpm + biasPsi + noise) : 0.0;
    if (target < 0) target = 0;
    _value = SprayMath.ema(_value, target, 0.3);
    return _value;
  }
}
