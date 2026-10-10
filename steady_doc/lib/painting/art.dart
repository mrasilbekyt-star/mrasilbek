import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Photos and renders dropped into `assets/art/`, by file name without extension
/// (`.jpg`, `.jpeg`, `.png` or `.webp`).
///
/// Every picture is optional: whatever is missing is drawn in code instead.
///
/// | File | What it shows |
/// |---|---|
/// | `scene_closed` | Patient from above, abdomen exposed, the rest under drapes |
/// | `scene_open` | The same shot with the abdomen opened |
/// | `scene_xray` | X-ray of the same abdomen, same framing |
/// | `scene_done` | The same shot after the operation, wound closed |
/// | `tool_forceps` | Forceps pointing up, tips at the bottom center (transparent) |
/// | `obj_<id>` | A finding, e.g. `obj_coin.png` (ids in `findingEmoji`, transparent) |
///
/// Scene pictures are 3:4 portrait and cover the whole 1000 x 1400 table.
class ArtAssets {
  ArtAssets(this._images);

  ArtAssets.none() : _images = const {};

  final Map<String, ui.Image> _images;

  ui.Image? operator [](String name) => _images[name];

  ui.Image? get sceneClosed => _images['scene_closed'];
  ui.Image? get sceneOpen => _images['scene_open'];
  ui.Image? get sceneXray => _images['scene_xray'];
  ui.Image? get sceneDone => _images['scene_done'];
  ui.Image? get forceps => _images['tool_forceps'];
  ui.Image? finding(String id) => _images['obj_$id'];

  static const _extensions = {'png', 'jpg', 'jpeg', 'webp'};

  static Future<ArtAssets> load(AssetBundle bundle) async {
    final images = <String, ui.Image>{};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      final paths = manifest.listAssets().where((a) => a.startsWith('assets/art/'));
      for (final path in paths) {
        final file = path.substring('assets/art/'.length);
        final dot = file.lastIndexOf('.');
        if (dot <= 0 || !_extensions.contains(file.substring(dot + 1).toLowerCase())) continue;
        final data = await bundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        images[file.substring(0, dot)] = frame.image;
      }
    } catch (e) {
      debugPrint('Art loading failed, using drawn graphics: $e');
    }
    return ArtAssets(images);
  }
}
