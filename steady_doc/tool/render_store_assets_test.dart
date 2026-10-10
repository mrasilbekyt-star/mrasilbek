// Draws the launcher icons and the Play Store graphics from code.
//
//   flutter test tool/render_store_assets_test.dart
//
// Writes android/app/src/main/res/mipmap-*/ic_launcher.png and store/*.png.
// Replace store/icon_512.png with a photo-real icon later if you make one.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_doc/game/session.dart';

const _green = Color(0xFF39D98A);

Future<void> _save(String path, int w, int h, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(w, h);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void _background(Canvas c, Rect r, {Alignment center = Alignment.center}) {
  c.drawRect(
    r,
    Paint()
      ..shader = RadialGradient(
        center: center,
        radius: 1.1,
        colors: const [Color(0xFF16413A), Color(0xFF071210), Color(0xFF030706)],
        stops: const [0, 0.65, 1],
      ).createShader(r),
  );
  // Faint monitor grid.
  final grid = Paint()
    ..color = const Color(0x0F39D98A)
    ..strokeWidth = 1.5;
  for (var x = r.left; x < r.right; x += 32) {
    c.drawLine(Offset(x, r.top), Offset(x, r.bottom), grid);
  }
  for (var y = r.top; y < r.bottom; y += 32) {
    c.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
  }
}

/// A glowing ECG trace across [r], [beats] heartbeats long.
void _ecg(Canvas c, Rect r, double beats, double amplitude) {
  final path = Path();
  for (var x = r.left; x <= r.right; x += 2) {
    final phase = ((x - r.left) / r.width * beats + 0.55) % 1;
    final y = r.center.dy - GameSession.ecgWave(phase) * amplitude;
    if (x == r.left) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  for (final (width, blur, alpha) in [(26.0, 18.0, 0.35), (12.0, 6.0, 0.6), (5.0, 0.0, 1.0)]) {
    final paint = Paint()
      ..color = _green.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    if (blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    c.drawPath(path, paint);
  }
  c.drawPath(
    path,
    Paint()
      ..color = const Color(0xCCEFFFF6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
  );
}

/// A steel scalpel, tip at the origin, pointing along +x.
void _scalpel(Canvas c, double length) {
  final s = length / 360;
  c.scale(s);
  c.drawRRect(
    RRect.fromLTRBR(70, -14, 360, 14, const Radius.circular(8)).shift(const Offset(18, 26)),
    Paint()
      ..color = const Color(0x88000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
  );
  final blade = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(26, -30, 84, -16)
    ..lineTo(84, 12)
    ..quadraticBezierTo(40, 12, 0, 0)
    ..close();
  c.drawPath(
    blade,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFC9D2D8), Color(0xFF6E7A82)],
      ).createShader(const Rect.fromLTWH(0, -30, 84, 42)),
  );
  // Sharp edge highlight.
  c.drawPath(
    Path()
      ..moveTo(2, 0)
      ..quadraticBezierTo(40, 11, 82, 11),
    Paint()
      ..color = const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  final handle = RRect.fromLTRBR(78, -13, 360, 13, const Radius.circular(7));
  c.drawRRect(
    handle,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF2F5F7), Color(0xFF8F9AA2), Color(0xFF4F5960), Color(0xFFB7C1C7)],
        stops: [0, 0.45, 0.6, 1],
      ).createShader(handle.outerRect),
  );
  // Grip ridges.
  final ridge = Paint()
    ..color = const Color(0x55000000)
    ..strokeWidth = 2;
  for (var x = 230.0; x < 345; x += 9) {
    c.drawLine(Offset(x, -11), Offset(x, 11), ridge);
  }
}

void _paintIcon(Canvas c, double size) {
  c.scale(size / 512);
  const square = Rect.fromLTWH(0, 0, 512, 512);
  _background(c, square);
  _ecg(c, const Rect.fromLTRB(-20, 210, 532, 330), 1.6, 150);
  c.save();
  c.translate(150, 380);
  c.rotate(-0.72);
  _scalpel(c, 400);
  c.restore();
}

void _paintFeatureGraphic(Canvas c) {
  const rect = Rect.fromLTWH(0, 0, 1024, 500);
  _background(c, rect, center: const Alignment(-0.5, 0));
  _ecg(c, const Rect.fromLTRB(-20, 300, 1044, 400), 4.2, 130);
  c.save();
  c.translate(120, 330);
  c.rotate(-0.55);
  _scalpel(c, 360);
  c.restore();

  void text(String s, Offset at, double size, FontWeight weight, Color color,
      {double spacing = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: spacing,
          shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 12)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at);
  }

  text('STEADY DOC', const Offset(440, 70), 78, FontWeight.w900, Colors.white, spacing: 6);
  text('Realistic surgery simulator', const Offset(446, 170), 34, FontWeight.w500,
      const Color(0xFFCFE8E1));
  text('Made for the S Pen', const Offset(446, 214), 34, FontWeight.w500, _green);
  text('HR 72   SpO2 99%   NIBP 118/76', const Offset(446, 430), 24, FontWeight.w500,
      const Color(0x9939D98A), spacing: 1);
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
