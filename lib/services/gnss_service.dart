import 'package:flutter/services.dart';

/// Android-only GNSS satellite-count listener.
///
/// The geolocator plugin does not expose satellite counts, so the Android side
/// reports them over the 'yard_sprayer/gnss' MethodChannel. On other platforms
/// the callback is simply never invoked and the count stays at its default.
class GnssService {
  static const MethodChannel _channel = MethodChannel('yard_sprayer/gnss');

  void Function(int visible, int used)? onSatellites;

  GnssService() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onSatellites') {
        final Map<Object?, Object?>? args = call.arguments is Map
            ? call.arguments as Map<Object?, Object?>
            : null;
        final int visible = (args?['visible'] as int?) ?? 0;
        final int used = (args?['used'] as int?) ?? 0;
        onSatellites?.call(visible, used);
      }
    });
  }

  /// Tell the native side to register its GNSS status listener.
  Future<void> start() async {
    try {
      await _channel.invokeMethod('start');
    } catch (_) {
      // Non-Android or missing provider: satellite count unavailable.
    }
  }

  /// Tell the native side to release its GNSS status listener.
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {
      // ignore
    }
  }
}
