import 'package:flutter_test/flutter_test.dart';
import 'package:steady_doc/game/levels.dart';
import 'package:steady_doc/game/session.dart';
import 'package:steady_doc/game/stages.dart';

import 'test_utils.dart';

class RecordingFeedback implements FeedbackSink {
  final sounds = <Sfx>[];
  @override
  void play(Sfx sfx) => sounds.add(sfx);
  @override
  void haptic(Haptic haptic) {}
}

void main() {
  for (final level in levels) {
    test('a careful surgeon cures patient ${level.number} with 3 stars', () {
      final feedback = RecordingFeedback();
      final session = GameSession(level, feedback: feedback);
      CarefulPlayer(session).playLevel();
      expect(session.state, SessionState.won);
      expect(session.mistakes, 0);
      expect(session.stars, 3);
      expect(session.finishedAt, isNotNull);
      expect(feedback.sounds.last, Sfx.win);
    });
  }

  test('the first patient skips the injection, later ones start with it', () {
    expect(GameSession(levels[0]).stage.kind, StageKind.xray);
    expect(GameSession(levels[1]).stage.kind, StageKind.inject);
  });

  test('mistakes raise the heart rate until the patient faints', () {
    final session = GameSession(levels.last);
    var guard = 0;
    while (session.state == SessionState.playing && guard++ < 50) {
      session.mistake(MistakeKind.wall, const Offset(500, 700));
      session.tick(0.05);
      for (var i = 0; i < 16; i++) {
        session.tick(0.05);
      }
    }
    expect(session.state, SessionState.failed);
    expect(session.bpm, GameSession.faintBpm);
    expect(session.mistakes, greaterThan(3));
  });

  test('mistakes in quick succession count once', () {
    final session = GameSession(levels.first);
    session.mistake(MistakeKind.wall, Offset.zero);
    session.mistake(MistakeKind.wall, Offset.zero);
    session.tick(0.1);
    session.mistake(MistakeKind.wall, Offset.zero);
    expect(session.mistakes, 1);
  });

  test('the heart calms down after a while without mistakes', () {
    final session = GameSession(levels.first);
    session.mistake(MistakeKind.wall, Offset.zero);
    final scared = session.bpm;
    for (var i = 0; i < 100; i++) {
      session.tick(0.05);
    }
    expect(session.bpm, lessThan(scared));
    expect(session.bpm, greaterThanOrEqualTo(GameSession.restingBpm));
  });

  test('vitals worsen as the patient panics', () {
    final session = GameSession(levels.first);
    expect(session.spo2, 99);
    expect(session.alarm, isFalse);
    final calmSystolic = session.systolic;
    for (var i = 0; i < 6; i++) {
      session.mistake(MistakeKind.wall, Offset.zero);
      for (var k = 0; k < 16; k++) {
        session.tick(0.05);
      }
    }
    expect(session.spo2, lessThan(95));
    expect(session.systolic, greaterThan(calmSystolic + 15));
    expect(session.alarm, isTrue);
  });

  test('stars drop with mistakes', () {
    final session = GameSession(levels.first);
    expect(session.stars, 3);
    session.mistakes = 3;
    expect(session.stars, 2);
    session.mistakes = 7;
    expect(session.stars, 1);
  });

  test('pausing freezes time and ignores input', () {
    final session = GameSession(levels.first);
    session.pause();
    final before = session.now;
    session.tick(1);
    session.hover(const PenSample(Offset(400, 700), 0));
    expect(session.now, before);
    final xray = session.stage as XrayStage;
    expect(xray.lens, isNull);
    session.resume();
    expect(session.state, SessionState.playing);
  });
}
