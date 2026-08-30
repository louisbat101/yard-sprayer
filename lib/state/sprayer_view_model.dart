import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/gps_fix.dart';
import '../core/sprayer_engine.dart';
import '../services/geolocator_gps_source.dart';

/// Bridges the framework-free [SprayerEngine] to the Flutter UI.
///
/// Owns the 100 ms tick loop, the GPS source and the mode switches. Extends
/// [ChangeNotifier] so screens can rebuild with `ListenableBuilder`.
class SprayerViewModel extends ChangeNotifier {
  final SprayerEngine engine;
  final GeolocatorGpsSource _gps = GeolocatorGpsSource();

  Timer? _ticker;
  StreamSubscription<GpsFix>? _gpsSub;

  /// Human-readable GPS status shown on the main screen.
  String gpsMessage = 'SIM';

  /// Set when the user denied location permission or the service is off.
  bool gpsDenied = false;

  SprayerViewModel({SprayerEngine? engine}) : engine = engine ?? SprayerEngine();

  /// Start the control loop. The app starts in simulation mode so the system
  /// can be exercised indoors with no GPS.
  void start() {
    _ticker ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      engine.tick(0.1);
      notifyListeners();
    });
  }

  /// Force an immediate rebuild (used by screens after mutating the engine
  /// outside of the normal tick).
  void refresh() => notifyListeners();

  Future<void> setMode(SprayerMode mode) async {
    if (mode == SprayerMode.simulation) {
      await _stopGps();
      engine.mode = SprayerMode.simulation;
      gpsMessage = 'SIM';
      gpsDenied = false;
      notifyListeners();
      return;
    }

    // Live mode: request permission, then stream fixes.
    final bool allowed = await _gps.ensurePermission();
    if (!allowed) {
      gpsDenied = true;
      gpsMessage = 'GPS DENIED';
      engine.mode = SprayerMode.live;
      notifyListeners();
      return;
    }
    gpsDenied = false;
    engine.mode = SprayerMode.live;
    gpsMessage = 'GPS: WAITING FOR FIX';
    await _startGps();
    notifyListeners();
  }

  Future<void> _startGps() async {
    await _stopGps();
    await _gps.start();
    _gpsSub = _gps.fixes.listen(_onFix);
  }

  Future<void> _stopGps() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    await _gps.stop();
  }

  void _onFix(GpsFix fix) {
    engine.applyGpsFix(fix);
    if (fix.hasFix) {
      gpsMessage = 'GPS: FIXED ±${fix.accuracyM.toStringAsFixed(0)} m';
    }
    // The ticker notifies listeners; no need to notify on every fix.
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _gpsSub?.cancel();
    _gps.dispose();
    super.dispose();
  }
}
