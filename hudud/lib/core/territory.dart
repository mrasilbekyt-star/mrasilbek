import 'geo.dart';
import 'hex_grid.dart';

/// One connected piece of territory, ready to draw: an outline and its holes.
class TerritoryShape {
  const TerritoryShape(this.outer, this.holes);

  final List<GeoPoint> outer;
  final List<List<GeoPoint>> holes;
}

/// Total real area of [cells], in square meters.
double areaOfCells(Iterable<int> cells) {
  var sum = 0.0;
  for (final c in cells) {
    sum += HexGrid.areaOf(c);
  }
  return sum;
}

/// Outlines of a set of cells: every edge between an owned and a free cell,
/// chained into closed loops. Outer outlines run counter-clockwise and holes
/// clockwise, because each cell's edges are walked counter-clockwise.
List<List<Vec>> outlineLoops(Set<int> cells) {
  // Each boundary corner has exactly one outgoing boundary edge: three cells
  // meet at a hex corner and any two of them share an edge, so outlines never
  // pinch at a single corner.
  final next = <int, int>{};
  for (final cell in cells) {
    final q = HexGrid.qOf(cell);
    final r = HexGrid.rOf(cell);
    for (var i = 0; i < 6; i++) {
      final d = HexGrid.directions[i];
      if (cells.contains(HexGrid.key(q + d.$1, r + d.$2))) continue;
      next[HexGrid.cornerKey(cell, i)] = HexGrid.cornerKey(cell, (i + 1) % 6);
    }
  }
  final loops = <List<Vec>>[];
  final visited = <int>{};
  for (final start in next.keys) {
    if (visited.contains(start)) continue;
    final loop = <Vec>[];
    var corner = start;
    while (visited.add(corner)) {
      loop.add(HexGrid.cornerPositionOf(corner));
      corner = next[corner]!;
    }
    loops.add(loop);
  }
  return loops;
}

/// Groups outline loops into shapes: each hole goes to the outline around it.
List<TerritoryShape> shapesOf(Set<int> cells) {
  final outers = <List<Vec>>[];
  final holes = <List<Vec>>[];
  for (final loop in outlineLoops(cells)) {
    (signedArea(loop) > 0 ? outers : holes).add(loop);
  }
  final holesOf = List.generate(outers.length, (_) => <List<Vec>>[]);
  for (final hole in holes) {
    var best = -1;
    var bestArea = double.infinity;
    for (var i = 0; i < outers.length; i++) {
      final area = signedArea(outers[i]);
      if (area < bestArea && pointInPolygon(outers[i], hole.first)) {
        best = i;
        bestArea = area;
      }
    }
    if (best >= 0) holesOf[best].add(hole);
  }
  List<GeoPoint> geo(List<Vec> loop) => [for (final v in loop) Plane.toGeo(v)];
  return [
    for (var i = 0; i < outers.length; i++)
      TerritoryShape(geo(outers[i]), [for (final h in holesOf[i]) geo(h)]),
  ];
}

/// The player's land: every cell they have claimed.
class Territory {
  Territory([Iterable<int> cells = const []]) : _cells = {...cells};

  final Set<int> _cells;
  double? _area;
  List<TerritoryShape>? _shapes;

  Set<int> get cells => _cells;
  int get length => _cells.length;
  bool contains(int cell) => _cells.contains(cell);

  double get area => _area ??= areaOfCells(_cells);

  List<TerritoryShape> get shapes => _shapes ??= shapesOf(_cells);

  /// Adds [cells] and returns the ones that were not owned yet.
  List<int> claim(Iterable<int> cells) {
    final fresh = [for (final c in cells) if (_cells.add(c)) c];
    if (fresh.isNotEmpty) {
      _area = null;
      _shapes = null;
    }
    return fresh;
  }
}
