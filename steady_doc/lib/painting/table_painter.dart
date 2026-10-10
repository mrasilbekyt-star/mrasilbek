import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../game/geometry.dart';
import '../game/levels.dart';
import '../game/session.dart';
import '../game/stages.dart';
import '../l10n/strings.dart';
import 'art.dart';
import 'emoji.dart';
import 'scene_painter.dart';

/// How the 1000 x 1400 design canvas is scaled and centered on screen.
class DesignFit {
  DesignFit(Size size)
      : scale = math.min(size.width / BodyLayout.design.width,
            size.height / BodyLayout.design.height),
        offset = Offset.zero {
    offset = Offset(
      (size.width - BodyLayout.design.width * scale) / 2,
      (size.height - BodyLayout.design.height * scale) / 2,
    );
  }

  final double scale;
  Offset offset;

  Offset toDesign(Offset local) => (local - offset) / scale;
}

/// Draws the operating field for a [GameSession], using photos from
/// [ArtAssets] where they exist and drawn graphics everywhere else.
class TablePainter extends CustomPainter {
  TablePainter(this.session, this.strings, this.art) : super(repaint: session);

  final GameSession session;
  final Strings strings;
  final ArtAssets art;

  static final _emoji = EmojiPainter();

  static const _full = Rect.fromLTWH(0, 0, 1000, 1400);
  static const _marker = Color(0xFF6B3FA0);
  static const _suture = Color(0xFF15181C);

  /// Opened part of the abdomen during extraction.
  static final Rect _cavity = BodyLayout.workZone.inflate(18);

  double get _t => session.now;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = DesignFit(size);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0B1714));
    canvas.save();
    canvas.translate(fit.offset.dx, fit.offset.dy);
    canvas.scale(fit.scale);
    canvas.clipRect(_full);

    final stage = session.stage;
    _paintScene(canvas, opened: stage is ExtractStage);
    _paintTrayContents(canvas);

    final inject = session.stages.whereType<InjectStage>().firstOrNull;
    if (inject != null && stage is InjectStage) _paintSyringe(canvas, inject);

    if (session.cutDone && stage is! ExtractStage) {
      _paintIncision(canvas, session.layout.cut.points, healed: session.stitchDone);
    }
    if (session.stitchDone) _paintSutures(canvas, session.layout.stitchTargets);

    switch (stage) {
      case XrayStage():
        _paintSkinMarks(canvas, stage.items);
        _paintXray(canvas, stage);
      case CutStage():
        _paintSkinMarks(canvas, session.stages.whereType<XrayStage>().first.items);
        _paintCut(canvas, stage);
      case ExtractStage():
        _paintExtraction(canvas, stage);
      case StitchStage():
        _paintStitching(canvas, stage);
      case InjectStage():
        break;
    }

    _paintHoverAim(canvas);
    _paintFloats(canvas);
    _paintVignette(canvas);
    canvas.restore();
  }

  // ----------------------------------------------------------------- scene

  void _paintScene(Canvas canvas, {required bool opened}) {
    final closed = art.sceneClosed;
    if (closed != null) {
      drawCover(canvas, closed, _full);
    } else {
      paintClosedScene(canvas, session.level);
    }
    if (!opened) return;
    final open = art.sceneOpen;
    if (open != null) {
      drawCover(canvas, open, _full);
      return;
    }
    // Retracted wound edges around the drawn organs.
    final rr = RRect.fromRectAndRadius(_cavity, const Radius.circular(70));
    canvas.drawRRect(rr.inflate(16),
        Paint()
          ..color = Color.lerp(session.level.skin, const Color(0xFF8A3B2E), 0.45)!);
    paintOrgans(canvas, session.level, _cavity);
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0x88200508)],
          stops: [0.6, 1],
        ).createShader(_cavity),
    );
  }

  void _paintVignette(Canvas canvas) {
    canvas.drawRect(
      _full,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.95,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x99000000)],
          stops: [0, 0.6, 1],
        ).createShader(_full),
    );
  }

  // --------------------------------------------------------------- findings

  void _paintFinding(Canvas canvas, String id, Offset at, double size,
      {bool silhouette = false, double opacity = 1}) {
    final image = art.finding(id);
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..color = Color.fromRGBO(0, 0, 0, opacity);
    if (silhouette) {
      paint.colorFilter = const ColorFilter.mode(Color(0xF2EEF4F8), BlendMode.srcIn);
    }
    if (image != null) {
      if (!silhouette && opacity >= 1) {
        // Soft contact shadow so the object sits in the tissue.
        canvas.drawOval(
          Rect.fromCenter(center: at + const Offset(6, 10), width: size * 0.8, height: size * 0.5),
          Paint()
            ..color = const Color(0x66000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      drawContained(canvas, image, at, size, paint: paint);
    } else {
      _emoji.paint(canvas, findingEmoji[id] ?? '❓', at, size * 0.85,
          filter: paint.colorFilter, opacity: opacity);
    }
  }

  void _paintTrayContents(Canvas canvas) {
    final extract = session.stages.whereType<ExtractStage>().first;
    final tray = BodyLayout.tray.deflate(30);
    var slot = 0;
    for (final item in extract.items) {
      if (!item.extracted) continue;
      final p = Offset(tray.left + 40 + (slot % 3) * 55, tray.top + 45 + (slot ~/ 3) * 70);
      _paintFinding(canvas, item.id, p, 58);
      slot++;
    }
  }

  // ---------------------------------------------------------------- inject

  void _paintSyringe(Canvas canvas, InjectStage stage) {
    const x = BodyLayout.syringeX;
    const barrelTop = BodyLayout.plungerStart + 30;
    const barrelBottom = BodyLayout.plungerEnd + 40;
    final handleY = stage.handleY;
    final rubberY = handleY + 30;
    final barrel = RRect.fromLTRBR(x - 30, barrelTop, x + 30, barrelBottom, const Radius.circular(8));

    // Drop shadow on the drapes.
    canvas.drawRRect(
      RRect.fromLTRBR(x - 30, handleY - 14, x + 30, BodyLayout.needleTipY, const Radius.circular(10))
          .shift(const Offset(14, 16)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Needle hub and needle into the IV port.
    canvas.drawRect(Rect.fromLTRB(x - 10, barrelBottom, x + 10, barrelBottom + 26),
        Paint()..color = const Color(0xFFE6ECEF));
    canvas.drawLine(
      const Offset(x, barrelBottom + 26),
      const Offset(x, BodyLayout.needleTipY),
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFF5F7F8), Color(0xFF8C969D)])
            .createShader(const Rect.fromLTWH(x - 3, 0, 6, 10))
        ..strokeWidth = 5,
    );

    // Medicine left in the barrel.
    canvas.drawRect(Rect.fromLTRB(x - 27, rubberY, x + 27, barrelBottom - 2),
        Paint()..color = const Color(0x8CCFE9F5));
    // Glass barrel with reflections.
    canvas.drawRRect(
      barrel,
      Paint()
        ..shader = const LinearGradient(colors: [
          Color(0x55FFFFFF),
          Color(0x10FFFFFF),
          Color(0x33FFFFFF),
          Color(0x08FFFFFF),
        ], stops: [0, 0.35, 0.7, 1])
            .createShader(barrel.outerRect),
    );
    canvas.drawRRect(
        barrel,
        Paint()
          ..color = const Color(0xCCDDE6EA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    final tick = Paint()
      ..color = const Color(0xCC2B3238)
      ..strokeWidth = 2;
    for (var i = 1; i < 10; i++) {
      final y = barrelTop + (barrelBottom - barrelTop) * i / 10;
      canvas.drawLine(Offset(x - 30, y), Offset(x - (i.isEven ? 12 : 20), y), tick);
    }
    // Flange.
    canvas.drawRRect(
      RRect.fromLTRBR(x - 52, barrelTop - 8, x + 52, barrelTop + 4, const Radius.circular(5)),
      Paint()..color = const Color(0xE6E9EEF1),
    );
    // Plunger rod, black rubber and thumb rest.
    canvas.drawRect(Rect.fromLTRB(x - 7, handleY, x + 7, rubberY),
        Paint()..color = const Color(0xF2F2F4F5));
    canvas.drawRRect(
      RRect.fromLTRBR(x - 27, rubberY - 10, x + 27, rubberY + 6, const Radius.circular(4)),
      Paint()..color = const Color(0xFF1E2226),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(x - 46, handleY - 14, x + 46, handleY + 4, const Radius.circular(9)),
      Paint()..color = stage.grabbed ? const Color(0xFFFFFFFF) : const Color(0xFFDDE3E6),
    );

    // Hint: push down.
    if (!stage.grabbed && stage.progress < 0.05) {
      final bounce = 10 * math.sin(_t * 5);
      final arrow = Paint()
        ..color = const Color(0xCCFFFFFF)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      const ax = x + 92;
      final top = handleY + bounce;
      canvas.drawLine(Offset(ax, top), Offset(ax, top + 100), arrow);
      canvas.drawPath(
        Path()
          ..moveTo(ax - 18, top + 80)
          ..lineTo(ax, top + 102)
          ..lineTo(ax + 18, top + 80),
        arrow,
      );
    }

    // Flow meter: green is safe, red hurts.
    final gauge = Rect.fromLTRB(x + 64, barrelTop, x + 76, barrelBottom);
    canvas.drawRRect(RRect.fromRectAndRadius(gauge, const Radius.circular(6)),
        Paint()..color = const Color(0x66000000));
    final ratio = (stage.speed / stage.speedLimit).clamp(0.0, 1.3) / 1.3;
    final color = ratio < 0.55
        ? const Color(0xFF39D98A)
        : ratio < 0.77
            ? const Color(0xFFFFC145)
            : const Color(0xFFFF4D4D);
    canvas.drawRRect(
      RRect.fromLTRBR(gauge.left, gauge.bottom - gauge.height * ratio, gauge.right, gauge.bottom,
          const Radius.circular(6)),
      Paint()..color = color,
    );
  }

  // ----------------------------------------------------------------- x-ray

  void _paintXray(Canvas canvas, XrayStage stage) {
    final lens = stage.lens;
    if (lens == null) {
      _dashedCircle(canvas, BodyLayout.workZone.center, 80 + 6 * math.sin(_t * 3),
          const Color(0x88FFFFFF), dashes: 24, width: 3);
      return;
    }
    const radius = XrayStage.lensRadius;
    final bounds = Rect.fromCircle(center: lens, radius: radius);
    canvas.save();
    canvas.clipPath(Path()..addOval(bounds));
    final film = art.sceneXray;
    if (film != null) {
      drawCover(canvas, film, _full);
    } else {
      _paintDrawnXray(canvas, bounds);
    }
    for (final item in stage.items) {
      _paintFinding(canvas, item.id, item.pos, 82, silhouette: true);
    }
    canvas.restore();

    // Lens housing.
    canvas.drawCircle(lens, radius + 2,
        Paint()
          ..color = const Color(0xFFB9C3C9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7);
    canvas.drawCircle(lens, radius + 8,
        Paint()
          ..color = const Color(0x88000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);

    for (final item in stage.items) {
      if (item.found || item.dwell <= 0) continue;
      final sweep = 2 * math.pi * (item.dwell / XrayStage.dwellTime).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: item.pos, radius: 60),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = const Color(0xFF39D98A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintDrawnXray(Canvas canvas, Rect bounds) {
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF050607));
    canvas.drawRRect(skinWindow.inflate(120),
        Paint()
          ..color = const Color(0xFF2A2E31)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));
    final soft = Paint()
      ..color = const Color(0x33A0A8AE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawPath(
      Path()
        ..moveTo(330, 760)
        ..quadraticBezierTo(500, 640, 670, 760)
        ..quadraticBezierTo(700, 950, 520, 980)
        ..quadraticBezierTo(330, 1000, 360, 860),
      soft,
    );
    final bone = Paint()
      ..color = const Color(0xFFDDE3E8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var y = 430.0; y < 1100; y += 52) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(500, y), width: 62, height: 40),
            const Radius.circular(10)),
        bone,
      );
    }
    final rib = Paint()
      ..color = const Color(0xCCD3DAE0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var y = 440.0; y < 700; y += 58) {
      canvas.drawPath(
        Path()
          ..moveTo(470, y)
          ..quadraticBezierTo(300, y - 20, 250, y + 110)
          ..moveTo(530, y)
          ..quadraticBezierTo(700, y - 20, 750, y + 110),
        rib,
      );
    }
    // Pelvis.
    canvas.drawPath(
      Path()
        ..moveTo(290, 1080)
        ..quadraticBezierTo(320, 1250, 470, 1290)
        ..moveTo(710, 1080)
        ..quadraticBezierTo(680, 1250, 530, 1290),
      Paint()
        ..color = const Color(0xCCD3DAE0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  /// Purple skin-marker circles where the X-ray found something.
  void _paintSkinMarks(Canvas canvas, List<HiddenItem> items) {
    for (final item in items) {
      if (!item.found) continue;
      _dashedCircle(canvas, item.pos, 48, _marker.withValues(alpha: 0.85), width: 4);
      final x = Paint()
        ..color = _marker.withValues(alpha: 0.85)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(item.pos + const Offset(-12, -12), item.pos + const Offset(12, 12), x);
      canvas.drawLine(item.pos + const Offset(-12, 12), item.pos + const Offset(12, -12), x);
    }
  }

  // ------------------------------------------------------------------- cut

  void _paintCut(Canvas canvas, CutStage stage) {
    final path = stage.path;
    // Surgical marker line for the rest of the cut.
    final dash = Paint()
      ..color = _marker.withValues(alpha: 0.9)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var s = stage.done; s < path.length; s += 26) {
      canvas.drawLine(path.at(s), path.at(math.min(s + 14, path.length)), dash);
    }
    if (stage.done > 0) {
      _paintIncision(canvas, path.pointsUntil(stage.done), healed: false);
    }
    if (!stage.cutting && !stage.isComplete) {
      final p = stage.resumePoint;
      canvas.drawCircle(p, 20 + 4 * math.sin(_t * 6),
          Paint()
            ..color = const Color(0xCCFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
      canvas.drawCircle(p, 6, Paint()..color = const Color(0xFFFFFFFF));
    }
    final pen = stage.pen;
    if (pen != null) _paintScalpel(canvas, path.at(stage.done), path.tangentAt(stage.done));
  }

  void _paintIncision(Canvas canvas, List<Offset> pts, {required bool healed}) {
    if (pts.length < 2) return;
    final path = _pathOf(pts);
    // Swollen skin edges.
    canvas.drawPath(path, _stroke(const Color(0x55C0503C), healed ? 12 : 22, blur: 4));
    // The wound itself.
    canvas.drawPath(path, _stroke(const Color(0xFF4A0A0E), healed ? 4 : 9));
    canvas.drawPath(path, _stroke(const Color(0xFF8E1A20), healed ? 2 : 4));
    if (healed) return;
    // Beads of blood along the cut.
    final line = Polyline(pts);
    final rnd = math.Random(session.level.seed);
    for (var s = 18.0; s < line.length; s += 34 + rnd.nextDouble() * 20) {
      final side = rnd.nextBool() ? 1.0 : -1.0;
      final p = line.at(s) + line.normalAt(s) * (side * (3 + rnd.nextDouble() * 4));
      final r = 3.5 + rnd.nextDouble() * 4;
      canvas.drawCircle(p, r, Paint()..color = const Color(0xFF6E0C12));
      canvas.drawCircle(p - Offset(r * 0.3, r * 0.3), r * 0.35, Paint()..color = const Color(0x88FFB0A8));
    }
  }

  void _paintScalpel(Canvas canvas, Offset tip, Offset direction) {
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    // Hold the scalpel up and to the right of the cut, like a right hand would.
    canvas.rotate(math.atan2(direction.dy, direction.dx) + math.pi * 0.85);
    canvas.drawRRect(
      RRect.fromLTRBR(40, -10, 300, 10, const Radius.circular(6)).shift(const Offset(10, 14)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final blade = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(20, -18, 60, -10)
      ..lineTo(60, 8)
      ..quadraticBezierTo(30, 8, 0, 0)
      ..close();
    canvas.drawPath(
      blade,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7F9FA), Color(0xFF9AA4AB)],
        ).createShader(const Rect.fromLTWH(0, -18, 60, 26)),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(56, -9, 300, 9, const Radius.circular(5)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3E8EB), Color(0xFF7D878E), Color(0xFFC4CCD1)],
        ).createShader(const Rect.fromLTWH(56, -9, 244, 18)),
    );
    canvas.restore();
  }

  // --------------------------------------------------------------- extract

  void _paintExtraction(Canvas canvas, ExtractStage stage) {
    // Channels between the organs that the objects can slide through.
    final hasPhoto = art.sceneOpen != null;
    for (final item in stage.items) {
      if (item.extracted) continue;
      final path = _pathOf(item.corridor.points);
      canvas.drawPath(path, _stroke(Color.fromRGBO(255, 214, 205, hasPhoto ? 0.35 : 0.55), stage.width + 10));
      canvas.drawPath(path, _stroke(Color.fromRGBO(40, 6, 10, hasPhoto ? 0.55 : 0.9), stage.width));
      canvas.drawPath(path,
          _stroke(const Color(0x22FFFFFF), stage.width * 0.3, blur: 6));
    }
    // Opening to pull objects out through.
    canvas.drawCircle(stage.exit, ExtractStage.exitRadius + 6, Paint()..color = const Color(0xFF14030A));
    _dashedCircle(canvas, stage.exit, ExtractStage.exitRadius + 14 + 3 * math.sin(_t * 4),
        const Color(0xCC39D98A), width: 4);

    for (var i = 0; i < stage.items.length; i++) {
      final item = stage.items[i];
      if (item.extracted) continue;
      final held = stage.grabbed == i;
      _paintFinding(canvas, item.id, item.pos, held ? 86 : 80);
      if (held) _paintForceps(canvas, item.pos);
    }
  }

  void _paintForceps(Canvas canvas, Offset at) {
    final photo = art.forceps;
    if (photo != null) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(0.45);
      const h = 420.0;
      final w = h * photo.width / photo.height;
      canvas.drawImageRect(photo, Offset.zero & Size(photo.width.toDouble(), photo.height.toDouble()),
          Rect.fromLTWH(-w / 2, -h, w, h), Paint()..filterQuality = FilterQuality.high);
      canvas.restore();
      return;
    }
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(0.45);
    final shadow = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRect(const Rect.fromLTRB(-4, -380, 34, -20).shift(const Offset(16, 12)), shadow);
    for (final side in [-1.0, 1.0]) {
      final prong = Path()
        ..moveTo(side * 12, -6)
        ..lineTo(side * 7, -60)
        ..lineTo(side * 16, -380)
        ..lineTo(side * 28, -380)
        ..lineTo(side * 18, -60)
        ..close();
      canvas.drawPath(
        prong,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF4F6F7), Color(0xFF7F8A91), Color(0xFFD0D7DB)],
          ).createShader(const Rect.fromLTRB(-30, -380, 30, 0)),
      );
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------- stitch

  void _paintStitching(Canvas canvas, StitchStage stage) {
    final targets = stage.targets;
    if (stage.stitched > 1) _paintSutures(canvas, targets.sublist(0, stage.stitched));
    final pen = stage.pen;
    if (stage.drawing && pen != null && stage.stitched > 0) {
      canvas.drawPath(_pathOf([targets[stage.stitched - 1], pen]), _stroke(_suture, 3.5));
      _paintNeedle(canvas, pen);
    }
    for (var i = stage.stitched; i < targets.length; i++) {
      canvas.drawCircle(targets[i], 7, Paint()..color = _marker.withValues(alpha: 0.9));
    }
    if (!stage.isComplete) {
      canvas.drawCircle(
        targets[stage.stitched],
        stage.hitRadius * 0.8 + 4 * math.sin(_t * 6),
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _paintSutures(Canvas canvas, List<Offset> pts) {
    canvas.drawPath(_pathOf(pts), _stroke(const Color(0x44000000), 6, blur: 3));
    canvas.drawPath(_pathOf(pts), _stroke(_suture, 3.5));
    for (final p in pts) {
      canvas.drawCircle(p, 5, Paint()..color = _suture);
      final tail = Paint()
        ..color = _suture
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p, p + const Offset(9, -11), tail);
      canvas.drawLine(p, p + const Offset(12, -4), tail);
    }
  }

  void _paintNeedle(Canvas canvas, Offset at) {
    canvas.drawArc(
      Rect.fromCircle(center: at + const Offset(0, -18), radius: 18),
      math.pi * 0.1,
      math.pi * 0.9,
      false,
      Paint()
        ..color = const Color(0xFFDDE3E7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  // --------------------------------------------------------------- helpers

  void _paintHoverAim(Canvas canvas) {
    final hover = session.hoverPos;
    if (hover == null || session.stage is XrayStage) return;
    final aim = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(hover, 18, aim);
    for (final d in const [Offset(-1, 0), Offset(1, 0), Offset(0, -1), Offset(0, 1)]) {
      canvas.drawLine(hover + d * 10, hover + d * 30, aim);
    }
  }

  void _paintFloats(Canvas canvas) {
    for (final f in session.floats) {
      final age = _t - f.born;
      final opacity = (1 - age / 1.2).clamp(0.0, 1.0);
      final pos = f.pos - Offset(0, 50 + 60 * age);
      final text = strings.mistake(f.mistake).toUpperCase();
      TextPainter layout(Paint? stroke, Color? color) => TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                foreground: stroke,
                color: color,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
      final outline = layout(
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = Color.fromRGBO(0, 0, 0, opacity * 0.8),
        null,
      );
      final fill = layout(null, Color.fromRGBO(255, 77, 77, opacity));
      final x = (pos.dx - fill.width / 2).clamp(10.0, BodyLayout.design.width - fill.width - 10);
      final at = Offset(x, pos.dy - fill.height / 2);
      outline.paint(canvas, at);
      fill.paint(canvas, at);
    }
  }

  static Path _pathOf(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  static Paint _stroke(Color color, double width, {double blur = 0}) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    return paint;
  }

  static void _dashedCircle(Canvas canvas, Offset c, double r, Color color,
      {int dashes = 16, double width = 5}) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), 2 * math.pi * i / dashes,
          math.pi / dashes, false, paint);
    }
  }

  @override
  bool shouldRepaint(TablePainter old) =>
      old.session != session || old.strings.lang != strings.lang || old.art != art;
}
