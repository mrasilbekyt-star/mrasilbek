import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'levels.dart';
import 'stages.dart';

/// Every sound the game plays.
enum Sfx { buzz, found, pop, stitch, stage, win, fail }

/// Vibration strengths.
enum Haptic { light, medium, heavy }

/// Where the session sends sounds and vibrations.
abstract interface class FeedbackSink {
  void play(Sfx sfx);
  void haptic(Haptic haptic);
}

class SilentFeedback implements FeedbackSink {
  const SilentFeedback();
  @override
  void play(Sfx sfx) {}
  @override
  void haptic(Haptic haptic) {}
}

enum SessionState { playing, stageClear, paused, won, failed }

/// A message that floats up from where a mistake happened.
class FloatingText {
  FloatingText(this.mistake, this.pos, this.born);
  final MistakeKind mistake;
  final Offset pos;
  final double born;
}

/// One attempt at one level: the stages, the patient's heart and the score.
class GameSession extends ChangeNotifier implements StageHost {
  GameSession(this.level, {this.feedback = const SilentFeedback()})
      : layout = LevelLayout.generate(level) {
    stages = _buildStages();
  }

  final LevelDef level;
  final LevelLayout layout;
  final FeedbackSink feedback;
  late final List<Stage> stages;

  static const double restingBpm = 72;
  static const double faintBpm = 170;
  static const double mistakeCooldown = 0.7;
  static const double stageClearDelay = 1.1;
  static const int ecgSamples = 240;

  int stageIndex = 0;
  SessionState state = SessionState.playing;
  SessionState _beforePause = SessionState.playing;
  double _now = 0;
  double bpm = restingBpm;
  int mistakes = 0;
  double _lastMistake = -10;
  double _stageClearUntil = 0;
  double _beat = 0;
  final List<double> ecg = List.filled(ecgSamples, 0);
  int ecgHead = 0;
  final List<FloatingText> floats = [];

  /// Last place the S Pen hovered, for the tool preview.
  Offset? hoverPos;
  double _hoverAt = -1;
  bool stylusSeen = false;

  /// Game time when the operation succeeded.
  double? finishedAt;

  @override
  double get now => _now;

  Stage get stage => stages[stageIndex];

  bool get cutDone => stages.whereType<CutStage>().every((s) => s.isComplete);
  bool get extractDone =>
      stages.whereType<ExtractStage>().every((s) => s.isComplete);
  bool get stitchDone =>
      stages.whereType<StitchStage>().every((s) => s.isComplete);

  /// 0 when calm, 1 just before fainting.
  double get stress =>
      ((bpm - restingBpm) / (faintBpm - restingBpm)).clamp(0.0, 1.0);

  /// Blood oxygen, in percent: falls as the patient panics.
  int get spo2 => (99 - stress * 11).round();

  /// Blood pressure, in mmHg: rises as the patient panics.
  int get systolic => (118 + stress * 52 + 2 * math.sin(_now * 0.7)).round();
  int get diastolic => (76 + stress * 28 + math.sin(_now * 0.9)).round();

  /// The monitor sounds its alarm close to fainting.
  bool get alarm => stress >= 0.7;

  int get stars => mistakes <= 1
      ? 3
      : mistakes <= 4
          ? 2
          : 1;

  List<Stage> _buildStages() {
    final items = [
      for (var i = 0; i < level.items.length; i++)
        HiddenItem(level.items[i], layout.items[i]),
    ];
    return [
      if (level.injection) InjectStage(this, speedLimit: level.injectSpeedLimit),
      XrayStage(this, items),
      CutStage(this, layout.cut, tolerance: level.cutTolerance),
      ExtractStage(
        this,
        [
          for (var i = 0; i < level.items.length; i++)
            ExtractItem(level.items[i], layout.corridors[i]),
        ],
        exit: layout.exit,
        width: level.corridorWidth,
      ),
      StitchStage(
        this,
        layout.stitchTargets,
        hitRadius: level.stitchHitRadius,
        tolerance: level.stitchTolerance,
      ),
    ];
  }

  bool get _acceptsInput => state == SessionState.playing;

  void _seeStylus(PenSample s) {
    if (s.stylus) stylusSeen = true;
  }

  void down(PenSample s) {
    _seeStylus(s);
    if (!_acceptsInput) return;
    stage.down(s);
    _afterInput();
  }

  void move(PenSample s) {
    _seeStylus(s);
    if (s.stylus) {
      hoverPos = null;
    }
    if (!_acceptsInput) return;
    stage.move(s);
    _afterInput();
  }

  void up() {
    if (!_acceptsInput) return;
    stage.up();
    _afterInput();
  }

  void hover(PenSample s) {
    _seeStylus(s);
    hoverPos = s.pos;
    _hoverAt = _now;
    if (!_acceptsInput) return;
    stage.hover(s);
    _afterInput();
  }

  void _afterInput() {
    _checkStage();
    notifyListeners();
  }

  void tick(double dt) {
    if (state == SessionState.paused) return;
    dt = math.min(dt, 0.05);
    _now += dt;

    if (state == SessionState.playing || state == SessionState.stageClear) {
      if (_now - _lastMistake > 2) {
        bpm = math.max(restingBpm, bpm - 3 * dt);
      }
    }
    _beat += dt * bpm / 60;
    ecg[ecgHead] = ecgWave(_beat % 1);
    ecgHead = (ecgHead + 1) % ecgSamples;

    if (hoverPos != null && _now - _hoverAt > 0.25) hoverPos = null;
    floats.removeWhere((f) => _now - f.born > 1.2);

    if (state == SessionState.playing) {
      stage.tick(dt);
      _checkStage();
    } else if (state == SessionState.stageClear && _now >= _stageClearUntil) {
      stageIndex++;
      state = SessionState.playing;
    }
    notifyListeners();
  }

  /// One heartbeat on the monitor, 0..1 through the beat.
  static double ecgWave(double p) {
    double bump(double center, double width, double height) {
      final x = (p - center) / width;
      return height * math.exp(-x * x);
    }

    return bump(0.18, 0.035, 0.12) +
        bump(0.30, 0.012, -0.15) +
        bump(0.33, 0.014, 1.0) +
        bump(0.36, 0.012, -0.3) +
        bump(0.58, 0.06, 0.25);
  }

  void _checkStage() {
    if (state != SessionState.playing || !stage.isComplete) return;
    if (stageIndex == stages.length - 1) {
      state = SessionState.won;
      finishedAt = _now;
      feedback.play(Sfx.win);
      feedback.haptic(Haptic.medium);
    } else {
      state = SessionState.stageClear;
      _stageClearUntil = _now + stageClearDelay;
      feedback.play(Sfx.stage);
      feedback.haptic(Haptic.light);
    }
  }

  @override
  void mistake(MistakeKind kind, Offset at) {
    if (state != SessionState.playing) return;
    if (_now - _lastMistake < mistakeCooldown) return;
    _lastMistake = _now;
    mistakes++;
    bpm += level.bpmPerMistake;
    floats.add(FloatingText(kind, at, _now));
    feedback.play(Sfx.buzz);
    feedback.haptic(Haptic.medium);
    if (bpm >= faintBpm) {
      bpm = faintBpm;
      state = SessionState.failed;
      feedback.play(Sfx.fail);
      feedback.haptic(Haptic.heavy);
    }
  }

  @override
  void cue(Cue cue) {
    switch (cue) {
      case Cue.found:
        feedback.play(Sfx.found);
        feedback.haptic(Haptic.light);
      case Cue.pop:
        feedback.play(Sfx.pop);
        feedback.haptic(Haptic.light);
      case Cue.stitch:
        feedback.play(Sfx.stitch);
    }
  }

  void pause() {
    if (state == SessionState.playing || state == SessionState.stageClear) {
      _beforePause = state;
      state = SessionState.paused;
      stage.up();
      notifyListeners();
    }
  }

  void resume() {
    if (state == SessionState.paused) {
      state = _beforePause;
      notifyListeners();
    }
  }
}
