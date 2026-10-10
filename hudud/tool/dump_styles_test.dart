// Writes every map style to build/styles/ so it can be checked with the
// official validator:
//   flutter test tool/dump_styles_test.dart
//   npx gl-style-validate build/styles/night.json
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hudud/map/map_style.dart';

void main() {
  test('dump styles', () {
    Directory('build/styles').createSync(recursive: true);
    for (final theme in MapTheme.all) {
      File('build/styles/${theme.id}.json').writeAsStringSync(styleJson(theme));
    }
  });
}
