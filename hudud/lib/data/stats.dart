import 'dart:math' as math;

import 'models.dart';

/// Everything the profile shows, worked out from the saved runs.
class Stats {
  Stats(List<RunRecord> runs, {required this.territoryArea, DateTime? now})
      : runs = List.unmodifiable(runs),
        now = now ?? DateTime.now() {
    for (final r in runs) {
      totalDistance += r.distance;
      totalSeconds += r.movingSeconds;
      totalLoops += r.loops;
      longestRun = math.max(longestRun, r.distance);
      biggestLoop = math.max(biggestLoop, r.biggestLoop);
      mostAreaInRun = math.max(mostAreaInRun, r.newArea);
      if (r.start.hour < 7) earlyRuns++;
      for (final s in r.splits) {
        if (fastestKm == null || s < fastestKm!) fastestKm = s;
      }
      for (var i = 0; i + 5 <= r.splits.length; i++) {
        final five = r.splits.sublist(i, i + 5).fold(0, (a, b) => a + b);
        if (fastest5k == null || five < fastest5k!) fastest5k = five;
      }
    }
    _streaks();
  }

  final List<RunRecord> runs;
  final DateTime now;

  /// Square meters owned now.
  final double territoryArea;

  double totalDistance = 0;
  int totalSeconds = 0;
  int totalLoops = 0;
  double longestRun = 0;
  double biggestLoop = 0;
  double mostAreaInRun = 0;
  int earlyRuns = 0;

  /// Seconds of the fastest full kilometer, and of the fastest five in a row.
  int? fastestKm;
  int? fastest5k;

  int currentStreak = 0;
  int bestStreak = 0;

  int get runCount => runs.length;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  void _streaks() {
    final days = {for (final r in runs) _day(r.start)}.toList()..sort();
    var run = 0;
    DateTime? prev;
    for (final d in days) {
      run = prev != null && d.difference(prev).inHours.round() == 24 ? run + 1 : 1;
      bestStreak = math.max(bestStreak, run);
      prev = d;
    }
    final today = _day(now);
    if (prev != null && today.difference(prev).inHours.round() <= 24) currentStreak = run;
  }

  /// Experience: a point per 100 m run, per 100 m² claimed and 25 per loop.
  int get xp => (totalDistance / 100 + territoryArea / 100 + totalLoops * 25).floor();

  static const rankThresholds = [0, 300, 1000, 3000, 8000, 20000, 50000];

  int get rank {
    var r = 0;
    for (var i = 0; i < rankThresholds.length; i++) {
      if (xp >= rankThresholds[i]) r = i;
    }
    return r;
  }

  /// Progress from this rank to the next, 0..1 (1 at the top rank).
  double get rankProgress {
    if (rank == rankThresholds.length - 1) return 1;
    final lo = rankThresholds[rank];
    final hi = rankThresholds[rank + 1];
    return (xp - lo) / (hi - lo);
  }

  /// Runs since Monday of this week.
  List<RunRecord> get thisWeek {
    final monday = _day(now).subtract(Duration(days: now.weekday - 1));
    return [for (final r in runs) if (!r.start.isBefore(monday)) r];
  }
}

/// A badge with a goal.
class Achievement {
  const Achievement(this.id, this.emoji, this.target, this._measure);

  final String id;
  final String emoji;
  final double target;
  final double Function(Stats) _measure;

  double value(Stats s) => _measure(s);
  bool unlocked(Stats s) => value(s) >= target;
  double progress(Stats s) => (value(s) / target).clamp(0.0, 1.0);

  static final all = <Achievement>[
    Achievement('first_run', '👟', 1, (s) => s.runCount.toDouble()),
    Achievement('first_loop', '⭕', 1, (s) => s.totalLoops.toDouble()),
    Achievement('area_1ha', '🟩', 10000, (s) => s.territoryArea),
    Achievement('km_5', '🥉', 5000, (s) => s.longestRun),
    Achievement('streak_3', '🔥', 3, (s) => s.bestStreak.toDouble()),
    Achievement('early', '🌅', 1, (s) => s.earlyRuns.toDouble()),
    Achievement('km_10', '🥈', 10000, (s) => s.longestRun),
    Achievement('big_loop', '🌀', 50000, (s) => s.biggestLoop),
    Achievement('area_10ha', '🏘️', 100000, (s) => s.territoryArea),
    Achievement('streak_7', '⚡', 7, (s) => s.bestStreak.toDouble()),
    Achievement('loops_25', '🎯', 25, (s) => s.totalLoops.toDouble()),
    Achievement('total_100', '💯', 100000, (s) => s.totalDistance),
    Achievement('half', '🥇', 21097, (s) => s.longestRun),
    Achievement('streak_30', '🏆', 30, (s) => s.bestStreak.toDouble()),
    Achievement('area_100ha', '👑', 1000000, (s) => s.territoryArea),
  ];
}

/// This week's three goals.
class Mission {
  const Mission(this.id, this.target, this._measure);

  final String id;
  final double target;
  final double Function(List<RunRecord>) _measure;

  double value(Stats s) => _measure(s.thisWeek);
  double progress(Stats s) => (value(s) / target).clamp(0.0, 1.0);
  bool done(Stats s) => value(s) >= target;

  static final weekly = <Mission>[
    Mission('week_km', 10000, (w) => w.fold(0.0, (a, r) => a + r.distance)),
    Mission('week_area', 5000, (w) => w.fold(0.0, (a, r) => a + r.newArea)),
    Mission('week_loops', 3, (w) => w.fold(0.0, (a, r) => a + r.loops)),
  ];
}
