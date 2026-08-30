import 'units.dart';

/// A single GPS position/velocity sample, normalized to a framework-free
/// structure so it can cross the UI/core boundary (and map to an ESP32 port).
class GpsFix {
  final DateTime time;
  final double latitude;
  final double longitude;

  /// Ground speed in metres/second as reported by the receiver.
  final double speedMps;

  /// Course over ground in degrees (0 = north, clockwise).
  final double headingDeg;

  /// Horizontal accuracy estimate in metres (lower is better).
  final double accuracyM;

  /// Number of satellites in use, when the receiver exposes it (may be null).
  final int? satellites;

  /// Whether this sample represents a valid fix.
  final bool hasFix;

  const GpsFix({
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.speedMps,
    required this.headingDeg,
    required this.accuracyM,
    this.satellites,
    required this.hasFix,
  });

  double get speedMph => SprayMath.mpsToMph(speedMps);

  static GpsFix invalid() => GpsFix(
        time: DateTime.now(),
        latitude: 0,
        longitude: 0,
        speedMps: 0,
        headingDeg: 0,
        accuracyM: double.infinity,
        satellites: 0,
        hasFix: false,
      );
}
