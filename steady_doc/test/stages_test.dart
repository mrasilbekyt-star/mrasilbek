import 'package:flutter_test/flutter_test.dart';
import 'package:steady_doc/game/levels.dart';
import 'package:steady_doc/game/stages.dart';

import 'test_utils.dart';

void main() {
  final level = levels[5];
  final layout = LevelLayout.generate(level);
  const syringe = Offset(330, 440);

  group('injection', () {
    test('a slow push finishes without mistakes', () {
      final host = FakeHost();
      final stage = InjectStage(host, speedLimit: 150, top: syringe);
      stage.down(PenSample(stage.handle, 0));
      var t = 0.0;
      for (var y = stage.start; y <= stage.end + 4; y += 2) {
        t += 0.02; // 100 units per second
        stage.move(PenSample(Offset(stage.x, y), t));
      }
      expect(stage.isComplete, isTrue);
      expect(host.mistakes, isEmpty);
    });

    test('rushing hurts', () {
      final host = FakeHost();
      final stage = InjectStage(host, speedLimit: 150, top: syringe);
      stage.down(PenSample(stage.handle, 0));
      stage.move(PenSample(stage.handle + const Offset(0, 60), 0.02));
      stage.move(PenSample(stage.handle + const Offset(0, 60), 0.04));
      expect(host.mistakes, contains(MistakeKind.tooFast));
    });

    test('pressing the S Pen too hard hurts', () {
      final host = FakeHost();
      final stage = InjectStage(host, speedLimit: 150, top: syringe);
      stage.down(PenSample(stage.handle, 0, stylus: true, pressure: 0.5));
      stage.move(PenSample(stage.handle + const Offset(0, 1), 0.05,
          stylus: true, pressure: 0.99));
      expect(host.mistakes, [MistakeKind.tooHard]);
    });

    test('grabbing away from the plunger does nothing', () {
      final host = FakeHost();
      final stage = InjectStage(host, speedLimit: 150, top: syringe);
      stage.down(const PenSample(Offset(600, 900), 0));
      stage.move(const PenSample(Offset(600, 1200), 0.1));
      expect(stage.progress, 0);
    });
  });

  group('x-ray', () {
    test('resting the lens on each object finds it', () {
      final host = FakeHost();
      final items = [
        for (var i = 0; i < level.items.length; i++) HiddenItem(level.items[i], layout.items[i]),
      ];
      final stage = XrayStage(host, items);
      for (final item in items) {
        for (var i = 0; i < 10; i++) {
          stage.hover(PenSample(item.pos + const Offset(20, 0), host.time));
          host.time += 0.05;
          stage.tick(0.05);
        }
      }
      expect(stage.isComplete, isTrue);
      expect(host.cues.where((c) => c == Cue.found), hasLength(items.length));
    });

    test('the lens disappears when the pen leaves', () {
      final host = FakeHost();
      final stage = XrayStage(host, [HiddenItem('🚗', const Offset(400, 700))]);
      stage.hover(PenSample(const Offset(100, 100), host.time));
      expect(stage.lens, isNotNull);
      host.time += 1;
      stage.tick(0.05);
      expect(stage.lens, isNull);
    });
  });

  group('incision', () {
    test('following the line completes the cut', () {
      final host = FakeHost();
      final stage = CutStage(host, layout.cut, tolerance: level.cutTolerance);
      stage.down(PenSample(layout.cut.start, 0, stylus: true, pressure: 0.4));
      var t = 0.0;
      for (var s = 4.0; s <= layout.cut.length + 4; s += 4) {
        t += 0.01;
        stage.move(PenSample(layout.cut.at(s), t, stylus: true, pressure: 0.4));
      }
      expect(stage.isComplete, isTrue);
      expect(host.mistakes, isEmpty);
    });

    test('leaving the line stops the scalpel', () {
      final host = FakeHost();
      final stage = CutStage(host, layout.cut, tolerance: level.cutTolerance);
      stage.down(PenSample(layout.cut.start, 0));
      stage.move(PenSample(layout.cut.at(20), 0.05));
      stage.move(PenSample(layout.cut.at(30) + const Offset(200, 0), 0.1));
      expect(host.mistakes, [MistakeKind.offLine]);
      expect(stage.cutting, isFalse);
      // Moving on without lifting does not cut further.
      stage.move(PenSample(layout.cut.at(40), 0.2));
      expect(stage.done, lessThan(35));
    });

    test('pressing the S Pen too hard cuts too deep', () {
      final host = FakeHost();
      final stage = CutStage(host, layout.cut, tolerance: level.cutTolerance);
      stage.down(PenSample(layout.cut.start, 0, stylus: true, pressure: 0.5));
      stage.move(PenSample(layout.cut.at(6), 0.05, stylus: true, pressure: 0.95));
      expect(host.mistakes, [MistakeKind.tooDeep]);
    });

    test('a cut can only restart where it stopped', () {
      final host = FakeHost();
      final stage = CutStage(host, layout.cut, tolerance: level.cutTolerance);
      stage.down(PenSample(layout.cut.end, 0));
      expect(stage.cutting, isFalse);
    });
  });

  group('extraction', () {
    ExtractStage build(FakeHost host) => ExtractStage(
          host,
          [
            for (var i = 0; i < level.items.length; i++)
              ExtractItem(level.items[i], layout.corridors[i]),
          ],
          exit: layout.exit,
          width: level.corridorWidth,
        );

    test('pulling each object along its corridor gets it out', () {
      final host = FakeHost();
      final stage = build(host);
      var t = 0.0;
      for (final item in stage.items) {
        stage.down(PenSample(item.pos, t));
        for (var s = 4.0; s <= item.corridor.length + 4; s += 4) {
          t += 0.02;
          stage.move(PenSample(item.corridor.at(s), t));
        }
        stage.up();
      }
      expect(stage.isComplete, isTrue);
      expect(host.mistakes, isEmpty);
      expect(host.cues.where((c) => c == Cue.pop), hasLength(stage.items.length));
    });

    test('touching a wall buzzes and drops the object back', () {
      final host = FakeHost();
      final stage = build(host);
      final item = stage.items.first;
      stage.down(PenSample(item.pos, 0));
      final sideways = item.corridor.normalAt(0) * (level.corridorWidth);
      stage.move(PenSample(item.pos + sideways, 0.1));
      expect(host.mistakes, [MistakeKind.wall]);
      expect(stage.grabbed, isNull);
      expect(item.pos, item.corridor.start);
    });

    test('a fast flick cannot jump through a wall', () {
      final host = FakeHost();
      final stage = build(host);
      final item = stage.items.first;
      stage.down(PenSample(item.pos, 0));
      // Straight at the exit, ignoring the corridor's bends and its width.
      final through = item.pos + (layout.exit - item.pos) * 0.5 + item.corridor.normalAt(0) * 300;
      stage.move(PenSample(through, 0.01));
      expect(host.mistakes, [MistakeKind.wall]);
      expect(item.extracted, isFalse);
    });
  });

  group('stitches', () {
    StitchStage build(FakeHost host) => StitchStage(
          host,
          layout.stitchTargets,
          hitRadius: level.stitchHitRadius,
          tolerance: level.stitchTolerance,
        );

    test('joining the dots in order closes the wound', () {
      final host = FakeHost();
      final stage = build(host);
      final targets = layout.stitchTargets;
      stage.down(PenSample(targets.first, 0));
      for (var i = 1; i < targets.length; i++) {
        for (var k = 1; k <= 10; k++) {
          stage.move(PenSample(Offset.lerp(targets[i - 1], targets[i], k / 10)!, 0));
        }
      }
      expect(stage.isComplete, isTrue);
      expect(host.mistakes, isEmpty);
    });

    test('straying from the thread line is a mistake', () {
      final host = FakeHost();
      final stage = build(host);
      final targets = layout.stitchTargets;
      stage.down(PenSample(targets.first, 0));
      stage.move(PenSample(targets.first + const Offset(0, 300), 0.1));
      expect(host.mistakes, [MistakeKind.offLine]);
      expect(stage.drawing, isFalse);
      // Resuming from the last stitch works.
      stage.down(PenSample(targets.first, 0.2));
      expect(stage.drawing, isTrue);
    });

    test('the first stitch must start on the first dot', () {
      final host = FakeHost();
      final stage = build(host);
      stage.down(PenSample(layout.stitchTargets.last, 0));
      expect(stage.drawing, isFalse);
      expect(stage.stitched, 0);
    });
  });
}
