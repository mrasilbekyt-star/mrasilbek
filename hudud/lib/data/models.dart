import '../core/geo.dart';

/// One saved run, without its route (that lives in its own file).
class RunRecord {
  const RunRecord({
    required this.id,
    required this.start,
    required this.end,
    required this.movingSeconds,
    required this.distance,
    required this.newArea,
    required this.newCells,
    required this.loops,
    required this.biggestLoop,
    required this.splits,
    required this.calories,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final int movingSeconds;

  /// Meters.
  final double distance;

  /// Square meters of land this run added to the territory.
  final double newArea;
  final int newCells;
  final int loops;

  /// Square meters of the largest loop.
  final double biggestLoop;

  /// Seconds for each full kilometer.
  final List<int> splits;
  final double calories;

  /// Seconds per kilometer, or null for very short runs.
  double? get pace => distance < 100 ? null : movingSeconds / (distance / 1000);

  Map<String, Object?> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'sec': movingSeconds,
        'dist': distance,
        'area': newArea,
        'cells': newCells,
        'loops': loops,
        'bigLoop': biggestLoop,
        'splits': splits,
        'kcal': calories,
      };

  factory RunRecord.fromJson(Map<String, Object?> j) => RunRecord(
        id: j['id']! as String,
        start: DateTime.parse(j['start']! as String),
        end: DateTime.parse(j['end']! as String),
        movingSeconds: (j['sec']! as num).toInt(),
        distance: (j['dist']! as num).toDouble(),
        newArea: (j['area']! as num).toDouble(),
        newCells: (j['cells']! as num).toInt(),
        loops: (j['loops']! as num).toInt(),
        biggestLoop: (j['bigLoop'] as num? ?? 0).toDouble(),
        splits: [for (final s in j['splits']! as List) (s as num).toInt()],
        calories: (j['kcal'] as num? ?? 0).toDouble(),
      );
}

/// A point of a saved route.
class RoutePoint {
  const RoutePoint(this.pos, this.seconds, {this.startsStretch = false});

  final GeoPoint pos;

  /// Seconds since the run started.
  final double seconds;

  /// True for the first point after a pause or a too-fast stretch: the line
  /// is not drawn from the previous point to this one.
  final bool startsStretch;
}

/// The route of a run and every cell it claimed.
class RunRoute {
  const RunRoute(this.points, this.cells);

  final List<RoutePoint> points;
  final List<int> cells;

  /// The route split where it was interrupted, for drawing.
  List<List<GeoPoint>> get stretches {
    final out = <List<GeoPoint>>[];
    for (final p in points) {
      if (out.isEmpty || p.startsStretch) out.add([]);
      out.last.add(p.pos);
    }
    return out;
  }

  // Coordinates are stored as integer microdegrees and tenths of a second.
  Map<String, Object?> toJson() => {
        'pts': [
          for (final p in points)
            [
              (p.pos.lat * 1e6).round(),
              (p.pos.lon * 1e6).round(),
              (p.seconds * 10).round(),
              if (p.startsStretch) 1,
            ],
        ],
        'cells': cells,
      };

  factory RunRoute.fromJson(Map<String, Object?> j) => RunRoute(
        [
          for (final raw in j['pts']! as List)
            RoutePoint(
              GeoPoint(((raw as List)[0] as num) / 1e6, (raw[1] as num) / 1e6),
              (raw[2] as num) / 10,
              startsStretch: raw.length > 3,
            ),
        ],
        [for (final c in j['cells']! as List) (c as num).toInt()],
      );
}
