import 'package:flutter_test/flutter_test.dart';
import 'package:steady_doc/game/geometry.dart';

void main() {
  test('distance to a segment clamps to its ends', () {
    const a = Offset(0, 0);
    const b = Offset(10, 0);
    expect(distanceToSegment(const Offset(5, 3), a, b), closeTo(3, 1e-9));
    expect(distanceToSegment(const Offset(-4, 3), a, b), closeTo(5, 1e-9));
    expect(distanceToSegment(const Offset(13, 4), a, b), closeTo(5, 1e-9));
  });

  test('polyline measures, samples and projects by arc length', () {
    final line = Polyline(const [Offset(0, 0), Offset(10, 0), Offset(10, 10)]);
    expect(line.length, closeTo(20, 1e-9));
    expect(line.at(15), const Offset(10, 5));
    expect(line.normalAt(5), const Offset(0, 1));

    final proj = line.project(const Offset(12, 4));
    expect(proj.s, closeTo(14, 1e-9));
    expect(proj.distance, closeTo(2, 1e-9));

    // A window keeps the projection on the requested part of the path.
    final windowed = line.project(const Offset(12, 4), from: 0, to: 8);
    expect(windowed.s, closeTo(8, 1e-9));
  });

  test('pointsUntil ends exactly at the requested length', () {
    final line = Polyline(const [Offset(0, 0), Offset(10, 0), Offset(10, 10)]);
    final pts = line.pointsUntil(12);
    expect(pts.first, Offset.zero);
    expect(pts.last, const Offset(10, 2));
  });

  test('resample spaces points evenly', () {
    final pts = resample(const [Offset(0, 0), Offset(100, 0)], 10);
    expect(pts, hasLength(11));
    expect(pts[3].dx, closeTo(30, 1e-9));
  });

  test('catmull-rom passes through its control points', () {
    const ctrl = [Offset(0, 0), Offset(50, 40), Offset(100, 0)];
    final curve = catmullRom(ctrl, samplesPerSegment: 10);
    expect(curve.first, ctrl.first);
    expect(curve.last, ctrl.last);
    expect(curve.any((p) => (p - ctrl[1]).distance < 1e-9), isTrue);
  });

  test('insidePolygon respects the outline and the margin', () {
    const diamond = [Offset(0, -100), Offset(100, 0), Offset(0, 100), Offset(-100, 0)];
    expect(insidePolygon(diamond, Offset.zero), isTrue);
    expect(insidePolygon(diamond, const Offset(80, 80)), isFalse);
    expect(insidePolygon(diamond, const Offset(45, 45)), isTrue);
    expect(insidePolygon(diamond, const Offset(45, 45), margin: 20), isFalse);
  });
}
