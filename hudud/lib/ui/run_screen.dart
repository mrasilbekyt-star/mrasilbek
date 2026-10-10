import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../core/geo.dart';
import '../data/stats.dart';
import '../map/hudud_map.dart';
import '../run/run_session.dart';
import 'summary_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key, required this.session});

  final RunSession session;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> with SingleTickerProviderStateMixin {
  final _map = HududMapController();
  Timer? _ticker;
  bool _follow = true;
  int _seenSplits = 0;
  int _seenCapture = 0;
  int _seenRoute = 0;
  int _seenTooFast = 0;
  DateTime? _tooFastUntil;
  bool _loopAnnounced = false;
  double _bearing = 0;
  bool _finishing = false;
  RunState? _lastState;

  late final AnimationController _celebrate =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  double _celebratedArea = 0;

  RunSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    session.addListener(_onSession);
    session.start();
    _lastState = session.state;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      session.tick();
      if (mounted) setState(() {});
    });
    if (app.settings.voiceCoach) {
      unawaited(app.coach.prepare(app.settings.strings).then((_) => app.coach.say((s) => s.sayStart)));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    session.removeListener(_onSession);
    session.dispose();
    _celebrate.dispose();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    final app = AppScope.read(context);
    final coach = app.settings.voiceCoach ? app.coach : null;
    final haptics = app.settings.haptics;

    if (session.state != _lastState) {
      if (session.state == RunState.paused) coach?.say((s) => s.sayPaused);
      if (session.state == RunState.running && _lastState == RunState.paused) coach?.say((s) => s.sayResumed);
      _lastState = session.state;
    }

    if (session.splits.length > _seenSplits) {
      _seenSplits = session.splits.length;
      if (haptics) HapticFeedback.mediumImpact();
      final km = _seenSplits;
      final elapsed = session.elapsed;
      final pace = session.splits.last.toDouble();
      coach?.say((s) => s.sayKm(km, elapsed, pace));
    }

    final capture = session.lastCapture;
    if (capture != null && capture.serial != _seenCapture) {
      _seenCapture = capture.serial;
      _celebratedArea = capture.area;
      _celebrate.forward(from: 0);
      if (haptics) {
        HapticFeedback.heavyImpact();
        Future<void>.delayed(const Duration(milliseconds: 180), HapticFeedback.heavyImpact);
      }
      coach?.say((s) => s.sayClaimed(capture.area));
    }

    final close = session.distanceToClose;
    if (close == null || close > 90) {
      _loopAnnounced = false;
    } else if (!_loopAnnounced && close <= 60 && close > 20) {
      _loopAnnounced = true;
      if (haptics) HapticFeedback.selectionClick();
      final meters = (close / 5).round() * 5;
      coach?.say((s) => s.sayCloseLoop(meters));
    }

    if (session.tooFastCount > _seenTooFast) {
      _seenTooFast = session.tooFastCount;
      _tooFastUntil = DateTime.now().add(const Duration(seconds: 8));
    }

    final route = session.route;
    if (route.length != _seenRoute && route.isNotEmpty) {
      _seenRoute = route.length;
      _bearing = _headingOf(route.map((p) => p.pos).toList()) ?? _bearing;
      if (_follow) unawaited(_map.follow(route.last.pos, bearing: _bearing));
    }
    setState(() {});
  }

  /// Direction of travel over the last ~20 m, in degrees from north.
  static double? _headingOf(List<GeoPoint> points) {
    if (points.length < 2) return null;
    final end = Plane.toPlane(points.last);
    for (var i = points.length - 2; i >= 0; i--) {
      final d = end - Plane.toPlane(points[i]);
      if (d.length >= 20) return (math.atan2(d.x, d.y) * 180 / math.pi + 360) % 360;
    }
    return null;
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final app = AppScope.read(context);
    final s = app.settings.strings;
    final before = Stats(app.store.runs, territoryArea: app.store.territory.area);
    final unlockedBefore = {for (final a in Achievement.all) if (a.unlocked(before)) a.id};
    final result = await session.finish();
    if (!mounted) return;
    if (result == null || result.record.distance < 20) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.nothingRun)));
      Navigator.of(context).pop();
      return;
    }
    var healthSaved = false;
    var badges = <String>[];
    if (!session.demo) {
      await app.store.addRun(result.record, result.route);
      final after = Stats(app.store.runs, territoryArea: app.store.territory.area);
      badges = [for (final a in Achievement.all) if (a.unlocked(after) && !unlockedBefore.contains(a.id)) a.id];
      if (app.settings.healthSync) {
        healthSaved = await app.fitness.saveRun(result.record, title: 'Hudud');
      }
      if (app.settings.voiceCoach) {
        app.coach.say((s) => s.sayFinish(result.record.distance, result.record.newArea));
      }
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => SummaryScreen(
        record: result.record,
        route: result.route,
        demo: session.demo,
        healthSaved: healthSaved,
        newBadges: badges,
      ),
    ));
  }

  Future<void> _confirmLeave() async {
    final s = AppScope.read(context).settings.strings;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.surface,
        title: Text(s.leaveRunTitle),
        content: Text(s.leaveRunText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.no)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Palette.danger),
            child: Text(s.yes),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      await session.discard();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings.strings;
    final padding = MediaQuery.paddingOf(context);
    final route = session.route;
    final stretches = <List<GeoPoint>>[];
    for (final p in route) {
      if (stretches.isEmpty || p.startsStretch) stretches.add([]);
      stretches.last.add(p.pos);
    }
    final me = session.lastFix;
    final running = session.state == RunState.running;
    final close = session.distanceToClose;
    final tooFast = _tooFastUntil != null && DateTime.now().isBefore(_tooFastUntil!);
    final start = route.isEmpty ? null : route.first.pos;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: HududMap(
                theme: app.mapTheme,
                center: me?.pos ?? start ?? const GeoPoint(41.3111, 69.2797),
                zoom: 17,
                tilt: 55,
                controller: _map,
                territory: app.store.territory.shapes,
                territoryVersion: app.store.territory.length,
                color: app.skin,
                runCells: session.newCells,
                runCellsVersion: session.newCells.length,
                route: stretches,
                routeVersion: route.length,
                hintFrom: close == null ? null : me?.pos,
                hintTo: session.closeTarget,
                me: me,
                ornamentInsets: EdgeInsets.only(top: padding.top + 200, bottom: padding.bottom + 150),
              ),
            ),
            // The celebration when land is claimed.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _celebrate,
                  builder: (context, _) => _Celebration(
                    t: _celebrate.value,
                    color: app.skin,
                    area: s.area(_celebratedArea),
                    title: s.landClaimed,
                  ),
                ),
              ),
            ),
            // Top: the numbers.
            Positioned(
              left: 12,
              right: 12,
              top: padding.top + 10,
              child: Column(
                children: [
                  Glass(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Stat(label: s.time, value: s.duration(session.elapsed), size: 40),
                            ),
                            if (session.demo)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Palette.violet.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(s.demoBadge,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Palette.violet)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: Stat(label: s.distance, value: (session.distance / 1000).toStringAsFixed(2), unit: 'km')),
                            Expanded(
                              child: Stat(
                                label: s.paceLabel,
                                value: s.pace(session.currentPace ?? session.averagePace),
                                unit: s.perKm,
                              ),
                            ),
                            Expanded(
                              child: Stat(
                                label: s.newLand,
                                value: '+${s.areaShort(session.newArea)}',
                                unit: s.areaUnit(session.newArea),
                                color: app.skin,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DefaultTextStyle(
                          style: const TextStyle(fontSize: 12, color: Palette.muted, fontWeight: FontWeight.w600),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('⭕ ${s.loopsLabel}: ${session.loops}'),
                              Text('🔥 ${session.calories.round()} ${s.kcal}'),
                              if (session.stepCount != null)
                                Text('👟 ${session.stepCount}${session.cadence == null ? '' : ' · ${session.cadence}/min'}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!running)
                    Pill(
                      icon: Icons.pause_circle_rounded,
                      text: session.autoPaused ? s.autoPaused : s.paused,
                      color: Palette.warning,
                    )
                  else if (tooFast)
                    Pill(icon: Icons.directions_car_rounded, text: s.tooFast, color: Palette.danger)
                  else if (!session.gpsReady)
                    Pill(icon: Icons.gps_not_fixed_rounded, text: s.gpsWeak, color: Palette.warning)
                  else if (close != null)
                    Pill(icon: Icons.all_inclusive_rounded, text: s.closeLoop(close.round()), color: app.skin),
                ],
              ),
            ),
            // Bottom: controls.
            Positioned(
              left: 0,
              right: 0,
              bottom: padding.bottom + 18,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  RoundButton(
                    icon: _follow ? Icons.navigation_rounded : Icons.navigation_outlined,
                    color: _follow ? app.skin : null,
                    onTap: () {
                      setState(() => _follow = !_follow);
                      if (_follow && me != null) unawaited(_map.follow(me.pos, bearing: _bearing));
                    },
                  ),
                  if (running)
                    _BigButton(
                      icon: Icons.pause_rounded,
                      color: Palette.warning,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        session.pause();
                      },
                    )
                  else
                    _BigButton(
                      icon: Icons.play_arrow_rounded,
                      color: app.skin,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        session.resume();
                      },
                    ),
                  if (running)
                    const SizedBox(width: 64)
                  else
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HoldButton(icon: Icons.stop_rounded, color: Palette.danger, onHeld: _finish, size: 58),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 90,
                          child: Text(s.holdToFinish,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10, color: Palette.muted)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 10,
        shadowColor: color,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 88, height: 88, child: Icon(icon, size: 44, color: Palette.background)),
        ),
      );
}

/// A burst of the territory color and the claimed area.
class _Celebration extends StatelessWidget {
  const _Celebration({required this.t, required this.color, required this.area, required this.title});

  final double t;
  final Color color;
  final String area;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (t == 0 || t == 1) return const SizedBox.shrink();
    final flash = (1 - t * 2.2).clamp(0.0, 1.0);
    final appear = Curves.elasticOut.transform((t * 2.5).clamp(0.0, 1.0));
    final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [color.withValues(alpha: 0.55 * flash), color.withValues(alpha: 0)],
                radius: 0.4 + t,
              ),
            ),
          ),
        ),
        Center(
          child: Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.6 + 0.4 * appear,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('+$area', style: bigNumber(56, color: color).copyWith(shadows: [Shadow(color: color, blurRadius: 30)])),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [Shadow(color: Colors.black, blurRadius: 12)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
