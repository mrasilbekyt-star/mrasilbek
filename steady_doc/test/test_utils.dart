import 'dart:ui';

import 'package:steady_doc/game/geometry.dart';
import 'package:steady_doc/game/session.dart';
import 'package:steady_doc/game/stages.dart';

class FakeHost implements StageHost {
  double time = 0;
  final mistakes = <MistakeKind>[];
  final cues = <Cue>[];

  @override
  double get now => time;

  @override
  void mistake(MistakeKind kind, Offset at) => mistakes.add(kind);

  @override
  void cue(Cue cue) => cues.add(cue);
}

/// Drives a [GameSession] like a careful player, one stage at a time.
class CarefulPlayer {
  CarefulPlayer(this.session);

  final GameSession session;
  double clock = 0;

  PenSample _at(Offset p) => PenSample(p, clock);

  void _moveTo(Offset from, Offset to, {double step = 4, double speed = 80}) {
    final d = to - from;
    final n = (d.distance / step).ceil().clamp(1, 100000);
    for (var k = 1; k <= n; k++) {
      clock += step / speed;
      session.move(_at(from + d * (k / n)));
    }
  }

  void _follow(Polyline path, {double step = 4, double speed = 300}) {
    for (var s = step; s <= path.length + step; s += step) {
      clock += step / speed;
      session.move(_at(path.at(s)));
    }
  }

  void playStage() {
    final stage = session.stage;
    switch (stage) {
      case InjectStage():
        final start = stage.handle;
        session.down(_at(start));
        _moveTo(start, Offset(start.dx, stage.end + 5), step: 2,
            speed: stage.speedLimit * 0.6);
        session.up();
      case XrayStage():
        for (final item in stage.items) {
          for (var i = 0; i < 12; i++) {
            session.hover(_at(item.pos));
            session.tick(0.05);
          }
        }
      case CutStage():
        session.down(_at(stage.path.start));
        _follow(stage.path);
        session.up();
      case ExtractStage():
        for (final item in stage.items) {
          session.down(_at(item.pos));
          _follow(item.corridor);
          session.up();
        }
      case StitchStage():
        session.down(_at(stage.targets.first));
        for (var i = 1; i < stage.targets.length; i++) {
          _moveTo(stage.targets[i - 1], stage.targets[i]);
        }
        session.up();
    }
  }

  /// Plays every stage, waiting through the "Great!" banners.
  void playLevel() {
    for (var guard = 0; guard < 20 && session.state != SessionState.won; guard++) {
      if (session.state == SessionState.playing) playStage();
      for (var i = 0; i < 30 && session.state == SessionState.stageClear; i++) {
        session.tick(0.05);
      }
      if (session.state == SessionState.failed) return;
    }
  }
}
