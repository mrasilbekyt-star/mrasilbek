import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/geo.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../map/map_style.dart';
import 'route_painter.dart';

/// Looks of the story image. The first is free; the others come with Pro.
enum CardStyle { neon, aurora, minimal }

/// Draws a 1080 x 1920 story image of a run and opens the share sheet.
Future<void> shareRun({
  required RunRecord record,
  required RunRoute route,
  required Strings s,
  required Color color,
  required MapTheme theme,
  required CardStyle style,
  GeoPoint? home,
}) async {
  final bytes = await renderShareCard(
    record: record,
    route: route,
    s: s,
    color: color,
    theme: theme,
    style: style,
    home: home,
  );
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/hudud_${record.id}.png');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'image/png')],
    text: '${s.km(record.distance)} · +${s.area(record.newArea)} — Hudud',
  ));
}

Future<List<int>> renderShareCard({
  required RunRecord record,
  required RunRoute route,
  required Strings s,
  required Color color,
  required MapTheme theme,
  required CardStyle style,
  GeoPoint? home,
}) async {
  const size = Size(1080, 1920);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);

  final (top, bottom, accent) = switch (style) {
    CardStyle.neon => (const Color(0xFF0B1220), const Color(0xFF04060B), color),
    CardStyle.aurora => (const Color(0xFF2A0F4F), const Color(0xFF071B2E), const Color(0xFF22E5FF)),
    CardStyle.minimal => (const Color(0xFFF4F2EE), const Color(0xFFE9E5DD), const Color(0xFF111111)),
  };
  final light = style == CardStyle.minimal;
  final textColor = light ? const Color(0xFF111111) : Colors.white;
  final muted = light ? const Color(0xFF6B6B6B) : const Color(0xFF8A97AB);

  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = LinearGradient(colors: [top, bottom], begin: Alignment.topCenter, end: Alignment.bottomCenter)
          .createShader(Offset.zero & size),
  );
  if (!light) {
    canvas.drawCircle(
      const Offset(540, 760),
      620,
      Paint()
        ..shader = RadialGradient(colors: [accent.withValues(alpha: 0.22), accent.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: const Offset(540, 760), radius: 620)),
    );
  }

  void text(String value, Offset at, double fontSize,
      {FontWeight weight = FontWeight.w800, Color? color, double spacing = 0, TextAlign align = TextAlign.left, double width = 920}) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: color ?? textColor,
          letterSpacing: spacing,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    final dx = switch (align) {
      TextAlign.center => at.dx + (width - painter.width) / 2,
      TextAlign.right => at.dx + width - painter.width,
      _ => at.dx,
    };
    painter.paint(canvas, Offset(dx, at.dy));
  }

  text('HUDUD', const Offset(80, 110), 44, spacing: 10, color: accent);
  text(s.date(record.start), const Offset(80, 175), 34, weight: FontWeight.w600, color: muted);

  // The run itself.
  canvas.save();
  canvas.translate(80, 290);
  RoutePainter(
    stretches: route.stretches,
    cells: route.cells.toSet(),
    color: accent,
    routeStart: light ? const Color(0xFF111111) : theme.routeStart,
    routeEnd: light ? const Color(0xFFFF4D2E) : theme.routeEnd,
    strokeWidth: 9,
    padding: 30,
    hideNear: home,
  ).paint(canvas, const Size(920, 900));
  canvas.restore();

  // Numbers.
  text('+${s.area(record.newArea)}', const Offset(80, 1250), 120, color: accent);
  text(s.newLand.toUpperCase(), const Offset(84, 1390), 30, weight: FontWeight.w700, color: muted, spacing: 4);
  final cols = [
    (s.distance, s.km(record.distance)),
    (s.time, s.duration(Duration(seconds: record.movingSeconds))),
    (s.paceLabel, '${s.pace(record.pace)}${s.perKm}'),
  ];
  for (var i = 0; i < cols.length; i++) {
    final x = 80.0 + i * 310;
    text(cols[i].$1.toUpperCase(), Offset(x, 1500), 26, weight: FontWeight.w700, color: muted, spacing: 3, width: 300);
    text(cols[i].$2, Offset(x, 1545), 54, width: 300);
  }
  text(s.tagline, const Offset(80, 1740), 34, weight: FontWeight.w700, color: muted, width: 920, align: TextAlign.center);

  final image = await recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
