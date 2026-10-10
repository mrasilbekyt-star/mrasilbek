import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../game/levels.dart';

/// The exposed patch of skin between the drapes.
final RRect skinWindow = BodyLayout.torso;

/// Draws [image] over [dst], cropping it to fill without stretching.
void drawCover(Canvas canvas, ui.Image image, Rect dst, {Paint? paint}) {
  final iw = image.width.toDouble();
  final ih = image.height.toDouble();
  final scale = math.max(dst.width / iw, dst.height / ih);
  final sw = dst.width / scale;
  final sh = dst.height / scale;
  final src = Rect.fromLTWH((iw - sw) / 2, (ih - sh) / 2, sw, sh);
  canvas.drawImageRect(image, src, dst, paint ?? (Paint()..filterQuality = FilterQuality.high));
}

/// Draws [image] fitted inside a square of [size] around [center].
void drawContained(Canvas canvas, ui.Image image, Offset center, double size, {Paint? paint}) {
  final iw = image.width.toDouble();
  final ih = image.height.toDouble();
  final scale = size / math.max(iw, ih);
  final dst = Rect.fromCenter(center: center, width: iw * scale, height: ih * scale);
  canvas.drawImageRect(image, Offset.zero & Size(iw, ih), dst,
      paint ?? (Paint()..filterQuality = FilterQuality.high));
}

final Map<int, ui.Picture> _closedCache = {};
final Map<int, ui.Picture> _organCache = {};

ui.Picture _record(void Function(Canvas) draw) {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  return recorder.endRecording();
}

/// Drapes and the prepped skin, drawn in code (cached per patient).
void paintClosedScene(Canvas canvas, LevelDef level) {
  canvas.drawPicture(_closedCache.putIfAbsent(level.number, () => _record((c) => _closed(c, level))));
}

/// Loops of bowel inside the opened abdomen, drawn in code (cached per patient).
void paintOrgans(Canvas canvas, LevelDef level, Rect area) {
  canvas.drawPicture(
      _organCache.putIfAbsent(level.number, () => _record((c) => _organs(c, level, area))));
}

void _closed(Canvas c, LevelDef level) {
  const full = Rect.fromLTWH(0, 0, 1000, 1400);

  // Sterile drapes with soft folds.
  c.drawRect(
    full,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E6B60), Color(0xFF214F47), Color(0xFF2A6156)],
      ).createShader(full),
  );
  final rnd = math.Random(level.seed);
  for (var i = 0; i < 14; i++) {
    final x = rnd.nextDouble() * 1000;
    final w = 30 + rnd.nextDouble() * 70;
    c.save();
    c.translate(x, 700);
    c.rotate((rnd.nextDouble() - 0.5) * 0.5);
    final fold = Rect.fromLTWH(-w / 2, -1000, w, 2000);
    c.drawRect(
      fold,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0x00000000),
            Color.fromRGBO(255, 255, 255, 0.05 + rnd.nextDouble() * 0.05),
            const Color(0x22000000),
            const Color(0x00000000),
          ],
          stops: const [0, 0.45, 0.6, 1],
        ).createShader(fold),
    );
    c.restore();
  }

  // Shadow where the drapes overlap the skin.
  c.drawRRect(skinWindow.inflate(14),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

  // Skin, prepped with iodine.
  final skin = level.skin;
  final rect = skinWindow.outerRect;
  c.drawRRect(skinWindow, Paint()..color = skin);
  c.drawRRect(
    skinWindow,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.1),
        radius: 0.85,
        colors: [
          const Color(0x33B5651D),
          const Color(0x66A0521A),
          Color.lerp(skin, const Color(0xFF3A2010), 0.55)!.withValues(alpha: 0.75),
        ],
        stops: const [0.2, 0.7, 1],
      ).createShader(rect),
  );
  // Fine texture: pores and uneven antiseptic.
  for (var i = 0; i < 900; i++) {
    final p = Offset(rect.left + rnd.nextDouble() * rect.width, rect.top + rnd.nextDouble() * rect.height);
    if (!skinWindow.contains(p)) continue;
    c.drawCircle(
      p,
      0.8 + rnd.nextDouble() * 1.6,
      Paint()
        ..color = rnd.nextBool() ? const Color(0x14000000) : const Color(0x10FFFFFF),
    );
  }
  for (var i = 0; i < 18; i++) {
    final p = Offset(rect.left + rnd.nextDouble() * rect.width, rect.top + rnd.nextDouble() * rect.height);
    c.drawCircle(
      p,
      30 + rnd.nextDouble() * 80,
      Paint()
        ..color = const Color(0x12A0521A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
  }
  // Costal margin.
  final crease = Paint()
    ..color = const Color(0x22000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  c.drawPath(
    Path()
      ..moveTo(200, 470)
      ..quadraticBezierTo(380, 330, 500, 360)
      ..quadraticBezierTo(620, 330, 800, 470),
    crease,
  );

  // Drape edge and towel clips.
  c.drawRRect(
    skinWindow,
    Paint()
      ..color = const Color(0xFF1C443D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6,
  );
  for (final corner in [
    rect.topLeft + const Offset(26, 26),
    rect.topRight + const Offset(-26, 26),
    rect.bottomLeft + const Offset(26, -26),
    rect.bottomRight + const Offset(-26, -26),
  ]) {
    _towelClip(c, corner);
  }

  // Steel kidney dish for the findings.
  _kidneyDish(c, BodyLayout.tray);
}

void _towelClip(Canvas c, Offset at) {
  final steel = Paint()
    ..shader = const LinearGradient(colors: [Color(0xFFE8EDF0), Color(0xFF7B8790)])
        .createShader(Rect.fromCircle(center: at, radius: 20));
  c.drawCircle(at + const Offset(3, 4), 15, Paint()..color = const Color(0x55000000));
  c.drawCircle(at, 14, steel);
  c.drawCircle(at, 6, Paint()..color = const Color(0xFF55606A));
}

void _kidneyDish(Canvas c, Rect r) {
  final rr = RRect.fromRectAndRadius(r, const Radius.circular(60));
  c.drawRRect(rr.shift(const Offset(6, 10)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
  c.drawRRect(
    rr,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF4F7F9), Color(0xFF9AA6AE), Color(0xFFD5DCE1)],
      ).createShader(r),
  );
  c.drawRRect(
    rr.deflate(14),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [Color(0xFFE9EEF1), Color(0xFF8D99A2)],
      ).createShader(r),
  );
}

void _organs(Canvas c, LevelDef level, Rect area) {
  final rnd = math.Random(level.seed ^ 0x5eed);
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(area, const Radius.circular(70)));
  // Deep cavity.
  c.drawRect(
    area,
    Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF8A2A2E), Color(0xFF4A1014)],
      ).createShader(area),
  );
  // Loops of small bowel: thick wet tubes wandering around.
  for (var loop = 0; loop < 16; loop++) {
    var p = Offset(area.left + rnd.nextDouble() * area.width, area.top + rnd.nextDouble() * area.height);
    var heading = rnd.nextDouble() * math.pi * 2;
    final path = Path()..moveTo(p.dx, p.dy);
    for (var step = 0; step < 14; step++) {
      heading += (rnd.nextDouble() - 0.5) * 1.6;
      p += Offset(math.cos(heading), math.sin(heading)) * 34;
      if (!area.inflate(30).contains(p)) heading += math.pi;
      path.lineTo(p.dx, p.dy);
    }
    final width = 46 + rnd.nextDouble() * 18;
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xAA3A0C10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    c.drawPath(
      path,
      Paint()
        ..color = Color.lerp(const Color(0xFFC8706A), const Color(0xFFD98C7E), rnd.nextDouble())!
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Wet highlight along each loop.
    c.drawPath(
      path.shift(Offset(-width * 0.18, -width * 0.18)),
      Paint()
        ..color = const Color(0x55FFE3DA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.22
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }
  // Fine blood vessels.
  for (var v = 0; v < 22; v++) {
    var p = Offset(area.left + rnd.nextDouble() * area.width, area.top + rnd.nextDouble() * area.height);
    final path = Path()..moveTo(p.dx, p.dy);
    for (var s = 0; s < 5; s++) {
      p += Offset((rnd.nextDouble() - 0.5) * 50, (rnd.nextDouble() - 0.5) * 50);
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0x667A1020)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
  c.restore();
}
