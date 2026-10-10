import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hudud/core/geo.dart';
import 'package:hudud/core/gps_filter.dart';
import 'package:hudud/core/hex_grid.dart';
import 'package:hudud/core/territory.dart';
import 'package:hudud/run/location.dart';
import 'package:hudud/run/run_session.dart';

const tashkent = GeoPoint(41.3111, 69.2797);

/// GPS readings fed by the test, on a clock the test moves.
class FakeSource implements LocationSource {
  final controller = StreamController<Fix>();
  DateTime clock = DateTime(2026, 10, 11, 6, 30);

  @override
  Stream<Fix> fixes() => controller.stream;

  @override
  DateTime now() => clock;

  /// Moves to [meters] from the origin after [seconds].
  Future<void> at(Vec meters, {int seconds = 1}) async {
    clock = clock.add(Duration(seconds: seconds));
    controller.add(Fix(Plane.toGeo(Plane.toPlane(tashkent) + meters), time: clock, accuracy: 5));
    await Future<void>.delayed(Duration.zero);
  }
}

/// Runs [source] along a path of points [step] meters apart at 3.3 m/s.
Future<void> runPath(FakeSource source, List<Vec> waypoints, {double step = 3.3}) async {
  for (var i = 1; i < waypoints.length; i++) {
    final a = waypoints[i - 1];
    final b = waypoints[i];
    final n = (a.distanceTo(b) / step).ceil();
    for (var k = 1; k <= n; k++) {
      await source.at(a + (b - a) * (k / n));
    }
  }
}

void main() {
  test('distance, time and splits of a straight run', () async {
    final source = FakeSource();
    final session = RunSession(source: source, territory: Territory())..start();
    await source.at(Vec.zero);
    await runPath(source, [Vec.zero, const Vec(2100, 0)]);
    expect(session.distance, closeTo(2100, 5));
    expect(session.splits, hasLength(2));
    expect(session.splits.first, closeTo(1000 / 3.3, 3));
    expect(session.averagePace, closeTo(1000 / 3.3, 5));
    expect(session.loops, 0);
    expect(session.newArea, greaterThan(0), reason: 'the street itself is claimed');
  });

  test('a lap of a block claims it and celebrates once', () async {
    final source = FakeSource();
    final session = RunSession(source: source, territory: Territory())..start();
    await source.at(Vec.zero);
    await runPath(source, [Vec.zero, const Vec(120, 0), const Vec(120, 120), const Vec(0, 120), const Vec(0, -10)]);
    expect(session.loops, 1);
    expect(session.lastCapture, isNotNull);
    expect(session.lastCapture!.loop, isTrue);
    // The block itself plus the street cells around its edge.
    expect(session.newArea, inInclusiveRange(120 * 120, 120 * 120 + 480 * 16));
  });

  test('land that is already owned is not counted again', () async {
    final owned = Territory();
    final source = FakeSource();
    final first = RunSession(source: source, territory: owned)..start();
    await source.at(Vec.zero);
    await runPath(source, [Vec.zero, const Vec(300, 0)]);
    owned.claim(first.newCells);

    final again = FakeSource();
    final second = RunSession(source: again, territory: owned)..start();
    await again.at(Vec.zero);
    await runPath(again, [Vec.zero, const Vec(300, 0)]);
    expect(second.newArea, 0);
  });

  test('a pause stops the clock and breaks the path', () async {
    final source = FakeSource();
    final session = RunSession(source: source, territory: Territory())..start();
    await source.at(Vec.zero);
    await runPath(source, [Vec.zero, const Vec(100, 0)]);
    final before = session.elapsed;
    session.pause();
    // Walk somewhere else during the pause: none of it counts.
    source.clock = source.clock.add(const Duration(minutes: 5));
    await source.at(const Vec(100, 200));
    session.resume();
    expect(session.elapsed, before);
    await source.at(const Vec(100, 200));
    await runPath(source, [const Vec(100, 200), const Vec(200, 200)]);
    expect(session.distance, closeTo(200, 5));
    final result = await session.finish();
    expect(result!.route.stretches, hasLength(2));
  });

  test('auto-pause stops when standing still and resumes on moving', () async {
    final source = FakeSource();
    final session = RunSession(source: source, territory: Territory(), autoPause: true)..start();
    await source.at(Vec.zero);
    await runPath(source, [Vec.zero, const Vec(50, 0)]);
    for (var i = 0; i < 15; i++) {
      await source.at(const Vec(50, 0));
      session.tick();
    }
    expect(session.state, RunState.paused);
    expect(session.autoPaused, isTrue);
    await source.at(const Vec(70, 0));
    expect(session.state, RunState.running);
  });

  test('a car ride claims nothing', () async {
    final source = FakeSource();
    final session = RunSession(source: source, territory: Territory())..start();
    await source.at(Vec.zero);
    for (var x = 15.0; x <= 600; x += 15) {
      await source.at(Vec(x, 0));
    }
    expect(session.tooFastCount, greaterThan(10));
    expect(session.distance, lessThan(50));
    expect(session.newCells.length, lessThan(4));
  });

  test('finishing returns a record and a route that rebuilds the territory', () async {
    final source = FakeSource();
    final session = RunSession(source: source, territory: Territory())..start();
    await source.at(Vec.zero);
    await runPath(source, [Vec.zero, const Vec(150, 0), const Vec(150, 150), const Vec(0, 150), const Vec(0, -10)]);
    final result = (await session.finish())!;
    expect(result.record.loops, 1);
    expect(result.record.distance, closeTo(session.distance, 1e-9));
    expect(result.route.cells.toSet(), containsAll(session.newCells));
    expect(areaOfCells(result.route.cells), closeTo(result.record.newArea, 1e-6));
    expect(result.route.points.length, lessThan(session.route.length));
  });

  test('the demo route closes two loops', () {
    final route = DemoLocation(tashkent).route();
    final tracker = RunSession(source: FakeSource(), territory: Territory()).tracker;
    for (final p in route) {
      tracker.add(Plane.toPlane(p));
    }
    expect(tracker.loops.length, greaterThanOrEqualTo(2));
    expect(areaOfCells(tracker.cells), greaterThan(40000));
    expect(HexGrid.cellAtGeo(route.first), isNotNull);
  });
}
