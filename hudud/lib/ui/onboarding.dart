import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app.dart';
import 'theme.dart';

/// Three pages that explain the game the first time the app opens.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings.strings;
    final color = app.skin;
    final pages = [
      (s.onboardTitle1, s.onboardText1, 0),
      (s.onboardTitle2, s.onboardText2, 1),
      (s.onboardTitle3, s.onboardText3, 2),
    ];
    final last = _page == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Text('HUDUD', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 6)),
                  const Spacer(),
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: i == _page ? color : Palette.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final (title, text, art) in pages)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 260),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: CustomPaint(painter: _HexArt(art, color)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(title, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 14),
                          Text(text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, color: Palette.muted, height: 1.45)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  onPressed: () {
                    if (last) {
                      app.settings.setOnboarded();
                    } else {
                      _pages.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
                    }
                  },
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  child: Text(last ? s.letsGo : s.next,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Palette.background)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hexagon art: a path of cells, a closed loop, a growing patch.
class _HexArt extends CustomPainter {
  _HexArt(this.kind, this.color);

  final int kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 18.0;
    final w = math.sqrt(3) * r;
    final c = size.center(Offset.zero);
    Offset center(int q, int row) => c + Offset(w * (q + row / 2), 1.5 * r * row);
    Path hex(Offset o) => Path()
      ..addPolygon([
        for (var i = 0; i < 6; i++) o + Offset(r * math.cos((60 * i - 30) * math.pi / 180), r * math.sin((60 * i - 30) * math.pi / 180)),
      ], true);

    final cells = <(int, int)>[];
    for (var row = -4; row <= 4; row++) {
      for (var q = -5; q <= 5; q++) {
        final p = center(q, row) - c;
        if (p.distance < 120) cells.add((q, row));
      }
    }
    bool owned(int q, int row) {
      final p = center(q, row) - c;
      return switch (kind) {
        0 => (p.dy - p.dx * 0.35).abs() < 16,
        1 => p.distance < 70,
        _ => p.distance < 70 || (p.dx > 20 && p.distance < 110),
      };
    }

    for (final (q, row) in cells) {
      final o = center(q, row);
      final mine = owned(q, row);
      canvas.drawPath(hex(o), Paint()..color = mine ? color.withValues(alpha: 0.35) : Palette.surface);
      canvas.drawPath(
        hex(o),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = mine ? color : Palette.line,
      );
    }
    if (kind == 1) {
      canvas.drawCircle(
        c,
        78,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..shader = const SweepGradient(colors: [Palette.violet, Color(0xFF3DFFA2), Palette.violet])
              .createShader(Rect.fromCircle(center: c, radius: 78)),
      );
    }
  }

  @override
  bool shouldRepaint(_HexArt old) => old.kind != kind || old.color != color;
}
