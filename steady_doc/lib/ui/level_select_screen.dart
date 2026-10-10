import 'package:flutter/material.dart';

import '../game/levels.dart';
import '../l10n/strings.dart';
import '../services/app_state.dart';
import '../services/services.dart';
import 'game_screen.dart';
import 'widgets.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key, required this.services});

  final Services services;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    return Scaffold(
      backgroundColor: const Color(0xFF070D0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1513),
        foregroundColor: Colors.white,
        title: Text(s.patients),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '★ ${app.totalStars}/${levels.length * 3}',
                style: const TextStyle(
                  color: Color(0xFFFFC145),
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
          childAspectRatio: 0.72,
        ),
        itemCount: levels.length,
        itemBuilder: (context, i) {
          final level = levels[i];
          final unlocked = app.isUnlocked(level.number);
          return _LevelCard(
            level: level,
            stars: app.starsFor(level.number),
            unlocked: unlocked,
            strings: s,
            onTap: unlocked
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GameScreen(level: level, services: services),
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
    required this.strings,
    required this.onTap,
  });

  final LevelDef level;
  final int stars;
  final bool unlocked;
  final Strings strings;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dim = unlocked ? 1.0 : 0.38;
    return Material(
      color: unlocked ? const Color(0xFF10201C) : const Color(0xFF0B1513),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: unlocked ? const Color(0xFF24433B) : const Color(0xFF15241F)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Opacity(
            opacity: dim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  strings.patientNumber(level.number).toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF39D98A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  unlocked ? _regionIcon(level.scene.region) : Icons.lock_rounded,
                  color: Colors.white70,
                  size: 38,
                ),
                const SizedBox(height: 6),
                Text(
                  strings.patient(level.sex, level.age),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.diagnosis(level.diagnosis),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 6),
                FittedBox(child: StarRow(stars: stars, size: 22)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _regionIcon(Region region) => switch (region) {
      Region.belly || Region.appendix || Region.gallbladder => Icons.accessibility_new_rounded,
      Region.hand => Icons.back_hand_rounded,
      Region.thigh || Region.knee => Icons.directions_walk_rounded,
      Region.flank => Icons.airline_seat_flat_rounded,
      Region.shoulder => Icons.fitness_center_rounded,
    };
