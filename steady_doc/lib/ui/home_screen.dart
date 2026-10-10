import 'package:flutter/material.dart';

import '../game/session.dart';
import '../services/app_state.dart';
import '../services/services.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});

  final Services services;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF12302A), Color(0xFF050A09)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CustomPaint(painter: _EcgLinePainter(_clock)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'STEADY DOC',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      s.tagline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF9FBFB6), fontSize: 16, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFFC145)),
                      const SizedBox(width: 6),
                      Text(
                        '${app.totalStars}',
                        style: const TextStyle(
                          color: Color(0xFFFFC145),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: 270,
                    height: 58,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1FA67A),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LevelSelectScreen(services: widget.services),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 30),
                      label: Text(s.play, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 270,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF2B4A42), width: 2),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                      ),
                      icon: const Icon(Icons.settings_rounded),
                      label: Text(s.settings, style: const TextStyle(fontSize: 17)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A glowing heartbeat sweeping across the title screen.
class _EcgLinePainter extends CustomPainter {
  _EcgLinePainter(this.clock) : super(repaint: clock);

  final AnimationController clock;

  @override
  void paint(Canvas canvas, Size size) {
    const beats = 2.5;
    final head = clock.value * size.width;
    final path = Path();
    for (var x = 0.0; x <= size.width; x += 2) {
      final phase = (x / size.width * beats) % 1;
      final y = size.height * 0.7 - GameSession.ecgWave(phase) * size.height * 0.6;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    // Fade the trace behind the sweeping head, like a real monitor.
    final shader = LinearGradient(
      colors: const [Color(0x0039D98A), Color(0xFF39D98A), Color(0x0039D98A)],
      stops: [
        ((head - size.width * 0.6) / size.width).clamp(0.0, 1.0),
        (head / size.width).clamp(0.0, 1.0),
        ((head + 1) / size.width).clamp(0.0, 1.0),
      ],
    ).createShader(Offset.zero & size);
    canvas.drawPath(
      path,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_EcgLinePainter old) => false;
}
