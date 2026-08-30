import 'dart:math' as math;

/// A-B line guidance (VERSION 2 milestone — math implemented, UI not wired).
///
/// Uses a local equirectangular projection so the cross-track / pass math is
/// simple and portable to the ESP32-S3. NOT RTK: expected accuracy is GPS-grade
/// (a few metres), so the UI will need to smooth positions before display.
class AbLine {
  double? _ax, _ay; // projected metres
  double? _bx, _by;

  /// Earth radius factor for equirectangular projection (metres/degree lat).
  static const double _mPerDegLat = 111320.0;

  bool get isValid => _ax != null && _bx != null;

  void reset() {
    _ax = _ay = _bx = _by = null;
  }

  void setA(double lat, double lon) {
    _ax = lon * _mPerDegLat * math.cos(lat * math.pi / 180.0);
    _ay = lat * _mPerDegLat;
  }

  void setB(double lat, double lon) {
    _bx = lon * _mPerDegLat * math.cos(lat * math.pi / 180.0);
    _by = lat * _mPerDegLat;
  }

  /// Line heading in degrees (0 = north, clockwise). 0 when not set.
  double headingDeg() {
    if (!isValid) return 0;
    final double d = math.atan2(_bx! - _ax!, _by! - _ay!) * 180.0 / math.pi;
    return (d + 360.0) % 360.0;
  }

  /// Signed cross-track distance in feet. Positive = right of the A->B line.
  double crossTrackFt(double lat, double lon) {
    if (!isValid) return 0;
    final double x = lon * _mPerDegLat * math.cos(lat * math.pi / 180.0);
    final double y = lat * _mPerDegLat;
    final double dx = _bx! - _ax!;
    final double dy = _by! - _ay!;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return 0;
    // Cross product / length gives signed perpendicular distance in metres.
    final double cross = dx * (y - _ay!) - dy * (x - _ax!);
    return cross / len * 3.28084; // metres -> feet
  }

  /// Pass number relative to the A-B line. Pass 1 is the first pass on the
  /// right of the line (offset by half the implement width); to the left of
  /// the line the pass number is negative.
  int passNumber(double lat, double lon, double implementWidthFt) {
    final double cross = crossTrackFt(lat, lon);
    final double half = implementWidthFt / 2.0;
    if (cross >= -half && cross <= half) return 0; // overlapping the base line
    return ((cross - half) / implementWidthFt).round() + 1;
  }
}
