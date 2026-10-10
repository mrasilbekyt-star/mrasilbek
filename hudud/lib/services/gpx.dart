import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';
import '../data/store.dart';

/// Every saved run as one GPX file, for Strava and other running apps.
String buildGpx(List<(RunRecord, RunRoute)> runs) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="Hudud" xmlns="http://www.topografix.com/GPX/1/1">');
  for (final (record, route) in runs) {
    b
      ..writeln('  <trk>')
      ..writeln('    <name>Hudud ${record.start.toIso8601String()}</name>')
      ..writeln('    <type>running</type>');
    for (final stretch in _segments(route)) {
      b.writeln('    <trkseg>');
      for (final p in stretch) {
        final time = record.start.add(Duration(milliseconds: (p.seconds * 1000).round())).toUtc();
        b.writeln('      <trkpt lat="${p.pos.lat.toStringAsFixed(6)}" lon="${p.pos.lon.toStringAsFixed(6)}">'
            '<time>${time.toIso8601String()}</time></trkpt>');
      }
      b.writeln('    </trkseg>');
    }
    b.writeln('  </trk>');
  }
  b.writeln('</gpx>');
  return b.toString();
}

List<List<RoutePoint>> _segments(RunRoute route) {
  final out = <List<RoutePoint>>[];
  for (final p in route.points) {
    if (out.isEmpty || p.startsStretch) out.add([]);
    out.last.add(p);
  }
  return out;
}

Future<void> shareGpx(HududStore store) async {
  final runs = <(RunRecord, RunRoute)>[];
  for (final r in store.runs.reversed) {
    final route = await store.route(r.id);
    if (route != null) runs.add((r, route));
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/hudud_routes.gpx');
  await file.writeAsString(buildGpx(runs));
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/gpx+xml')]));
}
