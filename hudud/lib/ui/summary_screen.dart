import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/stats.dart';
import '../map/hudud_map.dart';
import 'paywall_screen.dart';
import 'share_card.dart';
import 'theme.dart';
import 'widgets.dart';

/// A run's result: right after finishing, or opened from the history.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({
    super.key,
    required this.record,
    required this.route,
    this.demo = false,
    this.healthSaved = false,
    this.newBadges = const [],
    this.fromHistory = false,
  });

  final RunRecord record;
  final RunRoute route;
  final bool demo;
  final bool healthSaved;
  final List<String> newBadges;
  final bool fromHistory;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _map = HududMapController();
  bool _sharing = false;
  late final Set<int> _cells = widget.route.cells.toSet();

  Future<void> _share(CardStyle style) async {
    final app = AppScope.read(context);
    if (style != CardStyle.neon && !app.pro.isPro) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen()));
      return;
    }
    setState(() => _sharing = true);
    try {
      await shareRun(
        record: widget.record,
        route: widget.route,
        s: app.settings.strings,
        color: app.skin,
        theme: app.mapTheme,
        style: style,
        home: app.settings.home,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _pickShareStyle() async {
    final app = AppScope.read(context);
    final s = app.settings.strings;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final style in CardStyle.values)
              ListTile(
                leading: Icon(switch (style) {
                  CardStyle.neon => Icons.blur_on_rounded,
                  CardStyle.aurora => Icons.auto_awesome_rounded,
                  CardStyle.minimal => Icons.crop_square_rounded,
                }),
                title: Text(switch (style) {
                  CardStyle.neon => 'Neon',
                  CardStyle.aurora => 'Aurora',
                  CardStyle.minimal => 'Minimal',
                }),
                trailing: style != CardStyle.neon && !app.pro.isPro ? const ProTag(small: true) : null,
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_share(style));
                },
              ),
            const SizedBox(height: 8),
            Text(s.privacyZoneText, style: const TextStyle(fontSize: 12, color: Palette.muted)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings.strings;
    final r = widget.record;
    final stretches = widget.route.stretches;
    final allPoints = [for (final st in stretches) ...st];
    final height = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: height * 0.44,
            pinned: true,
            backgroundColor: Palette.background,
            leading: widget.fromHistory ? null : const SizedBox.shrink(),
            automaticallyImplyLeading: widget.fromHistory,
            flexibleSpace: FlexibleSpaceBar(
              background: allPoints.isEmpty
                  ? const SizedBox.shrink()
                  : HududMap(
                      theme: app.mapTheme,
                      center: allPoints.first,
                      zoom: 15,
                      tilt: 0,
                      controller: _map,
                      territory: app.store.territory.shapes,
                      territoryVersion: app.store.territory.length,
                      color: app.skin,
                      runCells: _cells,
                      runCellsVersion: 1,
                      route: stretches,
                      routeVersion: 1,
                      onReady: () => _map.fit(allPoints, padding: const EdgeInsets.fromLTRB(40, 90, 40, 40)),
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList.list(
              children: [
                Text(widget.fromHistory ? s.date(r.start) : s.greatRun,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                if (!widget.fromHistory) ...[
                  const SizedBox(height: 4),
                  Text(s.date(r.start), style: const TextStyle(color: Palette.muted)),
                ],
                const SizedBox(height: 16),
                if (widget.demo)
                  _Note(icon: Icons.info_outline_rounded, text: s.demoNotSaved, color: Palette.violet)
                else if (!widget.fromHistory) ...[
                  _Note(icon: Icons.check_circle_rounded, text: s.saved, color: app.skin),
                  if (widget.healthSaved)
                    _Note(icon: Icons.favorite_rounded, text: s.savedToHealth, color: const Color(0xFFFF5E6C)),
                ],
                const SizedBox(height: 8),
                Glass(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Stat(
                              label: s.newLand,
                              value: '+${s.areaShort(r.newArea)}',
                              unit: s.areaUnit(r.newArea),
                              color: app.skin,
                              size: 34,
                            ),
                          ),
                          Expanded(child: Stat(label: s.distance, value: (r.distance / 1000).toStringAsFixed(2), unit: 'km', size: 34)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: Stat(label: s.time, value: s.duration(Duration(seconds: r.movingSeconds)), size: 22)),
                          Expanded(child: Stat(label: s.paceLabel, value: s.pace(r.pace), unit: s.perKm, size: 22)),
                          Expanded(child: Stat(label: s.loopsLabel, value: '${r.loops}', size: 22)),
                          Expanded(child: Stat(label: s.calories, value: '${r.calories.round()}', size: 22)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (r.splits.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(s.splits.toUpperCase(), style: caption),
                  const SizedBox(height: 10),
                  _Splits(splits: r.splits, color: app.skin),
                ],
                if (widget.newBadges.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(s.newBadges.toUpperCase(), style: caption),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final id in widget.newBadges)
                        Chip(
                          avatar: Text(Achievement.all.firstWhere((a) => a.id == id).emoji),
                          label: Text(s.achievementTitle(id)),
                          backgroundColor: Palette.surfaceHigh,
                          side: BorderSide(color: app.skin.withValues(alpha: 0.5)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sharing || widget.demo ? null : _pickShareStyle,
                        icon: _sharing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.ios_share_rounded),
                        label: Text(s.share),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                        child: Text(widget.fromHistory ? s.close : s.done,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.background)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _Splits extends StatelessWidget {
  const _Splits({required this.splits, required this.color});

  final List<int> splits;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).settings.strings;
    final slowest = splits.reduce(math.max);
    final fastest = splits.reduce(math.min);
    return Column(
      children: [
        for (var i = 0; i < splits.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 54, child: Text(s.kmNumber(i + 1), style: const TextStyle(color: Palette.muted))),
                Expanded(
                  child: Bar(
                    value: slowest == 0 ? 1 : 0.35 + 0.65 * fastest / splits[i],
                    color: splits[i] == fastest ? color : Palette.violet,
                    height: 10,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  child: Text(s.pace(splits[i].toDouble()),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: tabular)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
