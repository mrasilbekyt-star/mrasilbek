import 'package:flutter/material.dart';

/// Rounded pill message at the top of the table.
class Toast extends StatelessWidget {
  const Toast({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xEE00796B),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// "Great!" that pops in between stages.
class StageClearBanner extends StatelessWidget {
  const StageClearBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFFFF),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18)],
        ),
        child: Text(
          '✓ $text',
          style: const TextStyle(
            color: Color(0xFF00897B),
            fontSize: 38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class PanelAction {
  const PanelAction({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;
}

/// Dimmed backdrop with a card: results, pause and failure screens.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.title,
    required this.emoji,
    required this.children,
    required this.actions,
  });

  final String title;
  final String emoji;
  final List<Widget> children;
  final List<PanelAction> actions;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99000000),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 52)),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      ...children,
                      const SizedBox(height: 18),
                      for (final action in actions)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: action.primary
                                ? FilledButton(
                                    onPressed: action.onTap,
                                    child: Text(action.label,
                                        style: const TextStyle(fontSize: 17)),
                                  )
                                : OutlinedButton(
                                    onPressed: action.onTap,
                                    child: Text(action.label,
                                        style: const TextStyle(fontSize: 16)),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three stars, [stars] of them gold.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 46});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < stars ? const Color(0xFFFFC107) : const Color(0xFFB0BEC5),
          ),
      ],
    );
  }
}

class StatLine extends StatelessWidget {
  const StatLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
