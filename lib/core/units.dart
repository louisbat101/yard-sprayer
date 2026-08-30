/// Pure, framework-free math and unit conversions for the sprayer.
///
/// This file intentionally has **no Flutter imports**: the same logic can be
/// ported line-for-line to the ESP32-S3 firmware (C++) in the hardware phase.
class SprayMath {
  SprayMath._();

  /// Metres/second -> miles/hour.
  static const double mphPerMps = 2.2369362920544;

  static double mpsToMph(double mps) => mps * mphPerMps;

  /// Required flow (US gal/min) to apply [targetGpa] while travelling at
  /// [speedMph] across [activeWidthFt] feet of live boom.
  ///
  /// Standard agricultural formula:  GPM = GPA x MPH x W / 495
  ///
  /// Returns 0 when any input is non-positive (nothing to spray).
  static double requiredGpm({
    required double targetGpa,
    required double speedMph,
    required double activeWidthFt,
  }) {
    if (targetGpa <= 0 || speedMph <= 0 || activeWidthFt <= 0) return 0;
    return targetGpa * speedMph * activeWidthFt / 495.0;
  }

  /// Actual applied rate (GPA) implied by measured [flowGpm], [speedMph] and
  /// [activeWidthFt]. Inverse of [requiredGpm].
  static double actualGpa({
    required double flowGpm,
    required double speedMph,
    required double activeWidthFt,
  }) {
    if (flowGpm <= 0 || speedMph <= 0 || activeWidthFt <= 0) return 0;
    return flowGpm * 495.0 / (speedMph * activeWidthFt);
  }

  /// Feed-forward valve opening (0..100%) that would pass [requiredGpm]
  /// through a linear valve whose 100% position flows [maxFlowGpm].
  static double feedforwardValvePct(double requiredGpm, double maxFlowGpm) {
    if (maxFlowGpm <= 0) return 0;
    final double pct = requiredGpm / maxFlowGpm * 100.0;
    if (pct < 0) return 0;
    if (pct > 100) return 100;
    return pct;
  }

  /// Exponential moving average: blend [prev] toward [sample] by [alpha]
  /// (0..1). A smaller alpha means heavier smoothing.
  static double ema(double prev, double sample, double alpha) {
    return prev + alpha * (sample - prev);
  }
}
