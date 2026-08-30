/// Simulated proportional valve.
///
/// The command is a normalized 0..100% signal (which the real hardware will
/// map to a 0-5 V interface on the ESP32). The *position* follows the command
/// at a configurable slew rate, mimicking a real valve's opening/closing time.
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
      positionPct =
          (positionPct + maxStep < commandPct) ? positionPct + maxStep : commandPct;
    } else if (positionPct > commandPct) {
      positionPct =
          (positionPct - maxStep > commandPct) ? positionPct - maxStep : commandPct;
    }
  }
}
