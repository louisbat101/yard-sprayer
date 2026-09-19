/// Normalized valve controller.
///
/// On hardware, the [commandPct] (0-100%) is interpreted as:
///   • Proportional valve: 0-5V DAC output (expensive, complex)
///   • PWM solenoid coils: PWM duty cycle (cheap, proven, recommended)
///
/// The [positionPct] follows the command with a configurable slew rate,
/// mimicking a real valve's opening/closing time (or solenoid actuation delay).
/// This rate limiting prevents controller jitter and smooths transitions.
///
/// **Recommended:** PWM solenoid at 20 Hz (see docs/esp32-pwm-solenoid.md)
class ProportionalValve {
  double positionPct = 0;

  double get position => positionPct;

  /// Move the physical position toward [commandPct], limited by
  /// [maxSlewPctPerSec] over [dt] seconds.
  void update({
    required double commandPct,
    required double dt,
    required double maxSlewPctPerSec,
  }) {
    final double maxStep = maxSlewPctPerSec * dt;
    if (positionPct < commandPct) {
      positionPct = (positionPct + maxStep < commandPct)
          ? positionPct + maxStep
          : commandPct;
    } else if (positionPct > commandPct) {
      positionPct = (positionPct - maxStep > commandPct)
          ? positionPct - maxStep
          : commandPct;
    }
  }
}
