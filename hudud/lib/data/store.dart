import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/territory.dart';
import 'models.dart';

/// Runs and territory, kept as JSON files on the phone.
///
/// `index.json` holds the territory and every run's summary; each route is
/// in `runs/<id>.json` and read only when it is shown.
class HududStore extends ChangeNotifier {
  HududStore(this.dir);

  final Directory dir;
  final List<RunRecord> _runs = [];
  Territory _territory = Territory();
  final Map<String, Future<RunRoute?>> _routes = {};

  /// Newest first.
  List<RunRecord> get runs => List.unmodifiable(_runs);
  Territory get territory => _territory;

  static Future<HududStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final store = HududStore(Directory('${docs.path}/hudud'));
    await store.load();
    return store;
  }

  File get _index => File('${dir.path}/index.json');
  File _routeFile(String id) => File('${dir.path}/runs/$id.json');

  Future<void> load() async {
    _runs.clear();
    _territory = Territory();
    if (!await _index.exists()) return;
    try {
      final json = jsonDecode(await _index.readAsString()) as Map<String, Object?>;
      _territory = Territory([for (final c in json['territory']! as List) (c as num).toInt()]);
      _runs.addAll([
        for (final r in json['runs']! as List) RunRecord.fromJson((r as Map).cast<String, Object?>()),
      ]);
      _runs.sort((a, b) => b.start.compareTo(a.start));
    } catch (e) {
      // A damaged index must not lock the player out; keep a copy to inspect.
      debugPrint('Hudud: could not read index.json: $e');
      await _index.copy('${_index.path}.broken');
    }
    notifyListeners();
  }

  /// Saves a finished run and adds its land to the territory.
  Future<void> addRun(RunRecord record, RunRoute route) async {
    await _write(_routeFile(record.id), jsonEncode(route.toJson()));
    _territory.claim(route.cells);
    _runs.insert(0, record);
    await _saveIndex();
    notifyListeners();
  }

  /// A saved route; read from disk once, then kept.
  Future<RunRoute?> route(String id) => _routes.putIfAbsent(id, () => _readRoute(id));

  Future<RunRoute?> _readRoute(String id) async {
    final file = _routeFile(id);
    if (!await file.exists()) return null;
    try {
      return RunRoute.fromJson(jsonDecode(await file.readAsString()) as Map<String, Object?>);
    } catch (e) {
      debugPrint('Hudud: could not read route $id: $e');
      return null;
    }
  }

  /// Forgets everything: runs, routes and territory.
  Future<void> clear() async {
    if (await dir.exists()) await dir.delete(recursive: true);
    _routes.clear();
    _runs.clear();
    _territory = Territory();
    notifyListeners();
  }

  Future<void> _saveIndex() => _write(
        _index,
        jsonEncode({
          'version': 1,
          'territory': _territory.cells.toList(),
          'runs': [for (final r in _runs) r.toJson()],
        }),
      );

  /// Writes through a temporary file, so a crash never leaves half a file.
  static Future<void> _write(File file, String text) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(file.path);
  }
}
