import '../core/gps_fix.dart';

/// Abstraction over a GPS receiver so the engine never depends on a specific
/// platform plugin. The real app uses [GeolocatorGpsSource]; tests and the
/// simulation mode bypass this entirely.
abstract class GpsSource {
  /// Broadcast stream of position fixes.
  Stream<GpsFix> get fixes;

  /// True once the source is actively producing fixes.
  bool get isRunning;

  /// Start acquiring fixes.
  Future<void> start();

  /// Stop acquiring fixes and release the receiver.
  Future<void> stop();
}
