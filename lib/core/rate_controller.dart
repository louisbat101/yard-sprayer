import 'sprayer_config.dart';

/// Closed-loop rate controller.
///
/// Combines:
///  - feed-forward (valve opening estimated directly from required flow),
///  - proportional + integral correction on the flow error,
///  - a deadband to stop the valve hunting around the target,
///  - a maximum correction rate (slew limit) so the valve never slams,
///  - output clamping to the configured valve range.
///
/// GPS only ever determines the *required* flow; the flow meter provides the
/// *actual* feedback this controller acts on.
class RateController {
  double _integral = 0;
  double _lastValvePct = 0;

  /// Integral anti-windup bound (percent of valve authority).
  static const double _integralWindup = 50.0;

  double get lastValvePct => _lastValvePct;

  /// Reset the controller state. Called on startup, master OFF, and when a
  /// section change makes the required flow jump to zero.
  void reset({double valvePct = 0}) {
    _integral = 0;
    _lastValvePct = valvePct.clamp(0, 100).toDouble();
  }

  /// Advance one control step.
  ///
  /// [requiredGpm] - target flow from GPS + boom geometry.
  /// [actualGpm]   - measured flow (flow-meter feedback).
  /// [ffPct]       - feed-forward opening estimate for [requiredGpm].
  /// [dt]          - step time in seconds.
  /// [cfg]         - gains, deadband, limits and slew rate.
  ///
  /// Returns the valve command in the range 0..100%.
  double update({
    required double requiredGpm,
    required double actualGpm,
    required double ffPct,
    required double dt,
    required SprayerConfig cfg,
  }) {
    double error = requiredGpm - actualGpm;

    // Deadband: treat tiny errors as zero so the valve does not hunt.
    if (error.abs() <= cfg.deadbandGpm) {
      error = 0;
    } else {
      // Integrate only outside the deadband (anti-hunt + anti-windup).
      _integral += error * dt;
    }

    // Clamp the integrator to what the valve authority can actually use.
    if (_integral > _integralWindup) _integral = _integralWindup;
    if (_integral < -_integralWindup) _integral = -_integralWindup;

    // Feed-forward + PI correction.
    double desired = ffPct + cfg.kp * error + cfg.ki * _integral;

    // Maximum correction rate: limit how far the command may move per step.
    final double maxStep = cfg.maxCorrectionPctPerSec * dt;
    double out = _lastValvePct;
    if (desired > out) {
      out = (out + maxStep < desired) ? out + maxStep : desired;
    } else if (desired < out) {
      out = (out - maxStep > desired) ? out - maxStep : desired;
    }

    // Final clamp to the configured valve range.
    if (out > cfg.valveMaxPct) out = cfg.valveMaxPct;
    if (out < cfg.valveMinPct) out = cfg.valveMinPct;

    _lastValvePct = out;
    return out;
  }
}
