import 'dart:math' as math;

import 'geo.dart';

/// The hexagon grid that territory is counted in.
///
/// Cells are pointy-top hexagons with 10 m sides on the [Plane]. A cell is
/// stored as one int built from its axial coordinates (q, r), using
/// multiplication rather than bit shifts so it stays exact on the web too.
abstract final class HexGrid {
  /// Distance from a cell's center to each corner, which is also its side.
  static const double size = 10;

  static final double _sqrt3 = math.sqrt(3);

  /// Area of one cell on the plane: 3√3/2 · size².
  static final double planeCellArea = 1.5 * _sqrt3 * size * size;

  static const int _offset = 1 << 24;
  static const int _span = 1 << 25;

  static int key(int q, int r) => (q + _offset) * _span + (r + _offset);
  static int qOf(int key) => key ~/ _span - _offset;
  static int rOf(int key) => key % _span - _offset;

  /// Neighbor offsets, in the order of the edges in [corners]: neighbor i
  /// shares the edge from corner i to corner i + 1.
  static const List<(int, int)> directions = [
    (1, 0), (0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1),
  ];

  /// Corner i of a cell, in half-steps of the corner lattice (see [cornerKey]).
  static const List<(int, int)> _cornerSteps = [
    (1, -1), (1, 1), (0, 2), (-1, 1), (-1, -1), (0, -2),
  ];

  static int cellAt(Vec p) {
    final qf = (_sqrt3 / 3 * p.x - p.y / 3) / size;
    final rf = (2 / 3 * p.y) / size;
    return _round(qf, rf);
  }

  static int cellAtGeo(GeoPoint g) => cellAt(Plane.toPlane(g));

  static int _round(double qf, double rf) {
    final sf = -qf - rf;
    var q = qf.round();
    var r = rf.round();
    final s = sf.round();
    final dq = (q - qf).abs();
    final dr = (r - rf).abs();
    final ds = (s - sf).abs();
    if (dq > dr && dq > ds) {
      q = -r - s;
    } else if (dr > ds) {
      r = -q - s;
    }
    return key(q, r);
  }

  static Vec center(int key) {
    final q = qOf(key);
    final r = rOf(key);
    return Vec(size * _sqrt3 * (q + r / 2), size * 1.5 * r);
  }

  /// The six corners, counter-clockwise.
  static List<Vec> corners(int key) {
    final q = qOf(key);
    final r = rOf(key);
    return [for (final step in _cornerSteps) _cornerPosition(2 * q + r + step.$1, 3 * r + step.$2)];
  }

  static List<int> neighbors(int key) {
    final q = qOf(key);
    final r = rOf(key);
    return [for (final d in directions) HexGrid.key(q + d.$1, r + d.$2)];
  }

  /// Real area of a cell in square meters.
  static double areaOf(int key) =>
      planeCellArea * Plane.areaScaleAt(Plane.toGeo(center(key)).lat);

  // Corners sit on a lattice of half-steps: x in units of size·√3/2 and y in
  // units of size/2. Their integer coordinates give every shared corner one key.
  static const int _cornerOffset = 1 << 25;
  static const int _cornerSpan = 1 << 26;

  static int cornerKey(int key, int corner) {
    final q = qOf(key);
    final r = rOf(key);
    final step = _cornerSteps[corner];
    return (2 * q + r + step.$1 + _cornerOffset) * _cornerSpan + (3 * r + step.$2 + _cornerOffset);
  }

  static Vec cornerPositionOf(int cornerKey) => _cornerPosition(
        cornerKey ~/ _cornerSpan - _cornerOffset,
        cornerKey % _cornerSpan - _cornerOffset,
      );

  static Vec _cornerPosition(int ix, int iy) => Vec(ix * size * _sqrt3 / 2, iy * size / 2);

  /// Cells along the segment from [a] to [b], sampled every half cell.
  static Iterable<int> cellsAlong(Vec a, Vec b) sync* {
    final length = a.distanceTo(b);
    final steps = math.max(1, (length / (size / 2)).ceil());
    int? previous;
    for (var i = 0; i <= steps; i++) {
      final cell = cellAt(a + (b - a) * (i / steps));
      if (cell != previous) yield cell;
      previous = cell;
    }
  }

  /// Cells whose centers lie inside [polygon]; null when it is too large.
  static List<int>? cellsInside(List<Vec> polygon, {int maxCandidates = 400000}) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in polygon) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final rMin = (minY / (1.5 * size)).floor() - 1;
    final rMax = (maxY / (1.5 * size)).ceil() + 1;
    final width = _sqrt3 * size;
    final rows = rMax - rMin + 1;
    final cols = ((maxX - minX) / width).ceil() + 3;
    if (rows * cols > maxCandidates) return null;
    final out = <int>[];
    for (var r = rMin; r <= rMax; r++) {
      final qMin = (minX / width - r / 2).floor() - 1;
      final qMax = (maxX / width - r / 2).ceil() + 1;
      for (var q = qMin; q <= qMax; q++) {
        final k = key(q, r);
        if (pointInPolygon(polygon, center(k))) out.add(k);
      }
    }
    return out;
  }
}
