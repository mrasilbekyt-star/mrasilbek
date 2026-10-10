import 'package:flutter/material.dart';

import '../game/levels.dart';
import '../game/session.dart';
import '../services/app_state.dart';
import 'game_screen.dart';
import 'widgets.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key, required this.feedback});

  final FeedbackSink feedback;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    return Scaffold(
      backgroundColor: const Color(0xFF0E2621),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12322B),
        foregroundColor: Colors.white,
        title: Text(s.patients),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '★ ${app.totalStars}/${levels.length * 3}',
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: levels.length,
        itemBuilder: (context, i) {
          final level = levels[i];
          final unlocked = app.isUnlocked(level.number);
          return _LevelCard(
            level: level,
            stars: app.starsFor(level.number),
            unlocked: unlocked,
            label: s.patientNumber(level.number),
            onTap: unlocked
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GameScreen(level: level, feedback: feedback),
                      ),
                    )
                : null,
          );
        },
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.stars,
    required this.unlocked,
    required this.label,
    required this.onTap,
  });

  final LevelDef level;
  final int stars;
  final bool unlocked;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: unlocked ? const Color(0xFF1E4D42) : const Color(0xFF173029),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: unlocked ? const Color(0xFF80CBC4) : Colors.white38,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              unlocked
                  ? Text(level.items.join(), style: const TextStyle(fontSize: 34))
                  : const Icon(Icons.lock_rounded, color: Colors.white38, size: 40),
              const SizedBox(height: 6),
              Text(
                level.patient,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked ? Colors.white : Colors.white38,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(child: StarRow(stars: stars, size: 24)),
            ],
          ),
        ),
      ),
    );
  }
}
