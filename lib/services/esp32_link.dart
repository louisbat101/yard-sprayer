// Conditional export: real TCP client on IO platforms (Android/desktop),
// no-op stub on web so `flutter run -d chrome` keeps working.
export 'esp32_link_stub.dart'
    if (dart.library.io) 'esp32_link_io.dart';
