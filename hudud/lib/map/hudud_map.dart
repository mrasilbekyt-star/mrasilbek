import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../core/geo.dart';
import '../core/gps_filter.dart';
import '../core/territory.dart';
import 'map_data.dart';
import 'map_style.dart';

/// Widget tests cannot host the native map; they set this to draw a flat
/// preview of the same layers instead.
bool hududMapPreview = false;

/// Moves the map's camera.
class HududMapController {
  MapLibreMapController? _map;

  bool get ready => _map != null;

  /// Keeps the runner in view from behind and above, facing their way.
  Future<void> follow(GeoPoint p, {double bearing = 0, double zoom = 17, double tilt = 55}) async {
    await _map?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(p.lat, p.lon), zoom: zoom, tilt: tilt, bearing: bearing),
      ),
      duration: const Duration(milliseconds: 900),
    );
  }

  Future<void> flyTo(GeoPoint p, {double zoom = 16, double tilt = 45}) async {
    await _map?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(p.lat, p.lon), zoom: zoom, tilt: tilt)),
      duration: const Duration(milliseconds: 1200),
    );
  }

  /// Shows everything in [points], leaving [padding] free for the panels.
  Future<void> fit(Iterable<GeoPoint> points, {EdgeInsets padding = const EdgeInsets.all(48)}) async {
    final b = boundsOf(points);
    if (b == null) return;
    final (sw, ne) = b;
    if (haversine(sw, ne) < 60) {
      await flyTo(GeoPoint((sw.lat + ne.lat) / 2, (sw.lon + ne.lon) / 2), zoom: 17);
      return;
    }
    await _map?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(sw.lat, sw.lon), northeast: LatLng(ne.lat, ne.lon)),
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      ),
      duration: const Duration(milliseconds: 1200),
    );
  }
}

/// The map with the base style and every Hudud layer.
///
/// Data is handed over as plain values with a version number each; a
/// source is sent to the map only when its version changes.
class HududMap extends StatefulWidget {
  const HududMap({
    super.key,
    required this.theme,
    required this.center,
    this.zoom = 15.5,
    this.tilt = 45,
    this.controller,
    this.territory = const [],
    this.territoryVersion = 0,
    this.color = const Color(0xFF3DFFA2),
    this.runCells = const {},
    this.runCellsVersion = 0,
    this.route = const [],
    this.routeVersion = 0,
    this.hintFrom,
    this.hintTo,
    this.me,
    this.interactive = true,
    this.ornamentInsets = EdgeInsets.zero,
    this.onReady,
  });

  final MapTheme theme;
  final GeoPoint center;
  final double zoom;
  final double tilt;
  final HududMapController? controller;
  final List<TerritoryShape> territory;
  final int territoryVersion;
  final Color color;
  final Set<int> runCells;
  final int runCellsVersion;
  final List<List<GeoPoint>> route;
  final int routeVersion;
  final GeoPoint? hintFrom;
  final GeoPoint? hintTo;
  final Fix? me;
  final bool interactive;

  /// Space covered by the app's panels, kept clear of the compass and the
  /// attribution button.
  final EdgeInsets ornamentInsets;

  /// Called once the style and the Hudud layers are on screen.
  final VoidCallback? onReady;

  @override
  State<HududMap> createState() => _HududMapState();
}

class _HududMapState extends State<HududMap> {
  static final Map<String, String> _styles = {};

  MapLibreMapController? _map;
  bool _styleReady = false;
  int _sentTerritory = -1;
  int _sentRunCells = -1;
  int _sentRoute = -1;
  Color? _sentColor;

  String get _style => _styles.putIfAbsent(widget.theme.id, () => styleJson(widget.theme));

  @override
  void didUpdateWidget(HududMap old) {
    super.didUpdateWidget(old);
    if (old.theme.id != widget.theme.id) {
      // The map reloads the style; everything is sent again once it is in.
      _styleReady = false;
      _sentTerritory = _sentRunCells = _sentRoute = -1;
      return;
    }
    unawaited(_push());
  }

  Future<void> _onStyleLoaded() async {
    _styleReady = true;
    _sentTerritory = _sentRunCells = _sentRoute = -1;
    await _push();
    widget.onReady?.call();
  }

  @override
  void initState() {
    super.initState();
    if (hududMapPreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onReady?.call());
    }
  }

  Future<void> _push() async {
    final map = _map;
    if (map == null || !_styleReady) return;
    final w = widget;
    try {
      final recolor = _sentColor != w.color;
      if (recolor || _sentTerritory != w.territoryVersion) {
        _sentTerritory = w.territoryVersion;
        await map.setGeoJsonSource(HududSources.territory, shapesGeoJson(w.territory, w.color));
      }
      if (recolor || _sentRunCells != w.runCellsVersion) {
        _sentRunCells = w.runCellsVersion;
        await map.setGeoJsonSource(HududSources.runCells, cellsGeoJson(w.runCells, w.color));
      }
      _sentColor = w.color;
      if (_sentRoute != w.routeVersion) {
        _sentRoute = w.routeVersion;
        await map.setGeoJsonSource(HududSources.route, routeGeoJson(w.route));
      }
      await map.setGeoJsonSource(HududSources.hint, hintGeoJson(w.hintFrom, w.hintTo));
      await map.setGeoJsonSource(HududSources.me, meGeoJson(w.me));
    } catch (e) {
      // A source update racing a style reload is harmless: the reload sends
      // everything again.
      debugPrint('Hudud map: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hududMapPreview) return _MapPreview(widget);
    final insets = widget.ornamentInsets;
    return MapLibreMap(
      styleString: _style,
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.center.lat, widget.center.lon),
        zoom: widget.zoom,
        tilt: widget.tilt,
      ),
      onMapCreated: (c) {
        _map = c;
        widget.controller?._map = c;
      },
      onStyleLoadedCallback: _onStyleLoaded,
      foregroundLoadColor: widget.theme.background,
      compassEnabled: true,
      compassViewPosition: CompassViewPosition.topRight,
      compassViewMargins: math.Point(insets.right + 12, insets.top + 12),
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      attributionButtonMargins: math.Point(insets.left + 8, insets.bottom + 8),
      attributionButtonColor: widget.theme.placeLabel,
      logoEnabled: false,
      myLocationEnabled: false,
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
      rotateGesturesEnabled: widget.interactive,
      tiltGesturesEnabled: widget.interactive,
      doubleClickZoomEnabled: widget.interactive,
    );
  }
}

/// A flat drawing of the Hudud layers around the map's center, used in
/// widget tests and screenshots where the native map cannot run.
class _MapPreview extends StatelessWidget {
  const _MapPreview(this.map);

  final HududMap map;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _PreviewPainter(map),
        size: Size.infinite,
      );
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.map);

  final HududMap map;

  @override
  void paint(Canvas canvas, Size size) {
    final t = map.theme;
    canvas.drawRect(Offset.zero & size, Paint()..color = t.background);
    // Web Mercator at the map's zoom, 512-pixel tiles like MapLibre.
    final scale = 512 * math.pow(2, map.zoom).toDouble();
    Offset project(GeoPoint p) {
      final x = (p.lon + 180) / 360 * scale;
      final s = math.sin(p.lat * math.pi / 180);
      final y = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scale;
      return Offset(x, y);
    }

    final c = project(map.center);
    Offset at(GeoPoint p) => project(p) - c + size.center(Offset.zero);

    final grid = Paint()
      ..color = t.roadMinor
      ..strokeWidth = 6;
    for (var x = -10; x <= 10; x++) {
      final dx = size.width / 2 + x * 120.0 - (c.dx % 120);
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
    }
    for (var y = -14; y <= 14; y++) {
      final dy = size.height / 2 + y * 120.0 - (c.dy % 120);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }

    void shapes(List<TerritoryShape> list, double fill) {
      for (final s in list) {
        final path = Path()..fillType = PathFillType.evenOdd;
        for (final ring in [s.outer, ...s.holes]) {
          path.addPolygon([for (final p in ring) at(p)], true);
        }
        canvas.drawPath(path, Paint()..color = map.color.withValues(alpha: fill));
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = map.color,
        );
      }
    }

    shapes(map.territory, 0.25);
    shapes(shapesOf(map.runCells), 0.45);
    for (final stretch in map.route) {
      if (stretch.length < 2) continue;
      canvas.drawPath(
        Path()..addPolygon([for (final p in stretch) at(p)], false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = LinearGradient(colors: [t.routeStart, t.routeEnd]).createShader(Offset.zero & size),
      );
    }
    final me = map.me;
    if (me != null) {
      final p = at(me.pos);
      canvas.drawCircle(p, 14, Paint()..color = t.routeEnd.withValues(alpha: 0.25));
      canvas.drawCircle(p, 10, Paint()..color = Colors.white);
      canvas.drawCircle(p, 7, Paint()..color = t.routeEnd);
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => true;
}
