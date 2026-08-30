import 'dart:math' as math;

import 'units.dart';

/// Simulated flow meter.
///
/// Produces a flow reading from the valve position, then lets the user inject
/// a steady error and noise so the rate controller can be exercised. The
/// reading is exponentially smoothed to imitate a real turbine/mag meter.
class SimulatedFlowMeter {
  final math.Random _rng = math.Random(1234);
  double _smoothed = 0;

  /// Amplitude of the random measurement noise, in GPM (± half of this).
  static const double _noiseAmplitudeGpm = 0.08;

  double get last => _smoothed;

  void reset() => _smoothed = 0;

  /// Compute the filtered flow for this tick.
  ///
  /// [errorOffsetGpm] is the deliberate disturbance the operator introduces
  /// (e.g. -0.16 GPM to simulate a clogged nozzle) so they can watch the
  /// controller open the valve to compensate.
  double measure({
    required double valvePositionPct,
    required double maxFlowGpm,
    required double errorOffsetGpm,
    required double alpha,
  }) {
    final double nominal = maxFlowGpm * valvePositionPct / 100.0;
    final double noise = (_rng.nextDouble() - 0.5) * _noiseAmplitudeGpm;
    final double raw = math.max(0.0, nominal + errorOffsetGpm + noise);
    _smoothed = SprayMath.ema(_smoothed, raw, alpha);
    return _smoothed;
  }
}
