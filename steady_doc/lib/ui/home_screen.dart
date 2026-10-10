import 'package:flutter/material.dart';

import '../game/session.dart';
import '../painting/patient_painter.dart';
import '../services/app_state.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.feedback});

  final FeedbackSink feedback;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 37))..repeat();

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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E52), Color(0xFF0B2B25)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: 190,
                    height: 190,
                    child: CustomPaint(painter: _FacePainter(_clock)),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    s.appTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.tagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '★ ${app.totalStars}',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 260,
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LevelSelectScreen(feedback: widget.feedback),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 32),
                      label: Text(s.play, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 260,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54, width: 2),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                      ),
                      icon: const Icon(Icons.settings_rounded),
                      label: Text(s.settings, style: const TextStyle(fontSize: 18)),
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

/// A calm patient blinking on the title screen.
class _FacePainter extends CustomPainter {
  _FacePainter(this.clock) : super(repaint: clock);

  final AnimationController clock;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 300;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    const skin = Color(0xFFF2C9A0);
    canvas.drawCircle(Offset.zero, 140, Paint()..color = const Color(0x33FFFFFF));
    canvas.drawCircle(Offset.zero, 130, Paint()..color = skin);
    // Surgical cap.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 132)));
    canvas.drawRect(const Rect.fromLTRB(-140, -140, 140, -62), Paint()..color = const Color(0xFF26A69A));
    canvas.restore();
    final time = clock.value * 37;
    paintFace(canvas, 0.1, time, Mood.normal, center: Offset.zero);
  }

  @override
  bool shouldRepaint(_FacePainter old) => false;
}
