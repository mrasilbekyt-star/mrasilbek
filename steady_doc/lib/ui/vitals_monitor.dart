import 'package:flutter/material.dart';

import '../game/session.dart';

/// Patient monitor: ECG trace, heart rate, oxygen and blood pressure.
class VitalsMonitor extends StatelessWidget {
  const VitalsMonitor({super.key, required this.session, required this.alarmLabel});

  final GameSession session;
  final String alarmLabel;

  static const green = Color(0xFF39D98A);
  static const cyan = Color(0xFF4FD1E8);
  static const amber = Color(0xFFFFC145);
  static const red = Color(0xFFFF4D4D);

  @override
  Widget build(BuildContext context) {
    final alarm = session.alarm;
    final flash = alarm && (session.now * 2).floor().isEven;
    return Container(
      height: 76,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF020504),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: flash ? red : const Color(0xFF1C2A26), width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('II',
                        style: TextStyle(color: green, fontSize: 10, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (alarm)
                      Text(
                        alarmLabel,
                        style: TextStyle(
                          color: flash ? red : red.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: CustomPaint(painter: _EcgPainter(session), size: Size.infinite),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _Readout(label: 'HR', value: '${session.bpm.round()}', unit: 'bpm', color: green),
          _Readout(label: 'SpO2', value: '${session.spo2}', unit: '%', color: cyan),
          _Readout(
            label: 'NIBP',
            value: '${session.systolic}/${session.diastolic}',
            unit: 'mmHg',
            color: amber,
            small: true,
          ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.small = false,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.75), fontSize: 10)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: small ? 17 : 24,
              fontWeight: FontWeight.w700,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(unit, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9)),
        ],
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  _EcgPainter(this.session) : super(repaint: session);

  final GameSession session;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF0E1D18)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 10) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final samples = session.ecg;
    final n = samples.length;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final v = samples[(session.ecgHead + i) % n];
      final x = size.width * i / (n - 1);
      final y = size.height * 0.75 - v * size.height * 0.65;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = VitalsMonitor.green.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = VitalsMonitor.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_EcgPainter old) => false;
}
