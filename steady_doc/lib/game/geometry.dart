import 'dart:math' as math;
import 'dart:ui';

/// Result of projecting a point onto a segment.
class SegmentProjection {
  const SegmentProjection(this.t, this.point, this.distance);

  /// Position along the segment, 0 at the start and 1 at the end.
  final double t;
  final Offset point;
  final double distance;
}

SegmentProjection projectToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  var t = len2 == 0 ? 0.0 : ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
  t = t.clamp(0.0, 1.0);
  final q = a + ab * t;
  return SegmentProjection(t, q, (p - q).distance);
}

double distanceToSegment(Offset p, Offset a, Offset b) =>
    projectToSegment(p, a, b).distance;

/// Result of projecting a point onto a [Polyline].
class PathProjection {
  const PathProjection(this.s, this.point, this.distance);

  /// Arc length from the start of the polyline to [point].
  final double s;
  final Offset point;
  final double distance;
}

/// An open path made of straight segments, addressed by arc length.
class Polyline {
  Polyline(List<Offset> points)
      : assert(points.length >= 2),
        points = List.unmodifiable(points),
        _cum = _cumulative(points);

  final List<Offset> points;
  final List<double> _cum;

  double get length => _cum.last;
  Offset get start => points.first;
  Offset get end => points.last;

  static List<double> _cumulative(List<Offset> pts) {
    final cum = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum.last + (pts[i] - pts[i - 1]).distance);
    }
    return cum;
  }

  /// Index of the segment containing arc length [s].
  int _segmentAt(double s) {
    var lo = 0;
    var hi = _cum.length - 2;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_cum[mid] <= s) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  Offset at(double s) {
    if (s <= 0) return points.first;
    if (s >= length) return points.last;
    final i = _segmentAt(s);
    final segLen = _cum[i + 1] - _cum[i];
    final t = segLen == 0 ? 0.0 : (s - _cum[i]) / segLen;
    return Offset.lerp(points[i], points[i + 1], t)!;
  }

  /// Unit direction of travel at arc length [s].
  Offset tangentAt(double s) {
    final i = _segmentAt(s.clamp(0.0, length));
    final d = points[i + 1] - points[i];
    final len = d.distance;
    return len == 0 ? const Offset(1, 0) : d / len;
  }

  /// Unit vector perpendicular to the path at arc length [s].
  Offset normalAt(double s) {
    final t = tangentAt(s);
    return Offset(-t.dy, t.dx);
  }

  /// Nearest point on the part of the path between arc lengths [from] and [to].
  PathProjection project(Offset p, {double from = 0, double to = double.infinity}) {
    final lo = from.clamp(0.0, length);
    final hi = to.clamp(lo, length);
    PathProjection? best;
    for (var i = 0; i < points.length - 1; i++) {
      final s0 = _cum[i];
      final s1 = _cum[i + 1];
      if (s1 < lo || s0 > hi) continue;
      final a0 = math.max(s0, lo);
      final b0 = math.min(s1, hi);
      final proj = projectToSegment(p, at(a0), at(b0));
      if (best == null || proj.distance < best.distance) {
        best = PathProjection(a0 + proj.t * (b0 - a0), proj.point, proj.distance);
      }
    }
    return best ?? PathProjection(lo, at(lo), (p - at(lo)).distance);
  }

  /// The points of the path from its start up to arc length [s].
  List<Offset> pointsUntil(double s) {
    if (s <= 0) return [points.first];
    final result = <Offset>[];
    for (var i = 0; i < points.length && _cum[i] < s; i++) {
      result.add(points[i]);
    }
    result.add(at(s));
    return result;
  }
}

/// Points spaced evenly, [step] apart, along [pts].
List<Offset> resample(List<Offset> pts, double step) {
  final line = Polyline(pts);
  final n = math.max(1, (line.length / step).ceil());
  return [for (var i = 0; i <= n; i++) line.at(line.length * i / n)];
}

/// Smooth curve through [ctrl] (uniform Catmull-Rom spline).
List<Offset> catmullRom(List<Offset> ctrl, {int samplesPerSegment = 12}) {
  if (ctrl.length < 3) return List.of(ctrl);
  final p = [ctrl.first, ...ctrl, ctrl.last];
  final out = <Offset>[];
  for (var i = 1; i < p.length - 2; i++) {
    for (var j = 0; j < samplesPerSegment; j++) {
      final t = j / samplesPerSegment;
      final t2 = t * t;
      final t3 = t2 * t;
      out.add((p[i] * 2 +
              (p[i + 1] - p[i - 1]) * t +
              (p[i - 1] * 2 - p[i] * 5 + p[i + 1] * 4 - p[i + 2]) * t2 +
              (p[i] * 3 - p[i - 1] - p[i + 1] * 3 + p[i + 2]) * t3) *
          0.5);
    }
  }
  out.add(ctrl.last);
  return out;
}

Offset clampToRect(Offset p, Rect r) =>
    Offset(p.dx.clamp(r.left, r.right), p.dy.clamp(r.top, r.bottom));

double mix(double a, double b, double t) => a + (b - a) * t;
