/// User-adjustable sprayer settings and controller tunables.
///
/// Immutable: use [copyWith] to change a field. Kept framework-free so the
/// same defaults can seed the ESP32-S3 firmware.
class SprayerConfig {
  // --- Boom geometry -------------------------------------------------------
  final double boomWidthFt; // total boom width
  final int sectionCount; // number of independently-switched sections
  final List<double> sectionWidthsFt; // width of each section (sums to boom)

  // --- Application target --------------------------------------------------
  final double targetGpa; // desired US gallons/acre
  final double designSpeedMph; // reference operating speed

  // --- Valve / flow hardware ----------------------------------------------
  final double valveMaxFlowGpm; // flow delivered at 100% valve opening
  final double valveMinPct; // minimum allowed command
  final double valveMaxPct; // maximum allowed command
  final double valveMaxSlewPctPerSec; // physical valve speed limit (%/s)

  // --- Rate controller -----------------------------------------------------
  final double kp; // proportional gain (% command per GPM of error)
  final double ki; // integral gain (% command per GPM·s of error)
  final double deadbandGpm; // error deadband to prevent hunting
  final double maxCorrectionPctPerSec; // controller output slew limit (%/s)

  // --- Filtering (alpha applied per 100 ms tick) ---------------------------
  final double flowFilterAlpha;
  final double gpaFilterAlpha;
  final double speedFilterAlpha;

  // --- Pressure / safety ---------------------------------------------------
  final double pressureIdlePsi; // pressure at zero flow (pump running)
  final double pressureDropPerGpm; // pressure fall per GPM of flow
  final double pressureAlarmHighPsi;
  final double pressureAlarmLowPsi;
  final double lossOfFlowValvePct; // valve must be this open to arm the test
  final double lossOfFlowFraction; // actual < required * this => "no flow"
  final double lossOfFlowSeconds; // sustained time before the alarm trips

  const SprayerConfig({
    this.boomWidthFt = 10.0,
    this.sectionCount = 2,
    this.sectionWidthsFt = const [5.0, 5.0],
    this.targetGpa = 10.0,
    this.designSpeedMph = 5.0,
    this.valveMaxFlowGpm = 6.0,
    this.valveMinPct = 5.0,
    this.valveMaxPct = 100.0,
    this.valveMaxSlewPctPerSec = 60.0,
    this.kp = 3.0,
    this.ki = 2.0,
    this.deadbandGpm = 0.02,
    this.maxCorrectionPctPerSec = 25.0,
    this.flowFilterAlpha = 0.4,
    this.gpaFilterAlpha = 0.15,
    this.speedFilterAlpha = 0.25,
    this.pressureIdlePsi = 50.0,
    this.pressureDropPerGpm = 12.0,
    this.pressureAlarmHighPsi = 80.0,
    this.pressureAlarmLowPsi = 10.0,
    this.lossOfFlowValvePct = 90.0,
    this.lossOfFlowFraction = 0.3,
    this.lossOfFlowSeconds = 2.0,
  });

  SprayerConfig copyWith({
    double? boomWidthFt,
    int? sectionCount,
    List<double>? sectionWidthsFt,
    double? targetGpa,
    double? designSpeedMph,
    double? valveMaxFlowGpm,
    double? valveMinPct,
    double? valveMaxPct,
    double? valveMaxSlewPctPerSec,
    double? kp,
    double? ki,
    double? deadbandGpm,
    double? maxCorrectionPctPerSec,
    double? flowFilterAlpha,
    double? gpaFilterAlpha,
    double? speedFilterAlpha,
    double? pressureIdlePsi,
    double? pressureDropPerGpm,
    double? pressureAlarmHighPsi,
    double? pressureAlarmLowPsi,
    double? lossOfFlowValvePct,
    double? lossOfFlowFraction,
    double? lossOfFlowSeconds,
  }) {
    return SprayerConfig(
      boomWidthFt: boomWidthFt ?? this.boomWidthFt,
      sectionCount: sectionCount ?? this.sectionCount,
      sectionWidthsFt: sectionWidthsFt ?? this.sectionWidthsFt,
      targetGpa: targetGpa ?? this.targetGpa,
      designSpeedMph: designSpeedMph ?? this.designSpeedMph,
      valveMaxFlowGpm: valveMaxFlowGpm ?? this.valveMaxFlowGpm,
      valveMinPct: valveMinPct ?? this.valveMinPct,
      valveMaxPct: valveMaxPct ?? this.valveMaxPct,
      valveMaxSlewPctPerSec: valveMaxSlewPctPerSec ?? this.valveMaxSlewPctPerSec,
      kp: kp ?? this.kp,
      ki: ki ?? this.ki,
      deadbandGpm: deadbandGpm ?? this.deadbandGpm,
      maxCorrectionPctPerSec: maxCorrectionPctPerSec ?? this.maxCorrectionPctPerSec,
      flowFilterAlpha: flowFilterAlpha ?? this.flowFilterAlpha,
      gpaFilterAlpha: gpaFilterAlpha ?? this.gpaFilterAlpha,
      speedFilterAlpha: speedFilterAlpha ?? this.speedFilterAlpha,
      pressureIdlePsi: pressureIdlePsi ?? this.pressureIdlePsi,
      pressureDropPerGpm: pressureDropPerGpm ?? this.pressureDropPerGpm,
      pressureAlarmHighPsi: pressureAlarmHighPsi ?? this.pressureAlarmHighPsi,
      pressureAlarmLowPsi: pressureAlarmLowPsi ?? this.pressureAlarmLowPsi,
      lossOfFlowValvePct: lossOfFlowValvePct ?? this.lossOfFlowValvePct,
      lossOfFlowFraction: lossOfFlowFraction ?? this.lossOfFlowFraction,
      lossOfFlowSeconds: lossOfFlowSeconds ?? this.lossOfFlowSeconds,
    );
  }

  /// Equal-width sections that sum to [boomWidthFt], used when the user
  /// changes boom width or section count.
  static List<double> equalSections(double boomWidthFt, int count) {
    if (count <= 0) return const [];
    final double w = boomWidthFt / count;
    return List<double>.filled(count, w);
  }
}
