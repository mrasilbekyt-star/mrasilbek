import 'geo.dart';

/// One reading from the GPS.
class Fix {
  const Fix(this.pos, {required this.time, this.accuracy = 5});

  final GeoPoint pos;
  final DateTime time;

  /// Horizontal accuracy in meters (68% radius).
  final double accuracy;
}

enum Verdict {
  /// A good point; [FilterResult.meters] were run since the last one.
  accepted,

  /// The first point, or the first after a break: nothing was run yet.
  started,

  /// Too inaccurate, too close to the last point, or a single GPS jump.
  ignored,

  /// Faster than any runner (a car, a bus, a bike): the path breaks here.
  tooFast,
}

class FilterResult {
  const FilterResult(this.verdict, [this.meters = 0, this.seconds = 0]);

  final Verdict verdict;
  final double meters;
  final double seconds;

  bool get counts => verdict == Verdict.accepted;
}

/// Cleans the raw GPS stream before it reaches the map and the territory.
class GpsFilter {
  GpsFilter({
    this.maxAccuracy = 25,
    this.minStep = 3,
    this.maxRunSpeed = 7,
    this.jumpSpeed = 12,
  });

  /// Readings worse than this are dropped.
  final double maxAccuracy;

  /// Readings closer than this to the last point are GPS jitter.
  final double minStep;

  /// Meters per second; 7 m/s is 25 km/h, faster than any sustained run.
  final double maxRunSpeed;

  /// A lone reading implying more than this is a GPS jump and is skipped.
  final double jumpSpeed;

  Fix? _last;
  int _jumps = 0;

  Fix? get last => _last;

  /// Starts over, e.g. after a pause, so no segment bridges the gap.
  void reset() {
    _last = null;
    _jumps = 0;
  }

  FilterResult add(Fix fix) {
    if (fix.accuracy > maxAccuracy) return const FilterResult(Verdict.ignored);
    final last = _last;
    if (last == null) {
      _last = fix;
      return const FilterResult(Verdict.started);
    }
    final seconds = fix.time.difference(last.time).inMilliseconds / 1000;
    if (seconds <= 0) return const FilterResult(Verdict.ignored);
    final meters = haversine(last.pos, fix.pos);
    if (meters < minStep) return const FilterResult(Verdict.ignored);
    final speed = meters / seconds;
    if (speed > jumpSpeed) {
      // One wild reading is a GPS jump; several in a row mean we really moved.
      if (++_jumps < 3) return const FilterResult(Verdict.ignored);
      _jumps = 0;
      _last = fix;
      return const FilterResult(Verdict.tooFast);
    }
    _jumps = 0;
    _last = fix;
    if (speed > maxRunSpeed) return const FilterResult(Verdict.tooFast);
    return FilterResult(Verdict.accepted, meters, seconds);
  }
}
