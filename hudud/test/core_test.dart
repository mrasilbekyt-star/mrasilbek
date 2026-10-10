import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hudud/core/capture.dart';
import 'package:hudud/core/geo.dart';
import 'package:hudud/core/gps_filter.dart';
import 'package:hudud/core/hex_grid.dart';
import 'package:hudud/core/territory.dart';

const tashkent = GeoPoint(41.3111, 69.2797);

/// A walk around a square of [side] meters, one point every [step] meters.
List<Vec> square(Vec origin, double side, {double step = 4}) {
  final corners = [
    origin,
    origin + Vec(side, 0),
    origin + Vec(side, side),
    origin + Vec(0, side),
    origin,
  ];
  final out = <Vec>[];
  for (var i = 0; i < 4; i++) {
    final a = corners[i];
    final b = corners[i + 1];
    final n = (a.distanceTo(b) / step).ceil();
    for (var k = 0; k < n; k++) {
      out.add(a + (b - a) * (k / n));
    }
  }
  out.add(origin);
  return out;
}

void main() {
  group('plane', () {
    test('round-trips a point', () {
      final back = Plane.toGeo(Plane.toPlane(tashkent));
      expect(back.lat, closeTo(tashkent.lat, 1e-9));
      expect(back.lon, closeTo(tashkent.lon, 1e-9));
    });

    test('distances on the plane match the ground in Tashkent', () {
      final b = GeoPoint(tashkent.lat + 0.001, tashkent.lon + 0.001);
      final plane = Plane.toPlane(tashkent).distanceTo(Plane.toPlane(b));
      expect(plane, closeTo(haversine(tashkent, b), 0.5));
    });
  });

  group('hex grid', () {
    test('keys round-trip, including negative coordinates', () {
      for (final (q, r) in [(0, 0), (-5, 7), (812345, -634210), (-1, -1)]) {
        final k = HexGrid.key(q, r);
        expect((HexGrid.qOf(k), HexGrid.rOf(k)), (q, r));
      }
    });

    test('a cell contains its own center and corners are 10 m away', () {
      final cell = HexGrid.cellAtGeo(tashkent);
      final c = HexGrid.center(cell);
      expect(HexGrid.cellAt(c), cell);
      for (final corner in HexGrid.corners(cell)) {
        expect(corner.distanceTo(c), closeTo(HexGrid.size, 1e-6));
      }
      expect(signedArea(HexGrid.corners(cell)), closeTo(HexGrid.planeCellArea, 1e-6));
    });

    test('neighbors share the edge named by their direction', () {
      final cell = HexGrid.cellAtGeo(tashkent);
      final neighbors = HexGrid.neighbors(cell);
      for (var i = 0; i < 6; i++) {
        final n = neighbors[i];
        expect(HexGrid.center(n).distanceTo(HexGrid.center(cell)),
            closeTo(HexGrid.size * math.sqrt(3), 1e-6));
        // Corner i and i+1 of the cell are corners of neighbor i too.
        final shared = {HexGrid.cornerKey(cell, i), HexGrid.cornerKey(cell, (i + 1) % 6)};
        final theirs = {for (var j = 0; j < 6; j++) HexGrid.cornerKey(n, j)};
        expect(theirs.containsAll(shared), isTrue, reason: 'direction $i');
      }
    });

    test('a cell is about 260 square meters', () {
      expect(HexGrid.areaOf(HexGrid.cellAtGeo(tashkent)), closeTo(259.8, 1));
    });

    test('cellsAlong covers a straight line without gaps', () {
      final a = Plane.toPlane(tashkent);
      final cells = HexGrid.cellsAlong(a, a + const Vec(100, 0)).toList();
      // 100 m is about six cells wide; a line near a row border zigzags.
      expect(cells.length, inInclusiveRange(6, 13));
      for (var i = 1; i < cells.length; i++) {
        expect(HexGrid.neighbors(cells[i - 1]), contains(cells[i]));
      }
    });
  });

  group('territory outlines', () {
    test('one cell is one hexagon', () {
      final cell = HexGrid.cellAtGeo(tashkent);
      final shapes = shapesOf({cell});
      expect(shapes, hasLength(1));
      expect(shapes.single.outer, hasLength(6));
      expect(shapes.single.holes, isEmpty);
    });

    test('a ring of cells has a hole', () {
      final cell = HexGrid.cellAtGeo(tashkent);
      final shapes = shapesOf({...HexGrid.neighbors(cell)});
      expect(shapes, hasLength(1));
      expect(shapes.single.holes, hasLength(1));
      expect(shapes.single.holes.single, hasLength(6));
    });

    test('separate patches are separate shapes', () {
      final a = HexGrid.cellAtGeo(tashkent);
      final b = HexGrid.cellAt(Plane.toPlane(tashkent) + const Vec(200, 0));
      expect(shapesOf({a, b}), hasLength(2));
    });

    test('claim reports only new cells and updates the area', () {
      final t = Territory();
      final a = HexGrid.cellAtGeo(tashkent);
      expect(t.claim([a]), [a]);
      expect(t.claim([a]), isEmpty);
      expect(t.area, closeTo(HexGrid.areaOf(a), 1e-9));
    });
  });

  group('capture', () {
    final origin = Plane.toPlane(tashkent);

    test('running a straight street claims only the street', () {
      final tracker = CaptureTracker();
      for (var x = 0.0; x <= 300; x += 4) {
        final step = tracker.add(origin + Vec(x, 0));
        expect(step.loop, isNull);
      }
      expect(tracker.loops, isEmpty);
      expect(tracker.cells.length, inInclusiveRange(17, 36));
    });

    test('running around a block claims the whole block', () {
      final tracker = CaptureTracker();
      Loop? loop;
      for (final p in square(origin, 100)) {
        loop ??= tracker.add(p).loop;
      }
      expect(loop, isNotNull);
      // A 100 m square is 10,000 m²; cells whose centers are inside cover
      // about the same area.
      expect(loop!.area, closeTo(10000, 1200));
      expect(tracker.loops, hasLength(1));
    });

    test('crossing the earlier path closes the loop too', () {
      final tracker = CaptureTracker();
      // Run along the bottom, up, back along the top, then cut down across
      // the bottom: the loop is the 60 x 100 m box right of x = 40.
      final pts = <Vec>[
        for (var x = 20.0; x <= 100; x += 4) origin + Vec(x, 0),
        for (var y = 0.0; y <= 100; y += 4) origin + Vec(100, y),
        for (var x = 100.0; x >= 40; x -= 4) origin + Vec(x, 100),
        for (var y = 100.0; y >= -40; y -= 4) origin + Vec(40, y),
      ];
      Loop? loop;
      for (final p in pts) {
        loop ??= tracker.add(p).loop;
      }
      expect(loop, isNotNull);
      expect(loop!.area, closeTo(6000, 900));
    });

    test('out and back along one street is not a loop', () {
      final tracker = CaptureTracker();
      for (var x = 0.0; x <= 200; x += 4) {
        tracker.add(origin + Vec(x, 0));
      }
      // Back along the other sidewalk, 12 m away.
      for (var x = 200.0; x >= 0; x -= 4) {
        tracker.add(origin + Vec(x, 12));
      }
      expect(tracker.loops, isEmpty);
    });

    test('a break stops loops from joining across it', () {
      final tracker = CaptureTracker();
      final pts = square(origin, 100);
      for (final p in pts.take(pts.length ~/ 2)) {
        tracker.add(p);
      }
      tracker.breakPath();
      for (final p in pts.skip(pts.length ~/ 2)) {
        tracker.add(p);
      }
      expect(tracker.loops, isEmpty);
    });

    test('tells how far away the loop can be closed', () {
      final tracker = CaptureTracker();
      final pts = square(origin, 100);
      for (final p in pts.take(pts.length - 8)) {
        tracker.add(p);
      }
      final hint = tracker.closeHint()!;
      expect(hint.$1, inInclusiveRange(25, 40));
      expect(hint.$2.distanceTo(origin), lessThan(5));
    });
  });

  group('gps filter', () {
    final t0 = DateTime(2026, 10, 10, 7);
    Fix at(double metersEast, int seconds, {double accuracy = 5}) {
      final p = Plane.toGeo(Plane.toPlane(tashkent) + Vec(metersEast, 0));
      return Fix(p, time: t0.add(Duration(seconds: seconds)), accuracy: accuracy);
    }

    test('accepts a runner', () {
      final f = GpsFilter();
      expect(f.add(at(0, 0)).verdict, Verdict.started);
      final r = f.add(at(3.5, 1));
      expect(r.verdict, Verdict.accepted);
      expect(r.meters, closeTo(3.5, 0.2));
    });

    test('drops inaccurate readings and jitter', () {
      final f = GpsFilter();
      expect(f.add(at(0, 0, accuracy: 60)).verdict, Verdict.ignored);
      f.add(at(0, 1));
      expect(f.add(at(1, 2)).verdict, Verdict.ignored);
      // Jitter adds up: once 3 m away from the last kept point it counts.
      expect(f.add(at(3.2, 3)).verdict, Verdict.accepted);
    });

    test('skips a single GPS jump', () {
      final f = GpsFilter();
      f.add(at(0, 0));
      expect(f.add(at(200, 1)).verdict, Verdict.ignored);
      expect(f.add(at(4, 2)).verdict, Verdict.accepted);
    });

    test('flags a car', () {
      final f = GpsFilter();
      f.add(at(0, 0));
      expect(f.add(at(10, 1)).verdict, Verdict.tooFast);
      expect(f.add(at(20, 2)).verdict, Verdict.tooFast);
    });
  });
}
