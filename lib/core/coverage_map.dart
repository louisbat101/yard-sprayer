import 'dart:math' as math;

/// Coverage map accumulator (VERSION 2 milestone — data model, not UI).
///
/// Tracks which ground has been sprayed so a later screen can render it and a
/// job summary can report true acres covered. Cells are stored in a projected
/// metre grid; the painting/rendering layer lives in the V2 UI.
class CoverageMap {
  /// Cell size in metres (about 3.3 ft). Small enough for a 10-ft boom.
  static const double _cellM = 1.0;

  final Map<String, _CoverageCell> _cells = {};

  /// Project lat/lon onto a local metre grid anchored at the first point.
  double _originLat = 0;
  double _originLon = 0;
  bool _hasOrigin = false;

  /// Mark the strip covered by one boom pass as sprayed.
  ///
  /// [sectionStates] marks which sections were ON (index-aligned with
  /// [sectionWidthsFt]); [headingDeg] orients the boom across the track.
  void recordPass({
    required double lat,
    required double lon,
    required double headingDeg,
    required List<bool> sectionStates,
    required List<double> sectionWidthsFt,
  }) {
    if (!sectionStates.any((s) => s)) return;

    _ensureOrigin(lat, lon);
    final double x = (lon - _originLon) * 111320.0 * _cosLat(lat);
    final double y = (lat - _originLat) * 111320.0;

    // Total live width across the boom.
    double liveWidth = 0;
    for (var i = 0; i < sectionStates.length && i < sectionWidthsFt.length; i++) {
      if (sectionStates[i]) liveWidth += sectionWidthsFt[i];
    }

    // Mark a small cell at the vehicle's position (a proper V2 pass will
    // stamp a full boom rectangle; this is the minimal V1 data hook).
    final int cx = (x / _cellM).round();
    final int cy = (y / _cellM).round();
    _cells.putIfAbsent('$cx,$cy', () => _CoverageCell(liveWidth, headingDeg));
  }

  /// Number of unique sprayed cells (proxy for covered area in m²).
  int get sprayedCellCount => _cells.length;

  double get coveredAcres => sprayedCellCount * _cellM * _cellM / 4046.86;

  void _ensureOrigin(double lat, double lon) {
    if (_hasOrigin) return;
    _originLat = lat;
    _originLon = lon;
    _hasOrigin = true;
  }

  static double _cosLat(double lat) {
    final double c = math.cos(lat * math.pi / 180.0);
    return c < 0.01 ? 0.01 : c;
  }
}

class _CoverageCell {
  final double liveWidthFt;
  final double headingDeg;
  _CoverageCell(this.liveWidthFt, this.headingDeg);
}
