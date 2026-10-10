import 'package:flutter_test/flutter_test.dart';
import 'package:steady_doc/game/levels.dart';

void main() {
  test('every finding has a fallback emoji', () {
    for (final level in levels) {
      for (final id in level.items) {
        expect(findingEmoji, contains(id));
      }
    }
  });

  test('every patient is a different person in their own scene', () {
    final scenes = {for (final level in levels) level.scene.id};
    expect(scenes, hasLength(levels.length));
    final regions = {for (final level in levels) level.scene.region};
    expect(regions, hasLength(Region.values.length));
    expect({for (final level in levels) level.diagnosis}, hasLength(Diagnosis.values.length));
  });

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
    group('patient ${level.number}', () {
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
          expect(level.scene.workZone.contains(p), isTrue, reason: 'item $i at $p');
          expect((p - layout.exit).distance, greaterThanOrEqualTo(level.minExitDistance));
          for (var j = 0; j < i; j++) {
            expect((p - layout.items[j]).distance, greaterThanOrEqualTo(150));
          }
        }
      });

      test('every corridor runs inside the torso from its object to the exit', () {
        for (var i = 0; i < layout.corridors.length; i++) {
          final corridor = layout.corridors[i];
          expect(corridor.start, layout.items[i]);
          expect((corridor.end - layout.exit).distance, lessThan(1));
          for (final p in corridor.points) {
            expect(level.scene.skin.contains(p), isTrue, reason: 'corridor $i at $p');
          }
        }
      });

      test('incision and stitches stay on the skin', () {
        for (final p in [...layout.cut.points, ...layout.stitchTargets]) {
          expect(level.scene.skin.contains(p), isTrue, reason: '$p');
        }
        expect(layout.stitchTargets.length, inInclusiveRange(5, 14));
      });

      test("objects sit on their scene's side of the incision", () {
        final a = level.scene.incisionStart;
        final b = level.scene.incisionEnd;
        final axis = (b - a) / (b - a).distance;
        for (var i = 0; i < layout.items.length; i++) {
          final d = layout.items[i] - a;
          final side = -axis.dy * d.dx + axis.dx * d.dy;
          final want = level.scene.itemSide != 0 ? level.scene.itemSide : (i.isEven ? -1 : 1);
          expect(side * want, greaterThanOrEqualTo(75), reason: 'item $i');
        }
      });
    });
  }
}
