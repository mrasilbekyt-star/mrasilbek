import 'package:flutter_test/flutter_test.dart';
import 'package:steady_doc/game/levels.dart';

void main() {
  test('there are 12 patients with rising difficulty', () {
    expect(levels, hasLength(12));
    expect(levels.first.difficulty, 0);
    expect(levels.last.difficulty, 1);
    expect(levels.first.injection, isFalse);
    for (var i = 1; i < levels.length; i++) {
      expect(levels[i].difficulty, greaterThan(levels[i - 1].difficulty));
      expect(levels[i].corridorWidth, lessThan(levels[i - 1].corridorWidth));
    }
  });

  for (final level in levels) {
    group('patient ${level.number} (${level.patient})', () {
      final layout = LevelLayout.generate(level);

      test('is generated the same way every time', () {
        final again = LevelLayout.generate(level);
        expect(again.items, layout.items);
        expect(again.exit, layout.exit);
        expect(again.stitchTargets, layout.stitchTargets);
      });

      test('objects sit inside the belly, apart from each other', () {
        expect(layout.items, hasLength(level.items.length));
        for (var i = 0; i < layout.items.length; i++) {
          final p = layout.items[i];
          expect(BodyLayout.workZone.contains(p), isTrue, reason: 'item $i at $p');
          expect((p - layout.exit).distance, greaterThanOrEqualTo(level.minExitDistance));
          for (var j = 0; j < i; j++) {
            expect((p - layout.items[j]).distance, greaterThanOrEqualTo(170));
          }
        }
      });

      test('every corridor runs inside the torso from its object to the exit', () {
        for (var i = 0; i < layout.corridors.length; i++) {
          final corridor = layout.corridors[i];
          expect(corridor.start, layout.items[i]);
          expect((corridor.end - layout.exit).distance, lessThan(1));
          for (final p in corridor.points) {
            expect(BodyLayout.torso.contains(p), isTrue, reason: 'corridor $i at $p');
          }
        }
      });

      test('incision and stitches stay on the torso', () {
        for (final p in [...layout.cut.points, ...layout.stitchTargets]) {
          expect(BodyLayout.torso.contains(p), isTrue, reason: '$p');
        }
        expect(layout.stitchTargets, hasLength(level.stitchCount));
      });
    });
  }
}
