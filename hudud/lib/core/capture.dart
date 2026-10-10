import 'geo.dart';
import 'hex_grid.dart';

/// A closed loop of the run and the cells inside it.
class Loop {
  const Loop(this.polygon, this.cells, this.area);

  final List<Vec> polygon;

  /// Cells inside the loop that this run had not claimed yet.
  final List<int> cells;

  /// Real area of the whole loop, in square meters.
  final double area;
}

/// What one new point claimed: cells under the path, and maybe a whole loop.
class CaptureStep {
  const CaptureStep(this.trail, [this.loop]);

  final List<int> trail;
  final Loop? loop;

  static const none = CaptureStep([]);
}

/// Turns the run's path into territory.
///
/// Every cell the runner passes through is claimed. When the path closes on
/// itself (it crosses an earlier part, or comes back near one), everything
/// inside that loop is claimed too: run around your block and it is yours.
class CaptureTracker {
  CaptureTracker({
    this.minLoopLength = 120,
    this.closeDistance = 20,
    this.minLoopArea = 400,
    this.minLoopWidth = 20,
  });

  /// A loop must be at least this long, and this far from the last loop.
  final double minLoopLength;

  /// Coming back this close to an earlier point closes a loop.
  final double closeDistance;

  /// Smaller loops claim nothing extra.
  final double minLoopArea;

  /// Average width (2 · area / perimeter) a loop needs: running out along one
  /// side of a street and back along the other is not a loop.
  final double minLoopWidth;

  final List<Vec> _path = [];
  final List<double> _along = [];
  double _lastLoopAt = 0;

  /// Every cell this run has claimed.
  final Set<int> cells = {};

  final List<Loop> loops = [];

  List<Vec> get path => List.unmodifiable(_path);

  /// Ends the current stretch: the next point starts a new one, and no loop
  /// joins across the gap (a pause, or a ride in a car).
  void breakPath() {
    _path.clear();
    _along.clear();
    _lastLoopAt = 0;
  }

  CaptureStep add(Vec p) {
    if (_path.isEmpty) {
      _path.add(p);
      _along.add(0);
      final cell = HexGrid.cellAt(p);
      return CaptureStep(cells.add(cell) ? [cell] : const []);
    }
    final prev = _path.last;
    final trail = [for (final c in HexGrid.cellsAlong(prev, p)) if (cells.add(c)) c];
    _path.add(p);
    _along.add(_along.last + prev.distanceTo(p));
    final loop = _closeLoop();
    if (loop != null) {
      loops.add(loop);
      _lastLoopAt = _along.last;
      cells.addAll(loop.cells);
    }
    return CaptureStep(trail, loop);
  }

  Loop? _closeLoop() {
    final n = _path.length - 1;
    if (_along[n] - _lastLoopAt < minLoopLength) return null;
    return _crossingLoop(n) ?? _returnLoop(n);
  }

  /// The newest segment crosses an older one: the loop is everything between.
  Loop? _crossingLoop(int n) {
    final a = _path[n - 1];
    final b = _path[n];
    for (var i = 0; i < n - 2; i++) {
      final hit = segmentIntersection(_path[i], _path[i + 1], a, b);
      if (hit == null) continue;
      final length = _along[n - 1] - _along[i + 1] + hit.distanceTo(_path[i + 1]) + hit.distanceTo(a);
      if (length < minLoopLength) continue;
      final loop = _loopOf([hit, ..._path.sublist(i + 1, n)]);
      if (loop != null) return loop;
    }
    return null;
  }

  /// The runner came back near an earlier point without crossing the path.
  Loop? _returnLoop(int n) {
    final p = _path[n];
    for (var i = 0; i < n; i++) {
      if (_along[n] - _along[i] < minLoopLength) break;
      if (_path[i].distanceTo(p) > closeDistance) continue;
      final loop = _loopOf(_path.sublist(i, n + 1));
      if (loop != null) return loop;
    }
    return null;
  }

  Loop? _loopOf(List<Vec> polygon) {
    final planeArea = signedArea(polygon).abs();
    if (planeArea < minLoopArea || 2 * planeArea / perimeter(polygon) < minLoopWidth) return null;
    final shape = simplify<Vec>(polygon, (v) => v, 1.5);
    final inside = HexGrid.cellsInside(shape) ?? const <int>[];
    final fresh = [for (final c in inside) if (!cells.contains(c)) c];
    var area = 0.0;
    for (final c in inside) {
      area += HexGrid.areaOf(c);
    }
    return Loop(shape, fresh, area);
  }

  /// The nearest earlier point that would close a loop, and how far it is,
  /// or null when no loop is in reach yet. Shown as "close the loop: 35 m".
  (double, Vec)? closeHint() {
    final n = _path.length - 1;
    if (n < 1 || _along[n] - _lastLoopAt < minLoopLength) return null;
    final p = _path[n];
    (double, Vec)? best;
    for (var i = 0; i < n; i++) {
      if (_along[n] - _along[i] < minLoopLength) break;
      final d = _path[i].distanceTo(p);
      if (best == null || d < best.$1) best = (d, _path[i]);
    }
    return best;
  }
}
