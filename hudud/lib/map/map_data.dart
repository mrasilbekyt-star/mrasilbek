import 'dart:math' as math;
import 'dart:ui';

import '../core/geo.dart';
import '../core/gps_filter.dart';
import '../core/territory.dart';
import 'map_style.dart';

/// GeoJSON for the Hudud sources in the map style. Coordinates are
/// [longitude, latitude], and every ring is closed.

typedef Json = Map<String, dynamic>;

Json featureCollection(List<Json> features) => {'type': 'FeatureCollection', 'features': features};

List<double> _coord(GeoPoint p) => [p.lon, p.lat];

List<List<double>> _ring(List<GeoPoint> ring) => [
      for (final p in ring) _coord(p),
      if (ring.isNotEmpty) _coord(ring.first),
    ];

/// Territory shapes as polygons, painted in [color].
Json shapesGeoJson(List<TerritoryShape> shapes, Color color) => featureCollection([
      for (final s in shapes)
        {
          'type': 'Feature',
          'properties': {'color': hex(color)},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [_ring(s.outer), for (final h in s.holes) _ring(h)],
          },
        },
    ]);

Json cellsGeoJson(Set<int> cells, Color color) => shapesGeoJson(shapesOf(cells), color);

/// The route, one line per uninterrupted stretch.
Json routeGeoJson(List<List<GeoPoint>> stretches) => featureCollection([
      for (final s in stretches)
        if (s.length >= 2)
          {
            'type': 'Feature',
            'properties': <String, Object>{},
            'geometry': {'type': 'LineString', 'coordinates': [for (final p in s) _coord(p)]},
          },
    ]);

/// A dotted line from the runner to the point that closes the loop.
Json hintGeoJson(GeoPoint? from, GeoPoint? to) {
  if (from == null || to == null) return featureCollection([]);
  return featureCollection([
    {
      'type': 'Feature',
      'properties': <String, Object>{},
      'geometry': {'type': 'LineString', 'coordinates': [_coord(from), _coord(to)]},
    },
    {
      'type': 'Feature',
      'properties': <String, Object>{},
      'geometry': {'type': 'Point', 'coordinates': _coord(to)},
    },
  ]);
}

/// The runner's dot. `acc22` is the accuracy circle's radius in pixels at
/// zoom 22 (MapLibre's 512-pixel tiles), which the style scales per zoom.
Json meGeoJson(Fix? fix) {
  if (fix == null) return featureCollection([]);
  final metersPerPixel22 = 40075016.686 * math.cos(fix.pos.lat * math.pi / 180) / (512 * 4194304);
  return featureCollection([
    {
      'type': 'Feature',
      'properties': {'acc22': fix.accuracy / metersPerPixel22},
      'geometry': {'type': 'Point', 'coordinates': _coord(fix.pos)},
    },
  ]);
}

/// The corners of the box around [points], or null for no points.
(GeoPoint, GeoPoint)? boundsOf(Iterable<GeoPoint> points) {
  double? s, w, n, e;
  for (final p in points) {
    s = s == null ? p.lat : math.min(s, p.lat);
    n = n == null ? p.lat : math.max(n, p.lat);
    w = w == null ? p.lon : math.min(w, p.lon);
    e = e == null ? p.lon : math.max(e, p.lon);
  }
  if (s == null) return null;
  return (GeoPoint(s, w!), GeoPoint(n!, e!));
}
