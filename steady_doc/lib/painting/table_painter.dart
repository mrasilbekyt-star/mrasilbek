import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../game/levels.dart';
import '../game/session.dart';
import '../game/stages.dart';
import '../l10n/strings.dart';
import 'emoji.dart';
import 'patient_painter.dart';

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

/// Draws the whole operating table for a [GameSession].
class TablePainter extends CustomPainter {
  TablePainter(this.session, this.strings) : super(repaint: session);

  final GameSession session;
  final Strings strings;

  static final _emoji = EmojiPainter();

  static const _thread = Color(0xFF6A3FC8);
  static const _incision = Color(0xFFB0304A);
  static const _guide = Color(0xFF1F6F8B);

  double get _t => session.now;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = DesignFit(size);
    canvas.save();
    canvas.translate(fit.offset.dx, fit.offset.dy);
    canvas.scale(fit.scale);

    final level = session.level;
    paintBody(canvas, level);
    paintFace(
      canvas,
      session.stress,
      _t,
      switch (session.state) {
        SessionState.failed => Mood.fainted,
        SessionState.won => Mood.happy,
        _ => Mood.normal,
      },
    );

    _paintTray(canvas);
    final stage = session.stage;

    final inject = session.stages.whereType<InjectStage>().firstOrNull;
    if (inject != null) {
      if (stage is InjectStage) {
        _paintSyringe(canvas, inject);
      } else {
        _paintBandAid(canvas);
      }
    }

    if (session.extractDone) {
      _paintClosedIncision(canvas, stitched: session.stitchDone);
    }

    switch (stage) {
      case XrayStage():
        _paintFoundMarkers(canvas, stage.items);
        _paintXray(canvas, stage);
      case CutStage():
        final xray = session.stages.whereType<XrayStage>().first;
        _paintFoundMarkers(canvas, xray.items);
        _paintCut(canvas, stage);
      case ExtractStage():
        _paintCavity(canvas, stage);
      case StitchStage():
        _paintStitches(canvas, stage);
      case InjectStage():
        break;
    }

    _paintHoverAim(canvas);
    _paintFloats(canvas);
    canvas.restore();
  }

  // ---------------------------------------------------------------- inject

  void _paintSyringe(Canvas canvas, InjectStage stage) {
    const x = BodyLayout.syringeX;
    const barrelTop = BodyLayout.plungerStart + 30;
    const barrelBottom = BodyLayout.plungerEnd + 40;
    final barrel = RRect.fromLTRBR(x - 34, barrelTop, x + 34, barrelBottom, const Radius.circular(10));
    final handleY = stage.handleY;

    // Needle into the arm.
    canvas.drawLine(
      const Offset(x, barrelBottom + 20),
      const Offset(x, BodyLayout.needleTipY),
      Paint()
        ..color = const Color(0xFF9AA5AD)
        ..strokeWidth = 6,
    );
    canvas.drawRect(Rect.fromLTRB(x - 12, barrelBottom, x + 12, barrelBottom + 24),
        Paint()..color = const Color(0xFF7D8A93));

    // Medicine left in the barrel.
    final rubberY = handleY + 30;
    canvas.drawRect(Rect.fromLTRB(x - 30, rubberY, x + 30, barrelBottom - 2),
        Paint()..color = const Color(0xCC6EC6FF));
    // Barrel glass.
    canvas.drawRRect(barrel, Paint()..color = const Color(0x33FFFFFF));
    canvas.drawRRect(
        barrel,
        Paint()
          ..color = const Color(0xFF5B6B75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
    for (var i = 1; i < 6; i++) {
      final y = barrelTop + (barrelBottom - barrelTop) * i / 6;
      canvas.drawLine(Offset(x - 34, y), Offset(x - 16, y),
          Paint()
            ..color = const Color(0xFF5B6B75)
            ..strokeWidth = 3);
    }
    // Plunger rod, rubber and handle.
    canvas.drawRect(Rect.fromLTRB(x - 8, handleY, x + 8, rubberY),
        Paint()..color = const Color(0xFFCFD8DC));
    canvas.drawRect(Rect.fromLTRB(x - 30, rubberY - 8, x + 30, rubberY + 4),
        Paint()..color = const Color(0xFF37474F));
    final grip = RRect.fromLTRBR(x - 58, handleY - 16, x + 58, handleY + 6, const Radius.circular(10));
    canvas.drawRRect(grip, Paint()..color = stage.grabbed ? const Color(0xFF26A69A) : const Color(0xFF455A64));

    // Hint arrow while untouched.
    if (!stage.grabbed && stage.progress < 0.05) {
      final bounce = 10 * math.sin(_t * 5);
      final arrow = Paint()
        ..color = const Color(0xFF26A69A)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final ax = x + 95;
      final top = handleY + bounce;
      canvas.drawLine(Offset(ax, top), Offset(ax, top + 110), arrow);
      canvas.drawPath(
        Path()
          ..moveTo(ax - 26, top + 84)
          ..lineTo(ax, top + 112)
          ..lineTo(ax + 26, top + 84),
        arrow,
      );
    }

    // Speed gauge: green is safe, red hurts.
    final gauge = Rect.fromLTRB(x + 70, barrelTop, x + 92, barrelBottom);
    canvas.drawRRect(RRect.fromRectAndRadius(gauge, const Radius.circular(11)),
        Paint()..color = const Color(0x33000000));
    final ratio = (stage.speed / stage.speedLimit).clamp(0.0, 1.3) / 1.3;
    final fillTop = gauge.bottom - gauge.height * ratio;
    final color = ratio < 0.55
        ? const Color(0xFF43A047)
        : ratio < 0.77
            ? const Color(0xFFFFB300)
            : const Color(0xFFE53935);
    canvas.drawRRect(
      RRect.fromLTRBR(gauge.left, fillTop, gauge.right, gauge.bottom, const Radius.circular(11)),
      Paint()..color = color,
    );
  }

  void _paintBandAid(Canvas canvas) {
    canvas.save();
    canvas.translate(BodyLayout.syringeX, BodyLayout.needleTipY);
    canvas.rotate(-0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 90, height: 34),
          const Radius.circular(17)),
      Paint()..color = const Color(0xFFE8B98A),
    );
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 30, height: 26),
        Paint()..color = const Color(0xFFF5D7B5));
    canvas.restore();
  }

  // ----------------------------------------------------------------- x-ray

  void _paintXray(Canvas canvas, XrayStage stage) {
    final lens = stage.lens;
    if (lens == null) {
      // Pulse a ring on the belly to invite scanning.
      final r = 70 + 12 * math.sin(_t * 3);
      canvas.drawCircle(
        BodyLayout.workZone.center,
        r,
        Paint()
          ..color = const Color(0x6629B6F6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8,
      );
      return;
    }
    const radius = XrayStage.lensRadius;
    final bounds = Rect.fromCircle(center: lens, radius: radius);
    canvas.save();
    canvas.clipPath(Path()..addOval(bounds));
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF0B1E3A));
    final tissue = Paint()..color = const Color(0xFF173A66);
    canvas.drawRRect(BodyLayout.torso, tissue);
    for (final arm in [BodyLayout.leftArm, BodyLayout.rightArm]) {
      canvas.drawRRect(RRect.fromRectAndRadius(arm, const Radius.circular(55)), tissue);
    }
    canvas.drawCircle(BodyLayout.headCenter, BodyLayout.headRadius, tissue);

    // Bones.
    final bone = Paint()
      ..color = const Color(0xFFBFD9F2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    for (var y = 430.0; y < 1220; y += 46) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(500, y), width: 46, height: 34),
            const Radius.circular(8)),
        Paint()..color = const Color(0xFFBFD9F2),
      );
    }
    for (var y = 480.0; y < 820; y += 56) {
      canvas.drawPath(
        Path()
          ..moveTo(490, y)
          ..quadraticBezierTo(330, y - 10, 300, y + 70)
          ..moveTo(510, y)
          ..quadraticBezierTo(670, y - 10, 700, y + 70),
        bone,
      );
    }
    for (final arm in [BodyLayout.leftArm, BodyLayout.rightArm]) {
      canvas.drawLine(Offset(arm.center.dx, arm.top + 30), Offset(arm.center.dx, arm.bottom - 20), bone);
    }

    for (final item in stage.items) {
      _emoji.paint(canvas, item.emoji, item.pos, 74, filter: xrayFilter);
    }
    canvas.restore();

    // Lens rim.
    canvas.drawCircle(
        lens,
        radius,
        Paint()
          ..color = const Color(0xFFE3F2FD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8);
    canvas.drawCircle(
        lens,
        radius + 7,
        Paint()
          ..color = const Color(0x6629B6F6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6);

    // Progress ring while holding over an object.
    for (final item in stage.items) {
      if (item.found || item.dwell <= 0) continue;
      final sweep = 2 * math.pi * (item.dwell / XrayStage.dwellTime).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: item.pos, radius: 58),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = const Color(0xFF00E676)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintFoundMarkers(Canvas canvas, List<HiddenItem> items) {
    for (final item in items) {
      if (!item.found) continue;
      _dashedCircle(canvas, item.pos, 50, const Color(0xFF00897B));
      _emoji.paint(canvas, item.emoji, item.pos, 40, opacity: 0.55);
    }
  }

  // ------------------------------------------------------------------- cut

  void _paintCut(Canvas canvas, CutStage stage) {
    final path = stage.path;
    // Dotted guide for the rest of the cut.
    final dot = Paint()..color = _guide;
    for (var s = stage.done; s <= path.length; s += 22) {
      canvas.drawCircle(path.at(s), 5, dot);
    }
    // Finish flag.
    final end = path.end;
    canvas.drawCircle(end, 16, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(end, 16,
        Paint()
          ..color = _guide
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
    // What has been cut.
    if (stage.done > 0) {
      _polyline(canvas, path.pointsUntil(stage.done), _incision, 9);
    }
    // Where to (re)start.
    if (!stage.cutting && !stage.isComplete) {
      final p = stage.resumePoint;
      final r = 24 + 6 * math.sin(_t * 6);
      canvas.drawCircle(p, r, Paint()..color = const Color(0xAA00C853));
      canvas.drawCircle(p, 10, Paint()..color = const Color(0xFFFFFFFF));
    }
  }

  void _paintClosedIncision(Canvas canvas, {required bool stitched}) {
    final cut = session.layout.cut;
    _polyline(canvas, cut.points, _incision, stitched ? 6 : 10);
    if (stitched) {
      _polyline(canvas, session.layout.stitchTargets, _thread, 5);
    }
  }

  // --------------------------------------------------------------- extract

  void _paintCavity(Canvas canvas, ExtractStage stage) {
    final zone = RRect.fromRectAndRadius(
        BodyLayout.workZone.inflate(18), const Radius.circular(70));
    // Skin flaps around the opening.
    canvas.drawRRect(zone.inflate(14), Paint()..color = _shade(session.level.skin));
    canvas.drawRRect(zone, Paint()..color = const Color(0xFFB4435E));
    canvas.drawRRect(
      zone,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0x66400010)],
          stops: [0.55, 1],
        ).createShader(zone.outerRect),
    );

    // Safe channels.
    final width = stage.width;
    for (final item in stage.items) {
      final pts = item.corridor.points;
      _polyline(canvas, pts, const Color(0xFF7A1F36), width + 10);
      _polyline(canvas, pts, const Color(0xFFFFD3DC), width);
    }
    // Exit hole.
    canvas.drawCircle(stage.exit, ExtractStage.exitRadius + 8, Paint()..color = const Color(0xFF3A0A16));
    canvas.drawCircle(
      stage.exit,
      ExtractStage.exitRadius + 8 + 4 * math.sin(_t * 4),
      Paint()
        ..color = const Color(0xFF00E676)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    for (var i = 0; i < stage.items.length; i++) {
      final item = stage.items[i];
      if (item.extracted) continue;
      final held = stage.grabbed == i;
      _emoji.paint(canvas, item.emoji, item.pos, held ? 70 : 64);
      if (held) _paintTweezers(canvas, item.pos);
    }
  }

  void _paintTweezers(Canvas canvas, Offset at) {
    final metal = Paint()
      ..color = const Color(0xFF90A4AE)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(at + const Offset(-14, -10), at + const Offset(40, -120), metal);
    canvas.drawLine(at + const Offset(14, -10), at + const Offset(52, -116), metal);
  }

  void _paintTray(Canvas canvas) {
    const tray = BodyLayout.tray;
    canvas.drawRRect(RRect.fromRectAndRadius(tray, const Radius.circular(24)),
        Paint()..color = const Color(0xFF90A4AE));
    canvas.drawRRect(RRect.fromRectAndRadius(tray.deflate(10), const Radius.circular(18)),
        Paint()..color = const Color(0xFFCFD8DC));
    final extract = session.stages.whereType<ExtractStage>().first;
    var slot = 0;
    for (final item in extract.items) {
      if (!item.extracted) continue;
      final p = Offset(tray.left + 50 + (slot % 3) * 50, tray.top + 60 + (slot ~/ 3) * 70);
      _emoji.paint(canvas, item.emoji, p, 52);
      slot++;
    }
  }

  // ---------------------------------------------------------------- stitch

  void _paintStitches(Canvas canvas, StitchStage stage) {
    final targets = stage.targets;
    if (stage.stitched > 1) {
      _polyline(canvas, targets.sublist(0, stage.stitched), _thread, 6);
    }
    final pen = stage.pen;
    if (stage.drawing && pen != null && stage.stitched > 0) {
      _polyline(canvas, [targets[stage.stitched - 1], pen], _thread.withValues(alpha: 0.7), 5);
    }
    for (var i = 0; i < targets.length; i++) {
      final p = targets[i];
      final done = i < stage.stitched;
      canvas.drawCircle(p, 13, Paint()..color = done ? _thread : const Color(0xFFFFFFFF));
      canvas.drawCircle(
          p,
          13,
          Paint()
            ..color = _thread
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
    }
    if (!stage.isComplete) {
      final next = targets[stage.stitched];
      canvas.drawCircle(
        next,
        stage.hitRadius + 4 * math.sin(_t * 6),
        Paint()
          ..color = const Color(0xFF00C853)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
    }
  }

  // --------------------------------------------------------------- helpers

  void _paintHoverAim(Canvas canvas) {
    final hover = session.hoverPos;
    if (hover == null || session.stage is XrayStage) return;
    final aim = Paint()
      ..color = const Color(0xCC00897B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(hover, 22, aim);
    canvas.drawLine(hover + const Offset(-34, 0), hover + const Offset(-12, 0), aim);
    canvas.drawLine(hover + const Offset(12, 0), hover + const Offset(34, 0), aim);
    canvas.drawLine(hover + const Offset(0, -34), hover + const Offset(0, -12), aim);
    canvas.drawLine(hover + const Offset(0, 12), hover + const Offset(0, 34), aim);
  }

  void _paintFloats(Canvas canvas) {
    for (final f in session.floats) {
      final age = _t - f.born;
      final opacity = (1 - age / 1.2).clamp(0.0, 1.0);
      final pos = f.pos - Offset(0, 50 + 70 * age);
      final text = strings.mistake(f.mistake);
      final outline = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8
              ..color = Color.fromRGBO(255, 255, 255, opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final fill = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: Color.fromRGBO(229, 57, 53, opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      var x = pos.dx - fill.width / 2;
      x = x.clamp(10.0, BodyLayout.design.width - fill.width - 10);
      final at = Offset(x, pos.dy - fill.height / 2);
      outline.paint(canvas, at);
      fill.paint(canvas, at);
    }
  }

  static Color _shade(Color c) => Color.lerp(c, const Color(0xFF000000), 0.12)!;

  static void _polyline(Canvas canvas, List<Offset> pts, Color color, double width) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  static void _dashedCircle(Canvas canvas, Offset c, double r, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const dashes = 14;
    for (var i = 0; i < dashes; i++) {
      final a = 2 * math.pi * i / dashes;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, math.pi / dashes, false, paint);
    }
  }

  @override
  bool shouldRepaint(TablePainter old) =>
      old.session != session || old.strings.lang != strings.lang;
}
