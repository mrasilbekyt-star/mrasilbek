import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import 'all_routes_screen.dart';
import 'paywall_screen.dart';
import 'route_painter.dart';
import 'summary_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings.strings;
    final runs = app.store.runs;
    final now = DateTime.now();
    final month = [for (final r in runs) if (r.start.year == now.year && r.start.month == now.month) r];
    final monthKm = month.fold(0.0, (a, r) => a + r.distance);
    final monthArea = month.fold(0.0, (a, r) => a + r.newArea);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.history, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => app.pro.isPro ? const AllRoutesScreen() : const PaywallScreen(),
            )),
            icon: const Icon(Icons.layers_rounded),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text(s.allRoutes), if (!app.pro.isPro) ...[const SizedBox(width: 6), const ProTag(small: true)]],
            ),
          ),
        ],
      ),
      body: runs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(s.noRuns, textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted, fontSize: 16)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Glass(
                  child: Row(
                    children: [
                      Expanded(child: Stat(label: s.thisMonth, value: s.runsCount(month.length), size: 20)),
                      Expanded(child: Stat(label: s.distance, value: s.km(monthKm), size: 20)),
                      Expanded(child: Stat(label: s.newLand, value: s.area(monthArea), size: 20, color: app.skin)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final r in runs) _RunCard(record: r),
              ],
            ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.record});

  final RunRecord record;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings.strings;
    final theme = app.mapTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final route = await app.store.route(record.id);
            if (route == null || !context.mounted) return;
            await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => SummaryScreen(record: record, route: route, fromHistory: true),
            ));
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(color: theme.background, borderRadius: BorderRadius.circular(14)),
                  child: FutureBuilder<RunRoute?>(
                    future: app.store.route(record.id),
                    builder: (context, snap) {
                      final route = snap.data;
                      if (route == null) return const SizedBox.shrink();
                      return CustomPaint(
                        painter: RoutePainter(
                          stretches: route.stretches,
                          cells: route.cells.toSet(),
                          color: app.skin,
                          routeStart: theme.routeStart,
                          routeEnd: theme.routeEnd,
                          strokeWidth: 2,
                          padding: 8,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.date(record.start), style: const TextStyle(color: Palette.muted, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(s.km(record.distance), style: bigNumber(24)),
                      const SizedBox(height: 6),
                      Text(
                        '${s.duration(Duration(seconds: record.movingSeconds))} · ${s.pace(record.pace)}${s.perKm}',
                        style: const TextStyle(color: Palette.muted, fontSize: 13, fontFeatures: tabular),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('+${s.area(record.newArea)}', style: TextStyle(color: app.skin, fontWeight: FontWeight.w800)),
                    if (record.loops > 0) ...[
                      const SizedBox(height: 6),
                      Text('⭕ ${record.loops}', style: const TextStyle(color: Palette.muted)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
