import 'package:flutter/painting.dart';

/// Draws emoji on a canvas, caching the laid-out text.
class EmojiPainter {
  final Map<(String, double), TextPainter> _cache = {};

  TextPainter _layout(String emoji, double size) =>
      _cache.putIfAbsent((emoji, size), () {
        return TextPainter(
          text: TextSpan(text: emoji, style: TextStyle(fontSize: size, height: 1)),
          textDirection: TextDirection.ltr,
        )..layout();
      });

  void paint(Canvas canvas, String emoji, Offset center, double size,
      {ColorFilter? filter, double opacity = 1}) {
    final tp = _layout(emoji, size);
    final topLeft = center - Offset(tp.width / 2, tp.height / 2);
    if (filter == null && opacity >= 1) {
      tp.paint(canvas, topLeft);
      return;
    }
    final paint = Paint()..color = Color.fromRGBO(0, 0, 0, opacity);
    if (filter != null) paint.colorFilter = filter;
    canvas.saveLayer(topLeft & tp.size, paint);
    tp.paint(canvas, topLeft);
    canvas.restore();
  }
}

/// Makes a colorful emoji look like a bright shape on an X-ray film.
const xrayFilter = ColorFilter.matrix(<double>[
  0.15, 0.50, 0.05, 0, 40, //
  0.19, 0.65, 0.07, 0, 60, //
  0.22, 0.75, 0.08, 0, 80, //
  0, 0, 0, 1, 0, //
]);
