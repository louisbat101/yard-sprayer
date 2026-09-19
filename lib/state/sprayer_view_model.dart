import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/gps_fix.dart';
import '../core/sprayer_engine.dart';
import '../services/esp32_link.dart';
import '../services/geolocator_gps_source.dart';
import '../services/gnss_service.dart';

/// Bridges the framework-free [SprayerEngine] to the Flutter UI.
///
/// Owns the 100 ms tick loop, the GPS source and the mode switches. Extends
/// [ChangeNotifier] so screens can rebuild with `ListenableBuilder`.
class SprayerViewModel extends ChangeNotifier {
  final SprayerEngine engine;
  final GeolocatorGpsSource _gps = GeolocatorGpsSource();
  final GnssService _gnss = GnssService();

  Timer? _ticker;
  StreamSubscription<GpsFix>? _gpsSub;

  final Esp32Link _link = Esp32Link();
  Timer? _linkHeartbeat;
  GpsFix? _lastFix;

  /// Whether the tablet is currently connected to the ESP32 over WiFi.
  bool get linkConnected => _link.connected;

  /// Human-readable GPS status shown on the main screen.
  String gpsMessage = 'SIM';

  /// Set when the user denied location permission or the service is off.
  bool gpsDenied = false;

  SprayerViewModel({SprayerEngine? engine})
    : engine = engine ?? SprayerEngine() {
    _gnss.onSatellites = (visible, used) {
      this.engine.satellites = used > 0 ? used : visible;
    };
  }

  /// Start the control loop. The app starts in simulation mode so the system
  /// can be exercised indoors with no GPS.
  void start() {
    _ticker ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      engine.tick(0.1);
      notifyListeners();
    });
    _startLink();
  }

  /// Connect to the ESP32 hotspot and send a heartbeat every second.
  void _startLink() {
    _linkHeartbeat ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _heartbeat();
    });
    _heartbeat();
  }

  void _heartbeat() {
    if (!_link.connected) {
      _link.connect();
      if (!_link.connected) return;
    }

    final fix = _lastFix;
    _link.send('PING');
    if (fix != null && fix.hasFix) {
      _link.send('SPEED:${fix.speedMph.toStringAsFixed(1)}');
      _link.send('SATS:${fix.satellites ?? 0}');
    } else {
      _link.send('SPEED:0.0');
      _link.send('SATS:0');
    }

    // Forward the tablet's control state so the ESP mirrors it.
    _link.send(engine.sprayOn ? 'SPRAY_ON' : 'SPRAY_OFF');
    _link.send(engine.sections.isOn(0) ? 'SECTION_L_ON' : 'SECTION_L_OFF');
    if (engine.sections.count > 1) {
      _link.send(engine.sections.isOn(1) ? 'SECTION_R_ON' : 'SECTION_R_OFF');
    }
    _link.send('TARGET_GPA:${engine.targetGpa.toStringAsFixed(1)}');
    _link.send('VALVE:${engine.valveCommandPct.toStringAsFixed(1)}');
    _link.send('GPM:${engine.actualGpm.toStringAsFixed(2)}');
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
    await _gnss.start();
    _gpsSub = _gps.fixes.listen(_onFix);
  }

  Future<void> _stopGps() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    await _gps.stop();
    await _gnss.stop();
  }

  void _onFix(GpsFix fix) {
    engine.applyGpsFix(fix);
    _lastFix = fix;
    if (fix.hasFix) {
      gpsMessage = 'GPS: FIXED ±${fix.accuracyM.toStringAsFixed(0)} m';
    }
    // The ticker notifies listeners; no need to notify on every fix.
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _gpsSub?.cancel();
    _linkHeartbeat?.cancel();
    _link.disconnect();
    _gps.dispose();
    super.dispose();
  }
}
