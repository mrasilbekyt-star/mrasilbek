import 'package:flutter/material.dart';

import '../game/session.dart';

/// ECG strip with the patient's heart rate.
class HeartMonitor extends StatelessWidget {
  const HeartMonitor({super.key, required this.session});

  final GameSession session;

  static Color colorFor(double stress) => stress < 0.4
      ? const Color(0xFF00E676)
      : stress < 0.7
          ? const Color(0xFFFFD54F)
          : const Color(0xFFFF5252);

  @override
  Widget build(BuildContext context) {
    final color = colorFor(session.stress);
    return Container(
      width: 150,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1A14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3D30), width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _EcgPainter(session, color),
              size: Size.infinite,
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                session.bpm.round().toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text('♥ BPM', style: TextStyle(color: color, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  _EcgPainter(this.session, this.color) : super(repaint: session);

  final GameSession session;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF16302A)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 12) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    final samples = session.ecg;
    final n = samples.length;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final v = samples[(session.ecgHead + i) % n];
      final x = size.width * i / (n - 1);
      final y = size.height * 0.72 - v * size.height * 0.62;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_EcgPainter old) => old.color != color;
}
