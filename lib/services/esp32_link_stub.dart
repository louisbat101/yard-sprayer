/// No-op ESP32 link for web builds (no TCP sockets available).
///
/// Matches the API of [Esp32Link] in esp32_link_io.dart so the conditional
/// export in esp32_link.dart resolves identically on every platform.
class Esp32Link {
  final String host;
  final int port;

  bool get connected => false;

  Esp32Link({this.host = '192.168.4.1', this.port = 8266});

  Future<void> connect() async {}

  void send(String command) {}

  void disconnect() {}
}
