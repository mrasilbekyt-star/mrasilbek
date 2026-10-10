import 'package:flutter/material.dart';

import '../app.dart';
import '../data/stats.dart';
import 'paywall_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings.strings;
    final stats = Stats(app.store.runs, territoryArea: app.store.territory.area);
    final color = app.skin;
    final nextXp = stats.rank + 1 < Stats.rankThresholds.length ? Stats.rankThresholds[stats.rank + 1] - stats.xp : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.profile, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // Rank.
          Glass(
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [color, Palette.violet]),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20)],
                  ),
                  child: Center(
                    child: Text('${stats.rank + 1}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Palette.background)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(s.rankName(stats.rank),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          ),
                          if (app.pro.isPro) ...[const SizedBox(width: 8), const ProTag(small: true)],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${stats.xp} XP', style: const TextStyle(color: Palette.muted, fontFeatures: tabular)),
                      const SizedBox(height: 10),
                      Bar(value: stats.rankProgress, color: color),
                      if (nextXp > 0) ...[
                        const SizedBox(height: 6),
                        Text(s.xpToNext(nextXp), style: const TextStyle(color: Palette.muted, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Totals.
          Glass(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Stat(label: s.yourTerritory, value: s.area(stats.territoryArea), size: 22, color: color)),
                    Expanded(child: Stat(label: s.totalDistance, value: s.km(stats.totalDistance), size: 22)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Stat(label: s.totalTime, value: s.duration(Duration(seconds: stats.totalSeconds)), size: 22)),
                    Expanded(child: Stat(label: s.currentStreak, value: '🔥 ${s.streakDays(stats.currentStreak)}', size: 22)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(s.weeklyMissions.toUpperCase(), style: caption),
          const SizedBox(height: 10),
          Glass(
            child: Column(
              children: [
                for (final m in Mission.weekly) ...[
                  Row(
                    children: [
                      Icon(m.done(stats) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: m.done(stats) ? color : Palette.muted, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s.missionTitle(m.id), style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('${(m.progress(stats) * 100).round()}%',
                          style: const TextStyle(color: Palette.muted, fontFeatures: tabular)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Bar(value: m.progress(stats), color: color),
                  if (m != Mission.weekly.last) const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text(s.records.toUpperCase(), style: caption),
              if (!app.pro.isPro) ...[const SizedBox(width: 8), const ProTag(small: true)],
            ],
          ),
          const SizedBox(height: 10),
          _Records(stats: stats, locked: !app.pro.isPro),
          const SizedBox(height: 22),
          Text(s.achievements.toUpperCase(), style: caption),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [for (final a in Achievement.all) _Badge(achievement: a, stats: stats)],
          ),
        ],
      ),
    );
  }
}

class _Records extends StatelessWidget {
  const _Records({required this.stats, required this.locked});

  final Stats stats;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings.strings;
    String orDash(String? v) => v ?? '—';
    final rows = [
      (s.fastestKm, orDash(stats.fastestKm == null ? null : s.pace(stats.fastestKm!.toDouble()))),
      (s.fastest5k, orDash(stats.fastest5k == null ? null : s.duration(Duration(seconds: stats.fastest5k!)))),
      (s.longestRun, s.km(stats.longestRun)),
      (s.biggestLoop, s.area(stats.biggestLoop)),
      (s.mostLand, s.area(stats.mostAreaInRun)),
    ];
    final card = Glass(
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: const TextStyle(color: Palette.muted))),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: tabular)),
                ],
              ),
            ),
        ],
      ),
    );
    if (!locked) return card;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen())),
      child: Stack(
        children: [
          Opacity(opacity: 0.25, child: card),
          Positioned.fill(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, color: Palette.gold),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(s.proOnly, style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.gold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.achievement, required this.stats});

  final Achievement achievement;
  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings.strings;
    final unlocked = achievement.unlocked(stats);
    final progress = achievement.progress(stats);
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${achievement.emoji}  ${s.achievementTitle(achievement.id)}: ${s.achievementText(achievement.id)}'),
      )),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: unlocked ? app.skin.withValues(alpha: 0.6) : Palette.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: Palette.surfaceHigh,
                    color: unlocked ? app.skin : Palette.violet,
                  ),
                  Opacity(
                    opacity: unlocked ? 1 : 0.35,
                    child: Text(achievement.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.achievementTitle(achievement.id),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: unlocked ? Palette.text : Palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
