import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/guidance.dart';
import '../state/sprayer_view_model.dart';
import 'theme.dart';

/// A-B guidance screen: record A, drive, record B, then follow the line on a
/// live map with cross-track error, heading and pass number.
class GuidanceScreen extends StatefulWidget {
  final SprayerViewModel vm;

  const GuidanceScreen({super.key, required this.vm});

  @override
  State<GuidanceScreen> createState() => _GuidanceScreenState();
}

class _GuidanceScreenState extends State<GuidanceScreen> {
  final AbLine _line = AbLine();

  /// Recorded (lat, lon) trail while spraying, drawn as the green applied swath.
  final List<(double, double)> _trail = [];
  double? _originLat;
  double? _originLon;

  /// When true (default) the applied pass is recorded while spraying.
  bool _recording = true;

  /// Manual zoom multiplier applied on top of the auto-fit scale.
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    widget.vm.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.vm.removeListener(_onTick);
    super.dispose();
  }

  /// Called every engine tick: record a trail point when spraying and moving.
  void _onTick() {
    final e = widget.vm.engine;
    if (!_recording || !e.sprayOn || e.speedMph < 0.1) return;
    final lat = e.currentLat;
    final lon = e.currentLon;
    if (_trail.isEmpty ||
        _distM(lat, lon, _trail.last.$1, _trail.last.$2) > 1.0) {
      _trail.add((lat, lon));
      if (_trail.length > 4000) _trail.removeAt(0);
    }
  }

  double _distM(double lat1, double lon1, double lat2, double lon2) {
    final dy = (lat2 - lat1) * 111320.0;
    final dx = (lon2 - lon1) * 111320.0 * math.cos(lat1 * math.pi / 180.0);
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Stable local projection: anchored at A once set, else at the first position.
  MapPoint _proj(double lat, double lon) {
    if (_line.hasA) return _line.project(lat, lon);
    _originLat ??= lat;
    _originLon ??= lon;
    final x =
        (lon - _originLon!) *
        111320.0 *
        math.cos(_originLat! * math.pi / 180.0);
    final y = (lat - _originLat!) * 111320.0;
    return MapPoint(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        final e = widget.vm.engine;
        final double lat = e.currentLat;
        final double lon = e.currentLon;
        final double hdg = e.currentHeadingDeg;

        final double cross = _line.crossTrackFt(lat, lon);
        final int pass = _line.passNumber(lat, lon, e.config.boomWidthFt);
        final double lineHdg = _line.headingDeg();

        final MapPoint? aLocal = _line.hasA
            ? _proj(_line.pointA!.$1, _line.pointA!.$2)
            : null;
        final MapPoint? bLocal = _line.bLocal;
        final MapPoint vehLocal = _proj(lat, lon);
        final List<MapPoint> trailLocal = [
          for (final p in _trail) _proj(p.$1, p.$2),
        ];

        // Combined SET A / SET B / RESET button.
        final String abLabel;
        final Color abColor;
        final VoidCallback abAction;
        if (!_line.hasA) {
          abLabel = 'SET A';
          abColor = AppTheme.accent;
          abAction = () {
            _line.setA(e.currentLat, e.currentLon);
            widget.vm.refresh();
          };
        } else if (!_line.isValid) {
          abLabel = 'SET B';
          abColor = AppTheme.amber;
          abAction = () {
            _line.setB(e.currentLat, e.currentLon);
            widget.vm.refresh();
          };
        } else {
          abLabel = 'RESET';
          abColor = AppTheme.textDim;
          abAction = () {
            _line.reset();
            widget.vm.refresh();
          };
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'GUIDANCE',
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    _statusChip(_line),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _cell(
                      'SPRAY',
                      e.sprayOn ? 'ON' : 'OFF',
                      '',
                      e.sprayOn ? AppTheme.accent : AppTheme.textDim,
                      onTap: () {
                        e.setSprayOn(!e.sprayOn);
                        widget.vm.refresh();
                      },
                    ),
                    _cell(
                      'SATS',
                      e.satelliteCount.toString(),
                      '',
                      AppTheme.amber,
                    ),
                    _cell(
                      'SPD',
                      e.speedMph.toStringAsFixed(1),
                      'MPH',
                      AppTheme.text,
                    ),
                    _cell(
                      'XTRACK',
                      cross.abs().toStringAsFixed(1),
                      cross.abs() < 0.5
                          ? 'ON LINE'
                          : (cross > 0 ? 'RIGHT' : 'LEFT'),
                      AppTheme.text,
                    ),
                    _cell('HDG', hdg.round().toString(), '°', AppTheme.text),
                    _cell(
                      'LINE',
                      lineHdg.round().toString(),
                      '°',
                      AppTheme.text,
                    ),
                    _cell('PASS', pass.toString(), '', AppTheme.text),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CustomPaint(
                            painter: _GuidancePainter(
                              a: aLocal,
                              b: bLocal,
                              vehicle: vehLocal,
                              headingDeg: hdg,
                              trail: trailLocal,
                              swathWidthM: e.config.boomWidthFt * 0.3048,
                              zoom: _zoom,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 96,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _button(abLabel, abColor, abAction),
                            const SizedBox(height: 6),
                            _button(
                              'CLEAR',
                              AppTheme.textDim,
                              _line.hasA || _trail.isNotEmpty
                                  ? () {
                                      _line.reset();
                                      _trail.clear();
                                      _originLat = null;
                                      _originLon = null;
                                      widget.vm.refresh();
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            _button(
                              _recording ? 'REC ON' : 'REC OFF',
                              _recording ? AppTheme.blue : AppTheme.textDim,
                              () => setState(() => _recording = !_recording),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _zoomButton(
                                    '−',
                                    () => setState(
                                      () => _zoom = math.max(0.5, _zoom / 1.4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _zoomButton(
                                    '+',
                                    () => setState(
                                      () => _zoom = math.min(8.0, _zoom * 1.4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _line.isValid
                      ? 'Line length ${_line.lengthFt().toStringAsFixed(0)} ft'
                      : (_line.hasA
                            ? 'Point A set — drive forward, then SET B'
                            : 'Press SET A at your start point'),
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(AbLine line) {
    final String label;
    final Color color;
    if (line.isValid) {
      label = 'LINE READY';
      color = AppTheme.accent;
    } else if (line.hasA) {
      label = 'A SET';
      color = AppTheme.amber;
    } else {
      label = 'NO LINE';
      color = AppTheme.textDim;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _cell(
    String label,
    String value,
    String sub,
    Color color, {
    VoidCallback? onTap,
  }) {
    final Widget box = Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: onTap != null ? color.withValues(alpha: 0.12) : AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: onTap != null ? color.withValues(alpha: 0.7) : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textDim,
              fontSize: 8,
              letterSpacing: 0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              style: const TextStyle(color: AppTheme.textDim, fontSize: 7),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
    return Expanded(
      child: onTap == null ? box : GestureDetector(onTap: onTap, child: box),
    );
  }

  Widget _button(String label, Color color, VoidCallback? onTap) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? color : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: enabled ? color : AppTheme.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: enabled ? Colors.black : AppTheme.textDim,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _zoomButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Paints the A-B line, the vehicle arrow, and the cross-track error line on a
/// locally-projected metre grid.
class _GuidancePainter extends CustomPainter {
  final MapPoint? a;
  final MapPoint? b;
  final MapPoint vehicle;
  final double headingDeg;
  final List<MapPoint> trail;
  final double swathWidthM;
  final double zoom;

  _GuidancePainter({
    required this.a,
    required this.b,
    required this.vehicle,
    required this.headingDeg,
    required this.trail,
    required this.swathWidthM,
    required this.zoom,
  });

  // Light-map palette (readable in direct sunlight).
  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _gridLine = Color(0xFFD8DFDC);
  static const Color _ink = Color(0xFF263238);
  static const Color _lineYellow = Color(0xFFF9A825);
  static const Color _nextBlue = Color(0xFF1E88E5);
  static const Color _crossRed = Color(0xFFD32F2F);
  static const Color _vehicleGreen = Color(0xFF2E7D32);

  @override
  void paint(Canvas canvas, Size size) {
    // Background (the map canvas itself; nothing opaque is painted on top).
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);

    // Course-up view: once the A-B line exists, rotate so it runs vertical.
    final double lineHeadingDeg = b != null
        ? math.atan2(b!.x, b!.y) * 180.0 / math.pi
        : 0.0;
    final double rotRad = -lineHeadingDeg * math.pi / 180.0;
    final double cosR = math.cos(rotRad);
    final double sinR = math.sin(rotRad);

    MapPoint rot(MapPoint p) =>
        MapPoint(p.x * cosR - p.y * sinR, p.x * sinR + p.y * cosR);

    final MapPoint rv = rot(vehicle);
    final MapPoint? ra = a != null ? rot(a!) : null;
    final MapPoint? rb = b != null ? rot(b!) : null;
    final List<MapPoint> rTrail = [for (final p in trail) rot(p)];

    // Bounds over everything to show (include the blue next-pass line).
    final List<MapPoint> pts = [
      rv,
      ?ra,
      ?rb,
      if (rb != null) MapPoint(swathWidthM, 0),
      ...rTrail,
    ];
    double minX = pts.first.x, maxX = pts.first.x;
    double minY = pts.first.y, maxY = pts.first.y;
    for (final p in pts) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }

    const double pad = 56;
    final double spanX = math.max(maxX - minX, 8.0);
    final double spanY = math.max(maxY - minY, 8.0);
    double scale = math.min(
      (size.width - 2 * pad) / spanX,
      (size.height - 2 * pad) / spanY,
    );
    scale = (scale * zoom).clamp(0.01, 400.0);
    final double midX = (minX + maxX) / 2;
    final double midY = (minY + maxY) / 2;

    Offset toScreen(MapPoint p) => Offset(
      size.width / 2 + (p.x - midX) * scale,
      size.height / 2 - (p.y - midY) * scale,
    );

    _drawGrid(canvas, size, scale, midX, midY);

    // Applied pass: green swath along the recorded (rotated) trail.
    if (rTrail.length >= 2) {
      final Path path = Path();
      final Offset p0 = toScreen(rTrail.first);
      path.moveTo(p0.dx, p0.dy);
      for (final tp in rTrail.skip(1)) {
        final Offset o = toScreen(tp);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _vehicleGreen.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(swathWidthM * scale, 3.0)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final Offset vs = toScreen(rv);

    // Guidance lines (only when the A-B line is set).
    if (rb != null) {
      final double topY = midY + (size.height / 2) / scale;
      final double bottomY = midY - (size.height / 2) / scale;

      // Yellow A-B line: full vertical (top to bottom of the screen).
      final Paint linePaint = Paint()
        ..color = _lineYellow
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        toScreen(MapPoint(0, topY)),
        toScreen(MapPoint(0, bottomY)),
        linePaint,
      );

      // Blue next-pass line (one boom width to the right).
      _drawDashed(
        canvas,
        toScreen(MapPoint(swathWidthM, topY)),
        toScreen(MapPoint(swathWidthM, bottomY)),
        _nextBlue,
      );

      // Cross-track error: perpendicular from the vehicle to the line.
      _drawDashed(canvas, vs, toScreen(MapPoint(0, rv.y)), _crossRed);
    }

    if (ra != null) _drawMarker(canvas, toScreen(ra), 'A');
    if (rb != null) _drawMarker(canvas, toScreen(rb), 'B');

    // Vehicle: halo + arrow (rotated by heading relative to the line).
    canvas.drawCircle(
      vs,
      22,
      Paint()..color = _vehicleGreen.withValues(alpha: 0.2),
    );
    canvas.save();
    canvas.translate(vs.dx, vs.dy);
    canvas.rotate(-(headingDeg - lineHeadingDeg) * math.pi / 180.0);
    final Path arrow = Path()
      ..moveTo(0, -20)
      ..lineTo(-12, 14)
      ..lineTo(12, 14)
      ..close();
    canvas.drawPath(arrow, Paint()..color = _vehicleGreen);
    canvas.restore();
    _label(canvas, 'YOU', vs + const Offset(0, 34), _ink, 12);

    // North indicator only while still north-up (no line yet).
    if (rb == null) {
      _label(canvas, 'N ↑', const Offset(20, 14), _ink, 14);
    }
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    double scale,
    double midX,
    double midY,
  ) {
    final Paint paint = Paint()
      ..color = _gridLine
      ..strokeWidth = 1;
    final double step = _niceStep(60 / scale);
    final double left = midX - (size.width / 2) / scale;
    final double right = midX + (size.width / 2) / scale;
    final double bottom = midY - (size.height / 2) / scale;
    final double top = midY + (size.height / 2) / scale;

    double x = (left / step).floor() * step;
    while (x <= right) {
      final double sx = size.width / 2 + (x - midX) * scale;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), paint);
      x += step;
    }
    double y = (bottom / step).floor() * step;
    while (y <= top) {
      final double sy = size.height / 2 - (y - midY) * scale;
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), paint);
      y += step;
    }
  }

  void _drawDashed(Canvas canvas, Offset p1, Offset p2, Color color) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const double dash = 8;
    const double gap = 6;
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final double ux = dx / dist;
    final double uy = dy / dist;
    double t = 0;
    while (t < dist) {
      final double t2 = math.min(t + dash, dist);
      canvas.drawLine(
        Offset(p1.dx + ux * t, p1.dy + uy * t),
        Offset(p1.dx + ux * t2, p1.dy + uy * t2),
        paint,
      );
      t += dash + gap;
    }
  }

  void _drawMarker(Canvas canvas, Offset p, String label) {
    canvas.drawCircle(p, 6, Paint()..color = _lineYellow);
    _label(canvas, label, Offset(p.dx, p.dy - 26), _ink, 16);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double size,
  ) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  double _niceStep(double minM) {
    const steps = [
      1.0,
      2.0,
      5.0,
      10.0,
      20.0,
      50.0,
      100.0,
      200.0,
      500.0,
      1000.0,
    ];
    for (final s in steps) {
      if (s >= minM) return s;
    }
    return 1000.0;
  }

  @override
  bool shouldRepaint(covariant _GuidancePainter oldDelegate) => true;
}
