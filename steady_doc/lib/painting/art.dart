import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Photos and renders dropped into `assets/art/`, by file name without `.png`.
///
/// Every picture is optional: whatever is missing is drawn in code instead.
///
/// | File | What it shows |
/// |---|---|
/// | `scene_closed.png` | Patient from above, abdomen exposed, the rest under drapes |
/// | `scene_open.png` | The same shot with the abdomen opened |
/// | `scene_xray.png` | X-ray of the same abdomen, same framing |
/// | `tool_forceps.png` | Forceps pointing up, tips at the bottom center |
/// | `obj_<id>.png` | A finding, e.g. `obj_coin.png` (ids in `findingEmoji`) |
class ArtAssets {
  ArtAssets(this._images);

  ArtAssets.none() : _images = const {};

  final Map<String, ui.Image> _images;

  ui.Image? operator [](String name) => _images[name];

  ui.Image? get sceneClosed => _images['scene_closed'];
  ui.Image? get sceneOpen => _images['scene_open'];
  ui.Image? get sceneXray => _images['scene_xray'];
  ui.Image? get forceps => _images['tool_forceps'];
  ui.Image? finding(String id) => _images['obj_$id'];

  static Future<ArtAssets> load(AssetBundle bundle) async {
    final images = <String, ui.Image>{};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      final paths = manifest
          .listAssets()
          .where((a) => a.startsWith('assets/art/') && a.endsWith('.png'));
      for (final path in paths) {
        final data = await bundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        final name = path.substring('assets/art/'.length, path.length - '.png'.length);
        images[name] = frame.image;
      }
    } catch (e) {
      debugPrint('Art loading failed, using drawn graphics: $e');
    }
    return ArtAssets(images);
  }
}
