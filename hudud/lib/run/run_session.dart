import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/capture.dart';
import '../core/geo.dart';
import '../core/gps_filter.dart';
import '../core/territory.dart';
import '../data/models.dart';
import 'location.dart';

enum RunState { ready, running, paused, finished }

/// Land claimed at one moment of the run, for the celebration on screen.
class CaptureEvent {
  const CaptureEvent(this.serial, this.area, {required this.loop});

  /// Grows with every event, so the screen can tell a new one from the last.
  final int serial;

  /// Square meters newly added to the territory.
  final double area;
  final bool loop;
}

/// A finished run, ready to be saved.
class RunResult {
  const RunResult(this.record, this.route);

  final RunRecord record;
  final RunRoute route;
}

/// One run in progress: GPS in, distance, pace and territory out.
class RunSession extends ChangeNotifier {
  RunSession({
    required this.source,
    required this.territory,
    this.weightKg = 70,
    this.demo = false,
    this.autoPause = false,
    Stream<int>? steps,
  }) : _stepsSource = steps;

  final LocationSource source;

  /// Land owned before this run. It is not changed until the run is saved.
  final Territory territory;
  final double weightKg;

  /// A pretend run: shown like a real one, never saved.
  final bool demo;

  /// Pause by itself when the runner stands still, resume when they move.
  final bool autoPause;

  final Stream<int>? _stepsSource;
  StreamSubscription<int>? _stepsSub;

  /// Steps from the phone's step counter, when it has one.
  int? get stepCount => _steps;
  int? _steps;
  final List<(double, int)> _recentSteps = [];

  bool _autoPaused = false;

  /// Paused because the runner stopped, not by the pause button.
  bool get autoPaused => _autoPaused;
  GeoPoint? _pausedAt;
  DateTime? _lastMoveAt;

  final GpsFilter _filter = GpsFilter();
  final CaptureTracker tracker = CaptureTracker();
  StreamSubscription<Fix>? _sub;

  RunState _state = RunState.ready;
  RunState get state => _state;

  DateTime? _startedAt;
  DateTime? get startedAt => _startedAt;
  DateTime? _resumedAt;
  Duration _active = Duration.zero;

  double _distance = 0;

  /// Meters run.
  double get distance => _distance;

  final List<RoutePoint> _route = [];
  List<RoutePoint> get route => List.unmodifiable(_route);
  bool _breakNext = false;

  /// Cells this run added to the territory (none of them owned before).
  final Set<int> newCells = {};
  double _newArea = 0;

  /// Square meters this run added to the territory.
  double get newArea => _newArea;

  int _loops = 0;
  int get loops => _loops;
  double _biggestLoop = 0;

  /// Seconds for each full kilometer so far.
  final List<int> splits = [];
  int _splitMark = 0;

  Fix? _lastFix;
  Fix? get lastFix => _lastFix;

  /// Times the GPS showed car speed; shown as a warning.
  int tooFastCount = 0;

  CaptureEvent? _lastCapture;
  CaptureEvent? get lastCapture => _lastCapture;
  int _captureSerial = 0;

  double? _distanceToClose;

  /// Meters to the nearest point that would close a loop, while one is near.
  double? get distanceToClose => _distanceToClose;

  /// Where the nearest closing point is.
  GeoPoint? get closeTarget => _closeTarget;
  GeoPoint? _closeTarget;

  final List<(double, double)> _recent = [];

  /// Time spent running, without pauses.
  Duration get elapsed {
    final since = _resumedAt;
    return since == null ? _active : _active + source.now().difference(since);
  }

  /// Average seconds per kilometer.
  double? get averagePace =>
      _distance < 50 ? null : elapsed.inMilliseconds / 1000 / (_distance / 1000);

  /// Seconds per kilometer over the last half minute or so.
  double? get currentPace {
    if (_recent.length < 2) return null;
    final (t0, d0) = _recent.first;
    final (t1, d1) = _recent.last;
    if (t1 - t0 < 10 || d1 - d0 < 15) return null;
    return (t1 - t0) / ((d1 - d0) / 1000);
  }

  /// Steps per minute over the last half minute.
  int? get cadence {
    if (_recentSteps.length < 2) return null;
    final (t0, s0) = _recentSteps.first;
    final (t1, s1) = _recentSteps.last;
    if (t1 - t0 < 10) return null;
    return ((s1 - s0) / (t1 - t0) * 60).round();
  }

  /// A rough estimate: about one kilocalorie per kilogram per kilometer.
  double get calories => weightKg * _distance / 1000 * 1.036;

  /// Whether a good GPS reading arrived in the last ten seconds.
  bool get gpsReady {
    final fix = _lastFix;
    if (fix == null) return false;
    return fix.accuracy <= _filter.maxAccuracy &&
        source.now().difference(fix.time) < const Duration(seconds: 10);
  }

  void start() {
    if (_state != RunState.ready) return;
    _state = RunState.running;
    _startedAt = source.now();
    _resumedAt = _startedAt;
    _lastMoveAt = _startedAt;
    _sub = source.fixes().listen(_onFix);
    _stepsSub = _stepsSource?.listen(_onSteps);
    notifyListeners();
  }

  void _onSteps(int steps) {
    _steps = steps;
    final t = elapsed.inMilliseconds / 1000;
    _recentSteps.add((t, steps));
    while (_recentSteps.length > 2 && t - _recentSteps[1].$1 >= 30) {
      _recentSteps.removeAt(0);
    }
    notifyListeners();
  }

  /// Called every second by the screen: auto-pause when standing still.
  void tick() {
    if (!autoPause || _state != RunState.running || _route.isEmpty) return;
    final last = _lastMoveAt;
    if (last != null && source.now().difference(last) > const Duration(seconds: 12)) {
      pause();
      _autoPaused = true;
      _pausedAt = _lastFix?.pos;
      notifyListeners();
    }
  }

  void pause() {
    if (_state != RunState.running) return;
    _autoPaused = false;
    _active = elapsed;
    _resumedAt = null;
    _state = RunState.paused;
    // Nothing joins across a pause: no free distance, no loop over the gap.
    _filter.reset();
    tracker.breakPath();
    _breakNext = true;
    _distanceToClose = null;
    _closeTarget = null;
    _recent.clear();
    notifyListeners();
  }

  void resume() {
    if (_state != RunState.paused) return;
    _autoPaused = false;
    _lastMoveAt = source.now();
    _resumedAt = source.now();
    _state = RunState.running;
    notifyListeners();
  }

  /// Stops the GPS and returns the run, or null if nothing was run.
  Future<RunResult?> finish() async {
    if (_state == RunState.finished) return null;
    _active = elapsed;
    _resumedAt = null;
    _state = RunState.finished;
    _stopSources();
    notifyListeners();
    final start = _startedAt;
    if (start == null || _route.isEmpty) return null;
    final record = RunRecord(
      id: start.millisecondsSinceEpoch.toString(),
      start: start,
      end: source.now(),
      movingSeconds: _active.inSeconds,
      distance: _distance,
      newArea: _newArea,
      newCells: newCells.length,
      loops: _loops,
      biggestLoop: _biggestLoop,
      splits: List.of(splits),
      calories: calories,
    );
    final points = simplify<RoutePoint>(_route, (p) => Plane.toPlane(p.pos), 1.5);
    // Simplifying may drop a stretch's first point; keep every break.
    final kept = {...points, ..._route.where((p) => p.startsStretch)};
    final route = RunRoute([for (final p in _route) if (kept.contains(p)) p], [...tracker.cells]);
    return RunResult(record, route);
  }

  /// Stops the GPS and forgets the run.
  Future<void> discard() async {
    _state = RunState.finished;
    _stopSources();
    notifyListeners();
  }

  /// Stops the GPS and the step counter. Not awaited: a generator stream
  /// only confirms its cancel at its next event, which may never come.
  void _stopSources() {
    unawaited(_sub?.cancel());
    unawaited(_stepsSub?.cancel());
    _sub = null;
    _stepsSub = null;
  }

  void _onFix(Fix fix) {
    _lastFix = fix;
    final pausedAt = _pausedAt;
    if (_state == RunState.paused && _autoPaused && pausedAt != null &&
        fix.accuracy <= _filter.maxAccuracy && haversine(pausedAt, fix.pos) > 12) {
      resume();
    }
    if (_state != RunState.running) {
      notifyListeners();
      return;
    }
    final result = _filter.add(fix);
    switch (result.verdict) {
      case Verdict.ignored:
        break;
      case Verdict.tooFast:
        tooFastCount++;
        tracker.breakPath();
        _breakNext = true;
      case Verdict.started:
        _addPoint(fix);
      case Verdict.accepted:
        _distance += result.meters;
        _lastMoveAt = source.now();
        _addPoint(fix);
        _updateSplits();
    }
    notifyListeners();
  }

  void _addPoint(Fix fix) {
    final seconds = elapsed.inMilliseconds / 1000;
    _route.add(RoutePoint(fix.pos, seconds, startsStretch: _breakNext && _route.isNotEmpty));
    _breakNext = false;
    _recent.add((seconds, _distance));
    while (_recent.length > 2 && seconds - _recent[1].$1 >= 30) {
      _recent.removeAt(0);
    }
    _claim(tracker.add(Plane.toPlane(fix.pos)));
    final hint = tracker.closeHint();
    final near = hint != null && hint.$1 <= 150;
    _distanceToClose = near ? hint.$1 : null;
    _closeTarget = near ? Plane.toGeo(hint.$2) : null;
  }

  void _claim(CaptureStep step) {
    final fresh = <int>[
      for (final c in [...step.trail, ...?step.loop?.cells])
        if (!territory.contains(c) && newCells.add(c)) c,
    ];
    final gained = areaOfCells(fresh);
    _newArea += gained;
    final loop = step.loop;
    if (loop != null) {
      _loops++;
      _biggestLoop = math.max(_biggestLoop, loop.area);
      if (gained > 0) _lastCapture = CaptureEvent(++_captureSerial, gained, loop: true);
    }
  }

  void _updateSplits() {
    final km = (_distance / 1000).floor();
    while (splits.length < km) {
      final now = elapsed.inSeconds;
      splits.add(now - _splitMark);
      _splitMark = now;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _stepsSub?.cancel();
    super.dispose();
  }
}
