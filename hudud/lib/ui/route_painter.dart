import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/geo.dart';
import '../core/territory.dart';

/// Draws a run without a base map: its claimed cells and its route, fitted
/// into the canvas. Used for history cards and share images.
class RoutePainter extends CustomPainter {
  RoutePainter({
    required this.stretches,
    required this.cells,
    required this.color,
    required this.routeStart,
    required this.routeEnd,
    this.strokeWidth = 3,
    this.padding = 12,
    this.hideNear,
    this.hideRadius = 250,
  }) : _shapes = shapesOf(cells);

  final List<List<GeoPoint>> stretches;
  final Set<int> cells;
  final Color color;
  final Color routeStart;
  final Color routeEnd;
  final double strokeWidth;
  final double padding;

  /// The privacy zone: route points this close to it are left out.
  final GeoPoint? hideNear;
  final double hideRadius;

  final List<TerritoryShape> _shapes;

  List<List<GeoPoint>> get _visibleStretches {
    final home = hideNear;
    if (home == null) return stretches;
    final out = <List<GeoPoint>>[];
    for (final s in stretches) {
      var current = <GeoPoint>[];
      for (final p in s) {
        if (haversine(p, home) < hideRadius) {
          if (current.length > 1) out.add(current);
          current = [];
        } else {
          current.add(p);
        }
      }
      if (current.length > 1) out.add(current);
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final visible = _visibleStretches;
    final points = [for (final s in visible) ...s, for (final sh in _shapes) ...sh.outer];
    if (points.isEmpty) return;
    final plane = [for (final p in points) Plane.toPlane(p)];
    var minX = plane.first.x, maxX = minX, minY = plane.first.y, maxY = minY;
    for (final v in plane) {
      minX = math.min(minX, v.x);
      maxX = math.max(maxX, v.x);
      minY = math.min(minY, v.y);
      maxY = math.max(maxY, v.y);
    }
    final w = math.max(maxX - minX, 1.0);
    final h = math.max(maxY - minY, 1.0);
    final scale = math.min((size.width - 2 * padding) / w, (size.height - 2 * padding) / h);
    final ox = (size.width - w * scale) / 2;
    final oy = (size.height - h * scale) / 2;
    Offset at(GeoPoint g) {
      final v = Plane.toPlane(g);
      // North is up, so y is flipped.
      return Offset(ox + (v.x - minX) * scale, oy + (maxY - v.y) * scale);
    }

    final home = hideNear;
    for (final s in _shapes) {
      if (home != null && s.outer.any((p) => haversine(p, home) < hideRadius)) continue;
      final path = Path()..fillType = PathFillType.evenOdd;
      for (final ring in [s.outer, ...s.holes]) {
        path.addPolygon([for (final p in ring) at(p)], true);
      }
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.28));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, strokeWidth / 2)
          ..color = color.withValues(alpha: 0.9),
      );
    }

    final bounds = Offset.zero & size;
    for (final s in visible) {
      final path = Path()..addPolygon([for (final p in s) at(p)], false);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = routeEnd.withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 1.5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = LinearGradient(colors: [routeStart, routeEnd]).createShader(bounds),
      );
    }
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.stretches != stretches || old.cells != cells || old.color != color || old.hideNear != hideNear;
}
