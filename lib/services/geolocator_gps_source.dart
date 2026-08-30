import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/gps_fix.dart';
import 'gps_source.dart';

/// Real GPS via the geolocator plugin (built-in phone/tablet GPS on Android,
/// browser geolocation on web).
class GeolocatorGpsSource implements GpsSource {
  final StreamController<GpsFix> _controller = StreamController<GpsFix>.broadcast();
  StreamSubscription<Position>? _sub;

  @override
  Stream<GpsFix> get fixes => _controller.stream;

  @override
  bool get isRunning => _sub != null;

  /// Ask for permission (and check the location service is on).
  /// Returns true when the app is allowed to read the position.
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<void> start() async {
    if (_sub != null) return;
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // update every metre
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position p) {
        _controller.add(GpsFix(
          time: DateTime.now(),
          latitude: p.latitude,
          longitude: p.longitude,
          speedMps: p.speed, // m/s (0 if the receiver doesn't provide it)
          headingDeg: p.heading, // degrees; 0 when stationary
          accuracyM: p.accuracy,
          satellites: null, // geolocator does not expose satellite count
          hasFix: true,
        ));
      },
      onError: (Object _) {
        // Keep the last known fix; the UI will show a stale/still-searching
        // status rather than crashing on a transient receiver error.
      },
    );
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
