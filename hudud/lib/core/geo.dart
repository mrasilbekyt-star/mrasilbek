import 'dart:math' as math;

/// A point on the ground, in degrees.
class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoPoint(${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)})';
}

/// A point on the flat working plane, in meters.
class Vec {
  const Vec(this.x, this.y);

  static const zero = Vec(0, 0);

  final double x;
  final double y;

  Vec operator +(Vec o) => Vec(x + o.x, y + o.y);
  Vec operator -(Vec o) => Vec(x - o.x, y - o.y);
  Vec operator *(double k) => Vec(x * k, y * k);

  double get length => math.sqrt(x * x + y * y);
  double dot(Vec o) => x * o.x + y * o.y;
  double cross(Vec o) => x * o.y - y * o.x;
  double distanceTo(Vec o) => (this - o).length;

  @override
  bool operator ==(Object other) => other is Vec && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

const double earthRadius = 6371008.8;

/// The plane every territory lives on: an equirectangular projection scaled
/// for Uzbekistan's latitude, so a cell has the same id on every phone.
///
/// East-west distances drift a few percent away from 41.3°N; real areas are
/// corrected with [areaScaleAt].
abstract final class Plane {
  static const double referenceLat = 41.3;
  static final double _cosRef = math.cos(referenceLat * math.pi / 180);

  static Vec toPlane(GeoPoint p) => Vec(
        earthRadius * p.lon * math.pi / 180 * _cosRef,
        earthRadius * p.lat * math.pi / 180,
      );

  static GeoPoint toGeo(Vec v) => GeoPoint(
        v.y / earthRadius * 180 / math.pi,
        v.x / (earthRadius * _cosRef) * 180 / math.pi,
      );

  /// Real square meters per plane square meter at [lat].
  static double areaScaleAt(double lat) => math.cos(lat * math.pi / 180) / _cosRef;
}

/// Great-circle distance in meters.
double haversine(GeoPoint a, GeoPoint b) {
  const rad = math.pi / 180;
  final dLat = (b.lat - a.lat) * rad;
  final dLon = (b.lon - a.lon) * rad;
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(a.lat * rad) * math.cos(b.lat * rad) * math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
}

/// Whether [p] is inside the closed [polygon] (even-odd rule).
bool pointInPolygon(List<Vec> polygon, Vec p) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// Signed area of a closed polygon; positive when counter-clockwise.
///
/// Measured from the first corner, because plane coordinates are millions of
/// meters and multiplying them directly loses the small area in rounding.
double signedArea(List<Vec> polygon) {
  if (polygon.length < 3) return 0;
  final o = polygon.first;
  var sum = 0.0;
  for (var i = 1; i < polygon.length - 1; i++) {
    sum += (polygon[i] - o).cross(polygon[i + 1] - o);
  }
  return sum / 2;
}

/// Length of the closed outline of [polygon].
double perimeter(List<Vec> polygon) {
  var sum = 0.0;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    sum += polygon[j].distanceTo(polygon[i]);
  }
  return sum;
}

/// Where segments ab and cd cross, or null when they do not.
Vec? segmentIntersection(Vec a, Vec b, Vec c, Vec d) {
  final r = b - a;
  final s = d - c;
  final denom = r.cross(s);
  if (denom.abs() < 1e-12) return null;
  final t = (c - a).cross(s) / denom;
  final u = (c - a).cross(r) / denom;
  if (t < 0 || t > 1 || u < 0 || u > 1) return null;
  return a + r * t;
}

double distanceToSegment(Vec p, Vec a, Vec b) {
  final ab = b - a;
  final len2 = ab.dot(ab);
  final t = len2 == 0 ? 0.0 : ((p - a).dot(ab) / len2).clamp(0.0, 1.0);
  return p.distanceTo(a + ab * t);
}

/// Douglas-Peucker simplification, keeping the first and last points.
List<T> simplify<T>(List<T> points, Vec Function(T) at, double tolerance) {
  if (points.length < 3) return List.of(points);
  final keep = List<bool>.filled(points.length, false)
    ..[0] = true
    ..[points.length - 1] = true;
  final stack = <(int, int)>[(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (first, last) = stack.removeLast();
    var maxDist = 0.0;
    var index = -1;
    final a = at(points[first]);
    final b = at(points[last]);
    for (var i = first + 1; i < last; i++) {
      final d = distanceToSegment(at(points[i]), a, b);
      if (d > maxDist) {
        maxDist = d;
        index = i;
      }
    }
    if (index > 0 && maxDist > tolerance) {
      keep[index] = true;
      stack
        ..add((first, index))
        ..add((index, last));
    }
  }
  return [for (var i = 0; i < points.length; i++) if (keep[i]) points[i]];
}
