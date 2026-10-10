import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// A dark rounded panel that floats over the map.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 22});

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Palette.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: child,
      );
}

/// A label over a big number.
class Stat extends StatelessWidget {
  const Stat({super.key, required this.label, required this.value, this.unit, this.size = 26, this.color});

  final String label;
  final String value;
  final String? unit;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: value, style: bigNumber(size, color: color ?? Palette.text)),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w700, color: Palette.muted),
                  ),
              ]),
            ),
          ),
        ],
      );
}

/// A round button with an icon, for the map's edges.
class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.icon, required this.onTap, this.size = 52, this.tooltip, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Palette.surface.withValues(alpha: 0.92),
      shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      elevation: 6,
      shadowColor: Colors.black,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: Icon(icon, color: color ?? Palette.text, size: size * 0.46)),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// The big round start button with a breathing ring.
class StartButton extends StatefulWidget {
  const StartButton({super.key, required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<StartButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    return SizedBox(
      width: size * 1.5,
      height: size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = _pulse.value;
              return Container(
                width: size * (1 + 0.45 * t),
                height: size * (1 + 0.45 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color.withValues(alpha: (1 - t) * 0.7), width: 3),
                ),
              );
            },
          ),
          Material(
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            elevation: 12,
            shadowColor: widget.color,
            child: Ink(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.color, Color.lerp(widget.color, Palette.violet, 0.55)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onTap();
                },
                child: Center(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Palette.background,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A button that only acts after being held, with a filling ring, so a run
/// is never finished by a stray touch.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onHeld,
    this.size = 76,
    this.duration = const Duration(milliseconds: 1100),
  });

  final IconData icon;
  final Color color;
  final VoidCallback onHeld;
  final double size;
  final Duration duration;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onHeld();
        _hold.reset();
      }
    });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          _hold.forward();
        },
        onTapUp: (_) => _hold.reverse(),
        onTapCancel: () => _hold.reverse(),
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) => CustomPaint(
            painter: _RingPainter(_hold.value, widget.color),
            child: Container(
              width: widget.size,
              height: widget.size,
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.18)),
              child: Icon(widget.icon, color: widget.color, size: widget.size * 0.45),
            ),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(2),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

/// A slim progress bar.
class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, required this.color, this.height = 6});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          children: [
            Container(height: height, color: Palette.surfaceHigh),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, Color.lerp(color, Palette.violet, 0.5)!]),
                ),
              ),
            ),
          ],
        ),
      );
}

/// The little golden PRO tag.
class ProTag extends StatelessWidget {
  const ProTag({super.key, this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 6 : 9, vertical: small ? 2 : 4),
        decoration: BoxDecoration(gradient: Palette.proGradient, borderRadius: BorderRadius.circular(8)),
        child: Text(
          'PRO',
          style: TextStyle(
            color: Palette.background,
            fontWeight: FontWeight.w900,
            fontSize: small ? 9 : 11,
            letterSpacing: 1,
          ),
        ),
      );
}

/// A pill-shaped notice over the map.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Palette.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      );
}
