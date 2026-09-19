import 'dart:async';
import 'dart:io';

/// TCP link to the ESP32 over its WiFi hotspot (Access Point).
///
/// The ESP32 hosts `YardSprayer` at 192.168.4.1:8266 and speaks a
/// newline-delimited text protocol:
///   PING / SPRAY_ON / SPRAY_OFF / SECTION_L_ON / SECTION_L_OFF /
///   SECTION_R_ON / SECTION_R_OFF / `TARGET_GPA:<n>` / `SPEED:<mph>` /
///   `SATS:<n>` / STATUS
class Esp32Link {
  final String host;
  final int port;

  Socket? _socket;
  bool _connected = false;
  bool _connecting = false;

  bool get connected => _connected;

  Esp32Link({this.host = '192.168.4.1', this.port = 8266});

  /// Connect to the ESP32. Safe to call repeatedly; overlapping attempts are
  /// ignored so the socket state can't flap.
  Future<void> connect() async {
    if (_connecting || _connected) return;
    _connecting = true;
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 4),
      );
      _socket = socket;
      _connected = true;
      socket.listen(
        (_) {
          // Incoming acks/telemetry ignored for now; parse later if needed.
        },
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
      );
    } catch (_) {
      _connected = false;
      _socket = null;
    } finally {
      _connecting = false;
    }
  }

  void _onDisconnected() {
    _connected = false;
    _connecting = false;
    _socket?.destroy();
    _socket = null;
  }

  /// Send a newline-terminated command (no-op if not connected).
  void send(String command) {
    final socket = _socket;
    if (socket != null && _connected) {
      try {
        socket.write('$command\n');
      } catch (_) {
        _onDisconnected();
      }
    }
  }

  void disconnect() {
    _connected = false;
    _connecting = false;
    _socket?.destroy();
    _socket = null;
  }
}
