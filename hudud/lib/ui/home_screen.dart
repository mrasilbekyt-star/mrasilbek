import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../core/geo.dart';
import '../core/gps_filter.dart';
import '../data/stats.dart';
import '../l10n/strings.dart';
import '../map/hudud_map.dart';
import '../map/map_style.dart';
import '../run/location.dart';
import 'history_screen.dart';
import 'paywall_screen.dart';
import 'profile_screen.dart';
import 'start_run.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _map = HududMapController();
  StreamSubscription<Fix>? _watch;
  Fix? _me;
  GeoPoint? _center;
  bool _located = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_locate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watch?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only watch the GPS while the map is on screen.
    if (state == AppLifecycleState.resumed) {
      unawaited(_locate());
    } else if (state == AppLifecycleState.paused) {
      _watch?.cancel();
      _watch = null;
    }
  }

  Future<void> _locate() async {
    final fix = await DeviceLocation.current();
    if (!mounted || fix == null) return;
    setState(() {
      _me = fix;
      _center ??= fix.pos;
    });
    _watch ??= DeviceLocation.watch().listen(
      (f) => mounted ? setState(() => _me = f) : null,
      onError: (Object _) {},
    );
    if (!_located) {
      _located = true;
      if (AppScope.read(context).store.territory.length == 0) await _map.flyTo(fix.pos, zoom: 16);
    }
  }

  GeoPoint _startCenter(AppServices app) {
    final shapes = app.store.territory.shapes;
    if (shapes.isNotEmpty) {
      final points = [for (final s in shapes) ...s.outer];
      final lat = points.map((p) => p.lat).reduce((a, b) => a + b) / points.length;
      final lon = points.map((p) => p.lon).reduce((a, b) => a + b) / points.length;
      return GeoPoint(lat, lon);
    }
    return _me?.pos ?? fallbackCenter;
  }

  Future<void> _fitTerritory(AppServices app) async {
    final points = [for (final s in app.store.territory.shapes) ...s.outer];
    if (points.isEmpty) {
      if (_me != null) await _map.flyTo(_me!.pos, zoom: 16.5);
      return;
    }
    final padding = MediaQuery.paddingOf(context);
    await _map.fit(points, padding: EdgeInsets.fromLTRB(40, padding.top + 200, 40, padding.bottom + 200));
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _pickMapStyle(AppServices app) async {
    final s = app.settings.strings;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.mapStyle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final theme in MapTheme.all)
                    Expanded(
                      child: _ThemeChoice(
                        theme: theme,
                        name: s.mapThemeName(theme.id),
                        selected: app.mapTheme.id == theme.id,
                        locked: theme.pro && !app.pro.isPro,
                        onTap: () {
                          Navigator.pop(context);
                          if (theme.pro && !app.pro.isPro) {
                            _open(const PaywallScreen());
                          } else {
                            app.settings.setMapTheme(theme);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings.strings;
    final territory = app.store.territory;
    final stats = Stats(app.store.runs, territoryArea: territory.area);
    final padding = MediaQuery.paddingOf(context);
    final center = _center ?? _startCenter(app);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: HududMap(
              theme: app.mapTheme,
              center: center,
              zoom: territory.length == 0 ? 15 : 15.5,
              controller: _map,
              territory: territory.shapes,
              territoryVersion: territory.length,
              color: app.skin,
              me: _me,
              ornamentInsets: EdgeInsets.only(top: padding.top + 150, bottom: padding.bottom + 150),
              onReady: () {
                if (territory.length > 0) unawaited(_fitTerritory(app));
              },
            ),
          ),
          // Top: the land you own.
          Positioned(
            left: 16,
            right: 16,
            top: padding.top + 12,
            child: Column(
              children: [
                Glass(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.yourTerritory.toUpperCase(), style: caption),
                            const SizedBox(height: 8),
                            Text.rich(TextSpan(children: [
                              TextSpan(text: s.areaShort(territory.area), style: bigNumber(40, color: app.skin)),
                              TextSpan(
                                text: ' ${s.areaUnit(territory.area)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.muted),
                              ),
                            ])),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 14,
                              runSpacing: 4,
                              children: [
                                _Mini(Icons.directions_run_rounded, s.runsCount(stats.runCount)),
                                _Mini(Icons.route_rounded, s.km(stats.totalDistance)),
                                _Mini(Icons.local_fire_department_rounded, s.streakDays(stats.currentStreak),
                                    color: stats.currentStreak > 0 ? Palette.warning : null),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () => _open(const PaywallScreen()),
                            child: app.pro.isPro
                                ? const ProTag()
                                : Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(gradient: Palette.proGradient, shape: BoxShape.circle),
                                    child: const Icon(Icons.workspace_premium_rounded, color: Palette.background),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Text(s.rankName(stats.rank),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, color: Palette.muted, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (territory.length == 0) ...[
                  const SizedBox(height: 10),
                  Glass(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.flag_rounded, color: app.skin),
                        const SizedBox(width: 12),
                        Expanded(child: Text(s.emptyTerritory, style: const TextStyle(fontSize: 13, height: 1.35))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Right: map tools.
          Positioned(
            right: 16,
            bottom: padding.bottom + 190,
            child: Column(
              children: [
                RoundButton(icon: Icons.palette_rounded, onTap: () => _pickMapStyle(app), size: 46),
                const SizedBox(height: 10),
                RoundButton(icon: Icons.crop_free_rounded, onTap: () => _fitTerritory(app), size: 46),
                const SizedBox(height: 10),
                RoundButton(
                  icon: Icons.my_location_rounded,
                  size: 46,
                  onTap: () async {
                    await _locate();
                    if (_me != null) await _map.flyTo(_me!.pos, zoom: 17);
                  },
                ),
              ],
            ),
          ),
          // Bottom: start.
          Positioned(
            left: 0,
            right: 0,
            bottom: padding.bottom + 12,
            child: Column(
              children: [
                _GpsLine(me: _me, strings: s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    RoundButton(icon: Icons.history_rounded, onTap: () => _open(const HistoryScreen()), tooltip: s.history),
                    StartButton(label: s.start, color: app.skin, onTap: () => startRun(context)),
                    RoundButton(icon: Icons.person_rounded, onTap: () => _open(const ProfileScreen()), tooltip: s.profile),
                  ],
                ),
                if (app.store.runs.isEmpty)
                  TextButton.icon(
                    onPressed: () => startDemo(context, _me?.pos),
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                    label: Text(s.demoRun),
                    style: TextButton.styleFrom(foregroundColor: Palette.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.icon, this.text, {this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color ?? Palette.muted),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 13, color: Palette.text, fontWeight: FontWeight.w600)),
        ],
      );
}

class _GpsLine extends StatelessWidget {
  const _GpsLine({required this.me, required this.strings});

  final Fix? me;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final fix = me;
    final ready = fix != null && fix.accuracy <= 25;
    final color = fix == null ? Palette.muted : (ready ? const Color(0xFF3DFFA2) : Palette.warning);
    final text = fix == null ? strings.gpsSearching : (ready ? strings.gpsReady : strings.gpsWeak);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.theme,
    required this.name,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final MapTheme theme;
  final String name;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 76,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? theme.routeEnd : Palette.line, width: selected ? 2.5 : 1),
                gradient: LinearGradient(
                  colors: [theme.background, theme.roadMajor, theme.water],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [theme.routeStart, theme.routeEnd]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (locked) const Positioned(right: 6, top: 6, child: ProTag(small: true)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
