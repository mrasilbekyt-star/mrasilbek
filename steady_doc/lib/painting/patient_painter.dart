import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../game/levels.dart';

enum Mood { normal, fainted, happy }

Color _shade(Color c, double amount) =>
    Color.lerp(c, const Color(0xFF000000), amount)!;

/// The operating table, drape and the patient's body (without the face).
void paintBody(Canvas canvas, LevelDef level) {
  final skin = level.skin;
  final skinEdge = _shade(skin, 0.18);

  // Table.
  canvas.drawRRect(
    RRect.fromLTRBR(90, 40, 910, 1440, const Radius.circular(60)),
    Paint()..color = const Color(0xFFB8C7D1),
  );
  canvas.drawRRect(
    RRect.fromLTRBR(110, 60, 890, 1440, const Radius.circular(48)),
    Paint()..color = const Color(0xFFDDE7EE),
  );

  // Pillow.
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(500, 250), width: 420, height: 190),
    Paint()..color = const Color(0xFFFFFFFF),
  );

  // Hair that falls behind the head.
  if (level.hairStyle == HairStyle.long) {
    canvas.drawRRect(
      RRect.fromLTRBR(352, 190, 648, 410, const Radius.circular(70)),
      Paint()..color = level.hair,
    );
  }

  final skinPaint = Paint()..color = skin;
  final edgePaint = Paint()
    ..color = skinEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;

  // Arms and hands.
  for (final arm in [BodyLayout.leftArm, BodyLayout.rightArm]) {
    final rr = RRect.fromRectAndRadius(arm, const Radius.circular(55));
    canvas.drawRRect(rr, skinPaint);
    canvas.drawRRect(rr, edgePaint);
    final hand = Offset(arm.center.dx, arm.bottom + 18);
    canvas.drawCircle(hand, 50, skinPaint);
    canvas.drawCircle(hand, 50, edgePaint);
  }

  // Neck.
  canvas.drawRect(const Rect.fromLTRB(448, 330, 552, 410), skinPaint);

  // Torso with soft shading towards the sides.
  final torso = BodyLayout.torso;
  canvas.drawRRect(torso, skinPaint);
  canvas.drawRRect(
    torso,
    Paint()
      ..shader = RadialGradient(
        colors: [skin.withValues(alpha: 0), skinEdge.withValues(alpha: 0.45)],
        stops: const [0.6, 1],
      ).createShader(torso.outerRect),
  );
  canvas.drawRRect(torso, edgePaint);

  // Collarbones and belly button.
  final line = Paint()
    ..color = skinEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round;
  canvas.drawPath(
    Path()
      ..moveTo(340, 445)
      ..quadraticBezierTo(420, 470, 480, 450)
      ..moveTo(520, 450)
      ..quadraticBezierTo(580, 470, 660, 445),
    line,
  );
  canvas.drawArc(Rect.fromCircle(center: const Offset(500, 1125), radius: 12),
      0.2, math.pi - 0.4, false, line);

  // Surgical drape over the legs.
  final drape = RRect.fromLTRBR(210, 1170, 790, 1440, const Radius.circular(30));
  canvas.drawRRect(drape, Paint()..color = const Color(0xFF3FA796));
  final fold = Paint()
    ..color = const Color(0xFF2E8475)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round;
  for (final x in [330.0, 500.0, 670.0]) {
    canvas.drawLine(Offset(x, 1220), Offset(x + 15, 1400), fold);
  }

  // Head and ears.
  const head = BodyLayout.headCenter;
  for (final dx in [-130.0, 130.0]) {
    canvas.drawCircle(head + Offset(dx, 12), 30, skinPaint);
    canvas.drawCircle(head + Offset(dx, 12), 30, edgePaint);
  }
  canvas.drawCircle(head, BodyLayout.headRadius, skinPaint);
  canvas.drawCircle(head, BodyLayout.headRadius, edgePaint);
  _paintHair(canvas, level);
}

void _paintHair(Canvas canvas, LevelDef level) {
  const head = BodyLayout.headCenter;
  const r = BodyLayout.headRadius;
  final hair = Paint()..color = level.hair;
  final headPath = Path()..addOval(Rect.fromCircle(center: head, radius: r + 2));

  void cap(double bottom) {
    canvas.save();
    canvas.clipPath(headPath);
    canvas.drawRect(Rect.fromLTRB(head.dx - r, head.dy - r, head.dx + r, bottom), hair);
    canvas.restore();
  }

  switch (level.hairStyle) {
    case HairStyle.short:
      cap(head.dy - 70);
      canvas.drawOval(Rect.fromLTRB(head.dx - 110, head.dy - 105, head.dx + 20, head.dy - 50), hair);
    case HairStyle.long:
      cap(head.dy - 60);
    case HairStyle.bun:
      cap(head.dy - 75);
      canvas.drawCircle(head + const Offset(0, -140), 48, hair);
    case HairStyle.spiky:
      cap(head.dy - 80);
      final spikes = Path();
      for (var i = 0; i < 7; i++) {
        final x = head.dx - 105 + i * 35;
        spikes
          ..moveTo(x - 22, head.dy - 95)
          ..lineTo(x, head.dy - 150 + (i.isEven ? 0 : 15))
          ..lineTo(x + 22, head.dy - 95);
      }
      canvas.drawPath(spikes, hair);
    case HairStyle.bald:
      canvas.drawOval(
        Rect.fromCenter(center: head + const Offset(-45, -80), width: 60, height: 26),
        Paint()..color = const Color(0x55FFFFFF),
      );
  }
}

/// The patient's face. [stress] is 0 (calm) to 1 (about to faint).
void paintFace(Canvas canvas, double stress, double time, Mood mood,
    {Offset center = BodyLayout.headCenter}) {
  final ink = Paint()
    ..color = const Color(0xFF2B1D16)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round;
  final fill = Paint()..color = const Color(0xFF2B1D16);
  final eyeL = center + const Offset(-46, -5);
  final eyeR = center + const Offset(46, -5);

  // Cheeks.
  if (stress < 0.5 && mood != Mood.fainted) {
    final cheek = Paint()..color = const Color(0x40FF5A6E);
    canvas.drawCircle(center + const Offset(-78, 40), 22, cheek);
    canvas.drawCircle(center + const Offset(78, 40), 22, cheek);
  }

  // Eyes.
  if (mood == Mood.fainted) {
    for (final e in [eyeL, eyeR]) {
      canvas.drawLine(e + const Offset(-16, -16), e + const Offset(16, 16), ink);
      canvas.drawLine(e + const Offset(-16, 16), e + const Offset(16, -16), ink);
    }
  } else if (mood == Mood.happy) {
    for (final e in [eyeL, eyeR]) {
      canvas.drawArc(Rect.fromCircle(center: e + const Offset(0, 8), radius: 18),
          math.pi + 0.3, math.pi - 0.6, false, ink);
    }
  } else {
    final blinking = (time % 3.7) < 0.13;
    if (blinking) {
      canvas.drawLine(eyeL + const Offset(-16, 0), eyeL + const Offset(16, 0), ink);
      canvas.drawLine(eyeR + const Offset(-16, 0), eyeR + const Offset(16, 0), ink);
    } else {
      final white = Paint()..color = const Color(0xFFFFFFFF);
      final size = 30 + stress * 10;
      // Nervous patients glance around.
      final look = Offset(math.sin(time * (1 + stress * 6)) * 6 * stress, 2);
      for (final e in [eyeL, eyeR]) {
        canvas.drawOval(Rect.fromCenter(center: e, width: size, height: size + 6), white);
        canvas.drawOval(Rect.fromCenter(center: e, width: size, height: size + 6),
            Paint()
              ..color = const Color(0xFF2B1D16)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
        canvas.drawCircle(e + look, 11 - stress * 3, fill);
      }
    }
  }

  // Eyebrows: they rise in the middle as the patient gets scared.
  if (mood != Mood.fainted) {
    final lift = mood == Mood.happy ? -4.0 : stress * 18;
    canvas.drawLine(eyeL + const Offset(-24, -36), eyeL + Offset(20, -36 - lift), ink);
    canvas.drawLine(eyeR + Offset(-20, -36 - lift), eyeR + const Offset(24, -36), ink);
  }

  // Mouth.
  final mouth = center + const Offset(0, 58);
  if (mood == Mood.happy) {
    final grin = Path()
      ..moveTo(mouth.dx - 40, mouth.dy - 8)
      ..quadraticBezierTo(mouth.dx, mouth.dy + 50, mouth.dx + 40, mouth.dy - 8)
      ..close();
    canvas.drawPath(grin, Paint()..color = const Color(0xFF8E2B3A));
    canvas.drawPath(grin, ink);
  } else if (mood == Mood.fainted) {
    final wave = Path()..moveTo(mouth.dx - 34, mouth.dy);
    for (var i = 0; i < 4; i++) {
      wave.relativeQuadraticBezierTo(8.5, i.isEven ? -12 : 12, 17, 0);
    }
    canvas.drawPath(wave, ink);
  } else if (stress < 0.3) {
    canvas.drawPath(
      Path()
        ..moveTo(mouth.dx - 32, mouth.dy - 6)
        ..quadraticBezierTo(mouth.dx, mouth.dy + 22, mouth.dx + 32, mouth.dy - 6),
      ink,
    );
  } else if (stress < 0.65) {
    final wave = Path()..moveTo(mouth.dx - 30, mouth.dy);
    final wobble = 6 + 4 * math.sin(time * 9);
    wave
      ..relativeQuadraticBezierTo(10, -wobble, 20, 0)
      ..relativeQuadraticBezierTo(10, wobble, 20, 0)
      ..relativeQuadraticBezierTo(10, -wobble, 20, 0);
    canvas.drawPath(wave, ink);
  } else {
    final open = Rect.fromCenter(
        center: mouth + const Offset(0, 6), width: 40, height: 30 + 30 * stress);
    canvas.drawOval(open, Paint()..color = const Color(0xFF6B1F2A));
    canvas.drawOval(open, ink);
  }

  // Sweat drop.
  if (stress > 0.45 && mood == Mood.normal) {
    final drop = center + Offset(98, -70 + (time * 40 % 30));
    final path = Path()
      ..moveTo(drop.dx, drop.dy - 22)
      ..quadraticBezierTo(drop.dx + 16, drop.dy, drop.dx, drop.dy + 10)
      ..quadraticBezierTo(drop.dx - 16, drop.dy, drop.dx, drop.dy - 22);
    canvas.drawPath(path, Paint()..color = const Color(0xFF7FD3FF));
  }
}
