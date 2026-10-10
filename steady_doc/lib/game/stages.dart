import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';
import 'levels.dart';

enum StageKind { inject, xray, cut, extract, stitch }

enum MistakeKind { offLine, tooDeep, tooFast, wall, tooHard }

/// Short sounds the stages ask for.
enum Cue { found, pop, stitch }

/// One pointer reading, already converted to design units.
class PenSample {
  const PenSample(this.pos, this.time, {this.stylus = false, this.pressure = 0.5});

  final Offset pos;

  /// Seconds, from the pointer event's timestamp.
  final double time;

  /// True for the S Pen (or any stylus).
  final bool stylus;

  /// 0..1. Only meaningful when [stylus] is true.
  final double pressure;
}

/// What a stage needs from the running game.
abstract interface class StageHost {
  /// Game time in seconds.
  double get now;
  void mistake(MistakeKind kind, Offset at);
  void cue(Cue cue);
}

/// Pressure above which the S Pen cuts too deep.
const double deepPressure = 0.88;

/// Pressure above which the S Pen pushes the plunger too hard.
const double hardPressure = 0.92;

abstract class Stage {
  Stage(this.host);

  final StageHost host;

  StageKind get kind;
  bool get isComplete;

  /// 0..1, shown in the HUD.
  double get progress;

  void down(PenSample s) {}
  void move(PenSample s) {}
  void up() {}
  void hover(PenSample s) {}
  void tick(double dt) {}
}

/// Smoothed speed of a moving pointer, in design units per second.
class _Speedometer {
  Offset? _last;
  double _lastTime = 0;
  double value = 0;

  void reset() {
    _last = null;
    value = 0;
  }

  void add(Offset pos, double time) {
    final last = _last;
    if (last != null) {
      final dt = time - _lastTime;
      if (dt > 0.001) {
        final v = (pos - last).distance / dt;
        value = value * 0.6 + v * 0.4;
      }
    }
    _last = pos;
    _lastTime = time;
  }
}

/// Anesthesia: drag the syringe plunger down slowly.
class InjectStage extends Stage {
  InjectStage(super.host, {required this.speedLimit});

  final double speedLimit;
  double handleY = BodyLayout.plungerStart;
  bool grabbed = false;
  double _grabOffset = 0;
  double _lastY = 0;
  double _lastTime = 0;
  double speed = 0;

  static const double grabRadius = 85;

  Offset get handle => Offset(BodyLayout.syringeX, handleY);

  @override
  StageKind get kind => StageKind.inject;

  @override
  bool get isComplete => handleY >= BodyLayout.plungerEnd - 0.5;

  @override
  double get progress => (handleY - BodyLayout.plungerStart) /
      (BodyLayout.plungerEnd - BodyLayout.plungerStart);

  @override
  void down(PenSample s) {
    if ((s.pos - handle).distance > grabRadius) return;
    grabbed = true;
    _grabOffset = handleY - s.pos.dy;
    _lastY = handleY;
    _lastTime = s.time;
    speed = 0;
  }

  @override
  void move(PenSample s) {
    if (!grabbed || isComplete) return;
    final target = (s.pos.dy + _grabOffset)
        .clamp(handleY, BodyLayout.plungerEnd)
        .toDouble();
    final dt = s.time - _lastTime;
    if (dt > 0.001) {
      speed = speed * 0.6 + ((target - _lastY) / dt) * 0.4;
      _lastY = target;
      _lastTime = s.time;
    }
    handleY = target;
    if (speed > speedLimit) {
      host.mistake(MistakeKind.tooFast, s.pos);
    } else if (s.stylus && s.pressure > hardPressure) {
      host.mistake(MistakeKind.tooHard, s.pos);
    }
  }

  @override
  void up() {
    grabbed = false;
    speed = 0;
  }
}

/// A swallowed object, hidden until found with the X-ray.
class HiddenItem {
  HiddenItem(this.emoji, this.pos);

  final String emoji;
  final Offset pos;
  bool found = false;

  /// Seconds the lens has rested on this object.
  double dwell = 0;
}

/// X-ray: hover the S Pen (or drag a finger) over the body to find objects.
class XrayStage extends Stage {
  XrayStage(super.host, this.items);

  final List<HiddenItem> items;
  Offset? lens;
  bool _touching = false;
  double _lastHover = -1;

  static const double lensRadius = 125;
  static const double identifyRadius = 62;
  static const double dwellTime = 0.45;

  @override
  StageKind get kind => StageKind.xray;

  @override
  bool get isComplete => items.every((i) => i.found);

  @override
  double get progress => items.where((i) => i.found).length / items.length;

  @override
  void hover(PenSample s) {
    lens = s.pos;
    _lastHover = host.now;
  }

  @override
  void down(PenSample s) {
    _touching = true;
    lens = s.pos;
  }

  @override
  void move(PenSample s) {
    if (_touching) lens = s.pos;
  }

  @override
  void up() {
    _touching = false;
    if (host.now - _lastHover > 0.25) lens = null;
  }

  @override
  void tick(double dt) {
    if (!_touching && host.now - _lastHover > 0.25) lens = null;
    final l = lens;
    for (final item in items) {
      if (item.found) continue;
      if (l != null && (l - item.pos).distance <= identifyRadius) {
        item.dwell += dt;
        if (item.dwell >= dwellTime) {
          item.found = true;
          host.cue(Cue.found);
        }
      } else {
        item.dwell = math.max(0, item.dwell - dt * 2);
      }
    }
  }
}

/// Incision: cut along the dotted line without leaving it.
class CutStage extends Stage {
  CutStage(super.host, this.path, {required this.tolerance});

  final Polyline path;
  final double tolerance;

  /// Arc length cut so far.
  double done = 0;
  bool cutting = false;
  final _speed = _Speedometer();

  static const double speedLimit = 1500;

  Offset get resumePoint => path.at(done);

  @override
  StageKind get kind => StageKind.cut;

  @override
  bool get isComplete => done >= path.length - 6;

  @override
  double get progress => (done / path.length).clamp(0.0, 1.0);

  @override
  void down(PenSample s) {
    if (isComplete) return;
    if ((s.pos - resumePoint).distance > math.max(tolerance, 45)) return;
    cutting = true;
    _speed
      ..reset()
      ..add(s.pos, s.time);
  }

  @override
  void move(PenSample s) {
    if (!cutting || isComplete) return;
    // Only look a little ahead, so jumping along the line counts as leaving it.
    final proj = path.project(s.pos, from: done - 30, to: done + 60);
    if (proj.distance > tolerance) {
      cutting = false;
      host.mistake(MistakeKind.offLine, s.pos);
      return;
    }
    if (proj.s > done) done = proj.s;
    _speed.add(s.pos, s.time);
    if (_speed.value > speedLimit) {
      host.mistake(MistakeKind.tooFast, s.pos);
    } else if (s.stylus && s.pressure > deepPressure) {
      host.mistake(MistakeKind.tooDeep, s.pos);
    }
    if (isComplete) cutting = false;
  }

  @override
  void up() => cutting = false;
}

/// An object being pulled out through its corridor.
class ExtractItem {
  ExtractItem(this.emoji, this.corridor) : pos = corridor.start;

  final String emoji;
  final Polyline corridor;
  Offset pos;
  bool extracted = false;

  /// Furthest arc length reached along the corridor.
  double reached = 0;

  /// Where the object goes back to after touching a wall.
  double get checkpoint {
    final third = corridor.length / 3;
    return (reached ~/ third).clamp(0, 2) * third;
  }
}

/// Extraction: pull each object to the exit without touching the walls.
class ExtractStage extends Stage {
  ExtractStage(super.host, this.items, {required this.exit, required this.width});

  final List<ExtractItem> items;
  final Offset exit;

  /// Full corridor width, in design units.
  final double width;

  int? grabbed;
  Offset _grabOffset = Offset.zero;

  static const double grabRadius = 75;
  static const double exitRadius = 40;
  static const double wallMargin = 6;
  static const double step = 6;

  double get halfWidth => width / 2;

  @override
  StageKind get kind => StageKind.extract;

  @override
  bool get isComplete => items.every((i) => i.extracted);

  @override
  double get progress => items.where((i) => i.extracted).length / items.length;

  @override
  void down(PenSample s) {
    double best = grabRadius;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.extracted) continue;
      final d = (s.pos - item.pos).distance;
      if (d <= best) {
        best = d;
        grabbed = i;
        _grabOffset = item.pos - s.pos;
      }
    }
  }

  @override
  void move(PenSample s) {
    final index = grabbed;
    if (index == null) return;
    final item = items[index];
    final target = s.pos + _grabOffset;
    // Walk towards the target in small steps so a fast flick cannot jump a wall.
    final delta = target - item.pos;
    final n = math.max(1, (delta.distance / step).ceil());
    final start = item.pos;
    for (var k = 1; k <= n; k++) {
      final p = start + delta * (k / n);
      final proj = item.corridor.project(p);
      if (proj.distance > halfWidth - wallMargin) {
        host.mistake(MistakeKind.wall, p);
        item.pos = item.corridor.at(item.checkpoint);
        grabbed = null;
        return;
      }
      item.pos = p;
      if (proj.s > item.reached) item.reached = proj.s;
      if ((p - exit).distance <= exitRadius) {
        item.extracted = true;
        grabbed = null;
        host.cue(Cue.pop);
        return;
      }
    }
  }

  @override
  void up() => grabbed = null;
}

/// Stitches: connect the dots across the incision, in order.
class StitchStage extends Stage {
  StitchStage(super.host, this.targets,
      {required this.hitRadius, required this.tolerance});

  final List<Offset> targets;
  final double hitRadius;

  /// How far the thread may stray from the straight line to the next dot.
  final double tolerance;

  /// Number of dots already joined.
  int stitched = 0;
  bool drawing = false;
  Offset? pen;

  @override
  StageKind get kind => StageKind.stitch;

  @override
  bool get isComplete => stitched >= targets.length;

  @override
  double get progress => stitched / targets.length;

  @override
  void down(PenSample s) {
    if (isComplete) return;
    if (stitched == 0) {
      if ((s.pos - targets[0]).distance <= hitRadius * 1.3) {
        stitched = 1;
        drawing = true;
        pen = s.pos;
        host.cue(Cue.stitch);
      }
    } else if ((s.pos - targets[stitched - 1]).distance <= hitRadius * 1.6) {
      drawing = true;
      pen = s.pos;
    }
  }

  @override
  void move(PenSample s) {
    if (!drawing || isComplete) return;
    pen = s.pos;
    final next = targets[stitched];
    if ((s.pos - next).distance <= hitRadius) {
      stitched++;
      host.cue(Cue.stitch);
      if (isComplete) {
        drawing = false;
        pen = null;
      }
      return;
    }
    if (distanceToSegment(s.pos, targets[stitched - 1], next) > tolerance) {
      drawing = false;
      pen = null;
      host.mistake(MistakeKind.offLine, s.pos);
    }
  }

  @override
  void up() {
    drawing = false;
    pen = null;
  }
}
