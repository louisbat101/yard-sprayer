import 'dart:math' as math;

/// A tiny 2-D point in a local metre grid (x = east, y = north).
class MapPoint {
  final double x;
  final double y;
  const MapPoint(this.x, this.y);
}

/// A-B line guidance.
///
/// Projects GPS positions onto a local equirectangular grid anchored at point A
/// so cross-track / pass math is simple and portable to the ESP32-S3. NOT RTK:
/// expected accuracy is GPS-grade (a few metres), so the UI smooths positions
/// before relying on the numbers for close-in steering.
class AbLine {
  double? _aLat;
  double? _aLon;
  double? _bLat;
  double? _bLon;

  /// Metres per degree of latitude (equirectangular).
  static const double _mPerDegLat = 111320.0;

  bool get hasA => _aLat != null;
  bool get isValid => _aLat != null && _bLat != null;

  /// Raw A / B positions as (lat, lon), or null when not recorded.
  (double, double)? get pointA => hasA ? (_aLat!, _aLon!) : null;
  (double, double)? get pointB => _bLat != null ? (_bLat!, _bLon!) : null;

  void reset() {
    _aLat = _aLon = _bLat = _bLon = null;
  }

  void setA(double lat, double lon) {
    _aLat = lat;
    _aLon = lon;
  }

  void setB(double lat, double lon) {
    _bLat = lat;
    _bLon = lon;
  }

  /// Project a position onto the local metre grid anchored at A (or at the
  /// position itself before A exists). x = east, y = north.
  MapPoint project(double lat, double lon) {
    final double anchorLat = _aLat ?? lat;
    final double anchorLon = _aLon ?? lon;
    final double x = (lon - anchorLon) * _mPerDegLat * _cos(anchorLat);
    final double y = (lat - anchorLat) * _mPerDegLat;
    return MapPoint(x, y);
  }

  /// Local point for B relative to A, or null until both are set.
  MapPoint? get bLocal => isValid ? project(_bLat!, _bLon!) : null;

  /// Line heading in degrees (0 = north, clockwise). 0 until A and B are set.
  double headingDeg() {
    final MapPoint? b = bLocal;
    if (b == null) return 0;
    final double d = math.atan2(b.x, b.y) * 180.0 / math.pi;
    return (d + 360.0) % 360.0;
  }

  /// Length of the A-B segment in feet.
  double lengthFt() {
    final MapPoint? b = bLocal;
    if (b == null) return 0;
    return math.sqrt(b.x * b.x + b.y * b.y) * 3.28084;
  }

  /// Signed cross-track distance in feet. Positive = right of the A->B line.
  double crossTrackFt(double lat, double lon) {
    final MapPoint? b = bLocal;
    if (b == null) return 0;
    final MapPoint p = project(lat, lon);
    final double len = math.sqrt(b.x * b.x + b.y * b.y);
    if (len == 0) return 0;
    final double cross = b.x * p.y - b.y * p.x;
    return cross / len * 3.28084;
  }

  /// Pass number relative to the A-B line. Pass 1 is the first pass to the
  /// right of the line (offset by half the implement width); left of the line
  /// the pass number is negative; 0 means overlapping the base line.
  int passNumber(double lat, double lon, double implementWidthFt) {
    final double cross = crossTrackFt(lat, lon);
    final double half = implementWidthFt / 2.0;
    if (cross >= -half && cross <= half) return 0;
    return ((cross - half) / implementWidthFt).round() + 1;
  }

  static double _cos(double lat) {
    final double c = math.cos(lat * math.pi / 180.0);
    return c < 0.01 ? 0.01 : c;
  }
}
