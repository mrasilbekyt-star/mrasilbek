// Draws the launcher icons and the Play Store graphics from code.
//
//   flutter test tool/render_store_assets_test.dart
//
// Writes android/app/src/main/res/mipmap-*/ic_launcher.png and store/*.png.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_doc/painting/patient_painter.dart';

const _skin = Color(0xFFF2C9A0);
const _capColor = Color(0xFF00695C);

Future<void> _save(String path, int w, int h, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(w, h);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

/// Patient head with a surgical cap and a band-aid, centered on the origin.
void _paintHead(Canvas c) {
  final edge = Paint()
    ..color = Color.lerp(_skin, Colors.black, 0.18)!
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;
  for (final dx in [-130.0, 130.0]) {
    c.drawCircle(Offset(dx, 12), 30, Paint()..color = _skin);
    c.drawCircle(Offset(dx, 12), 30, edge);
  }
  c.drawCircle(Offset.zero, 130, Paint()..color = _skin);
  c.save();
  c.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 132)));
  c.drawRect(const Rect.fromLTRB(-140, -140, 140, -66), Paint()..color = _capColor);
  c.restore();
  c.drawCircle(Offset.zero, 130, edge);
  // White cross on the cap.
  final cross = Paint()..color = Colors.white;
  c.drawRect(Rect.fromCenter(center: const Offset(0, -98), width: 36, height: 12), cross);
  c.drawRect(Rect.fromCenter(center: const Offset(0, -98), width: 12, height: 36), cross);

  paintFace(c, 0.25, 1, Mood.normal, center: Offset.zero);

  // Band-aid on the cheek.
  c.save();
  c.translate(78, 52);
  c.rotate(-0.55);
  c.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 82, height: 30), const Radius.circular(15)),
    Paint()..color = const Color(0xFFE8B98A),
  );
  c.drawRect(Rect.fromCenter(center: Offset.zero, width: 26, height: 22),
      Paint()..color = const Color(0xFFF7DCC0));
  c.restore();
}

void _paintIcon(Canvas c, double size) {
  c.scale(size / 512);
  const square = Rect.fromLTWH(0, 0, 512, 512);
  c.drawRect(
    square,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2BB5A6), Color(0xFF0B4F44)],
      ).createShader(square),
  );
  c.drawCircle(const Offset(256, 262), 205, Paint()..color = const Color(0x22FFFFFF));
  c.save();
  c.translate(256, 268);
  c.scale(1.3);
  _paintHead(c);
  c.restore();
}

void _paintFeatureGraphic(Canvas c) {
  const rect = Rect.fromLTWH(0, 0, 1024, 500);
  c.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1B7A6C), Color(0xFF0B2B25)],
      ).createShader(rect),
  );
  c.drawCircle(const Offset(250, 250), 215, Paint()..color = const Color(0x1FFFFFFF));
  c.save();
  c.translate(250, 262);
  c.scale(1.3);
  _paintHead(c);
  c.restore();

  void text(String s, Offset at, double size, FontWeight weight, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: 'Roboto', fontSize: size, fontWeight: weight, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at);
  }

  text('Steady Doc', const Offset(496, 126), 92, FontWeight.w900, Colors.white);
  text('Steady-hand surgery game', const Offset(506, 248), 36, FontWeight.w500,
      const Color(0xDDFFFFFF));
  text('Made for the S Pen', const Offset(506, 296), 36, FontWeight.w500,
      const Color(0xFF9FF2E4));

  // Little badges: x-ray, incision, stitches.
  final badges = [const Offset(540, 410), const Offset(640, 410), const Offset(740, 410)];
  for (final b in badges) {
    c.drawCircle(b, 38, Paint()..color = const Color(0x33FFFFFF));
  }
  // X-ray lens with ribs.
  c.drawCircle(badges[0], 30, Paint()..color = const Color(0xFF0B1E3A));
  final bone = Paint()
    ..color = const Color(0xFFBFD9F2)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  for (var i = -1; i <= 1; i++) {
    c.drawArc(Rect.fromCircle(center: badges[0] + Offset(0, i * 12.0 + 14), radius: 18),
        math.pi * 1.15, math.pi * 0.7, false, bone);
  }
  // Dotted incision.
  final dot = Paint()..color = Colors.white;
  for (var i = -2; i <= 2; i++) {
    c.drawCircle(badges[1] + Offset(i * 10.0, math.sin(i * 0.9) * 8), 3.5, dot);
  }
  // Zigzag stitches.
  final thread = Paint()
    ..color = const Color(0xFFB39DDB)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeJoin = StrokeJoin.round;
  final zig = Path()..moveTo(badges[2].dx - 22, badges[2].dy - 8);
  for (var i = 0; i < 4; i++) {
    zig.lineTo(badges[2].dx - 22 + (i + 1) * 11, badges[2].dy + (i.isEven ? 10 : -8));
  }
  c.drawPath(zig, thread);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const fonts = 'bin/cache/artifacts/material_fonts';
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
    ByteData font(String name) =>
        ByteData.sublistView(File('$flutterRoot/$fonts/$name').readAsBytesSync());
    await (FontLoader('Roboto')
          ..addFont(Future.value(font('Roboto-Medium.ttf')))
          ..addFont(Future.value(font('Roboto-Black.ttf'))))
        .load();
  });

  test('launcher icons', () async {
    const sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final entry in sizes.entries) {
      await _save('android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png', entry.value,
          entry.value, (c) => _paintIcon(c, entry.value.toDouble()));
    }
    await _save('store/icon_512.png', 512, 512, (c) => _paintIcon(c, 512));
  });

  test('feature graphic', () async {
    await _save('store/feature_graphic.png', 1024, 500, _paintFeatureGraphic);
  });
}
