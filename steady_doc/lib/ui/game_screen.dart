import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/levels.dart';
import '../game/session.dart';
import '../game/stages.dart';
import '../l10n/strings.dart';
import '../painting/table_painter.dart';
import '../services/app_state.dart';
import '../services/services.dart';
import 'vitals_monitor.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level, required this.services});

  final LevelDef level;
  final Services services;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late GameSession _session;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  bool _saved = false;

  /// The one pointer currently operating; extra fingers are ignored.
  int? _pointer;

  /// Event time of the last S Pen reading, for palm rejection.
  double _lastStylus = -100;

  bool _penToastShown = false;
  double _penToastUntil = 0;

  @override
  void initState() {
    super.initState();
    _session = _newSession();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addObserver(this);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _session.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _session.pause();
  }

  GameSession _newSession() =>
      GameSession(widget.level, feedback: widget.services.feedback);

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _session.tick(dt);
    if (_session.stylusSeen && !_penToastShown) {
      _penToastShown = true;
      _penToastUntil = _session.now + 3.5;
    }
    if (_session.state == SessionState.won && !_saved) {
      _saved = true;
      unawaited(AppScope.read(context).recordStars(widget.level.number, _session.stars));
    }
  }

  void _restart() {
    final old = _session;
    setState(() {
      _session = _newSession();
      _saved = false;
      _pointer = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _nextLevel() {
    final index = levels.indexOf(widget.level);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(level: levels[index + 1], services: widget.services),
      ),
    );
  }

  // ------------------------------------------------------------- pointers

  static bool _isStylus(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;

  static double _time(PointerEvent e) => e.timeStamp.inMicroseconds / 1e6;

  PenSample _sample(PointerEvent e, DesignFit fit) {
    final stylus = _isStylus(e);
    var pressure = 0.5;
    if (stylus) {
      final range = e.pressureMax - e.pressureMin;
      pressure = range > 0 ? (e.pressure - e.pressureMin) / range : e.pressure;
      pressure = pressure.clamp(0.0, 1.0);
      _lastStylus = _time(e);
    }
    return PenSample(fit.toDesign(e.localPosition), _time(e),
        stylus: stylus, pressure: pressure);
  }

  void _onDown(PointerDownEvent e, DesignFit fit) {
    if (_pointer != null) return;
    // Palm rejection: while the S Pen is in use, ignore the resting hand.
    if (!_isStylus(e) && _time(e) - _lastStylus < 5) return;
    _pointer = e.pointer;
    _session.down(_sample(e, fit));
  }

  void _onMove(PointerMoveEvent e, DesignFit fit) {
    if (e.pointer != _pointer) return;
    _session.move(_sample(e, fit));
  }

  void _onUp(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _session.up();
  }

  void _onHover(PointerHoverEvent e, DesignFit fit) {
    if (!_isStylus(e) && e.kind != PointerDeviceKind.mouse) return;
    _session.hover(_sample(e, fit));
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_session.state == SessionState.playing ||
            _session.state == SessionState.stageClear) {
          _session.pause();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF070D0B),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _session,
            builder: (context, _) => Column(
              children: [
                _topBar(s),
                VitalsMonitor(session: _session, alarmLabel: s.alarm),
                const SizedBox(height: 6),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _table(s)),
                      ..._overlays(s),
                    ],
                  ),
                ),
                _instructions(s),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _table(Strings s) => LayoutBuilder(
        builder: (context, constraints) {
          final fit = DesignFit(constraints.biggest);
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _onDown(e, fit),
            onPointerMove: (e) => _onMove(e, fit),
            onPointerUp: _onUp,
            onPointerCancel: _onUp,
            onPointerHover: (e) => _onHover(e, fit),
            child: CustomPaint(
              painter: TablePainter(_session, s, widget.services.art),
              size: Size.infinite,
            ),
          );
        },
      );

  Widget _topBar(Strings s) {
    final level = widget.level;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: _session.pause,
            icon: const Icon(Icons.pause_rounded),
            color: Colors.white70,
            iconSize: 28,
            tooltip: s.paused,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.patientNumber(level.number)} · ${s.patient(level.sex, level.age)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${s.toRemove} ${s.findings(level.items)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B6B), size: 20),
              const SizedBox(width: 4),
              Text(
                '${_session.mistakes}',
                style: const TextStyle(
                    color: Color(0xFFFF8A80), fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _icon(StageKind kind) => switch (kind) {
        StageKind.inject => Icons.vaccines_rounded,
        StageKind.xray => Icons.center_focus_strong_rounded,
        StageKind.cut => Icons.content_cut_rounded,
        StageKind.extract => Icons.front_hand_rounded,
        StageKind.stitch => Icons.gesture_rounded,
      };

  Widget _instructions(Strings s) {
    final stage = _session.stage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      color: const Color(0xFF0B1513),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _session.stages.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _StageChip(
                    icon: _icon(_session.stages[i].kind),
                    done: i < _session.stageIndex ||
                        (i == _session.stageIndex && stage.isComplete),
                    current: i == _session.stageIndex,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.stageName(stage.kind).toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF80CBC4),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.instruction(stage.kind),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.25),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stage.progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF1E3D30),
              color: const Color(0xFF26A69A),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _overlays(Strings s) {
    final level = widget.level;
    final isLast = levels.indexOf(level) == levels.length - 1;
    return [
      if (_session.now < _penToastUntil)
        Positioned(
          top: 8,
          left: 16,
          right: 16,
          child: Center(child: Toast(text: s.penDetected)),
        ),
      if (_session.state == SessionState.stageClear)
        Center(child: StageClearBanner(text: s.great)),
      if (_session.state == SessionState.won)
        Panel(
          title: s.won,
          icon: Icons.verified_rounded,
          iconColor: const Color(0xFF39D98A),
          actions: [
            if (!isLast) PanelAction(label: s.next, onTap: _nextLevel, primary: true),
            PanelAction(label: s.retry, onTap: _restart),
            PanelAction(label: s.menu, onTap: () => Navigator.of(context).pop()),
          ],
          children: [
            StarRow(stars: _session.stars),
            const SizedBox(height: 12),
            StatLine(label: s.mistakes, value: '${_session.mistakes}'),
            StatLine(label: s.time, value: formatTime(_session.finishedAt ?? _session.now)),
            if (isLast) ...[
              const SizedBox(height: 12),
              Text(s.allCured, textAlign: TextAlign.center),
            ],
          ],
        ),
      if (_session.state == SessionState.failed)
        Panel(
          title: s.failed,
          icon: Icons.monitor_heart_rounded,
          iconColor: const Color(0xFFFF4D4D),
          actions: [
            PanelAction(label: s.retry, onTap: _restart, primary: true),
            PanelAction(label: s.menu, onTap: () => Navigator.of(context).pop()),
          ],
          children: [Text(s.failHint, textAlign: TextAlign.center)],
        ),
      if (_session.state == SessionState.paused)
        Panel(
          title: s.paused,
          icon: Icons.pause_circle_rounded,
          iconColor: const Color(0xFFCFE8E1),
          actions: [
            PanelAction(label: s.resume, onTap: _session.resume, primary: true),
            PanelAction(label: s.retry, onTap: _restart),
            PanelAction(label: s.menu, onTap: () => Navigator.of(context).pop()),
          ],
          children: const [],
        ),
    ];
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.icon, required this.done, required this.current});

  final IconData icon;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? const Color(0xFF26A69A)
        : current
            ? Colors.white
            : const Color(0xFF41675C);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: current ? const Color(0xFF1E4D42) : Colors.transparent,
        border: Border.all(color: color, width: 2.5),
      ),
      child: Icon(done ? Icons.check_rounded : icon, color: color, size: 22),
    );
  }
}

String formatTime(double seconds) {
  final total = seconds.floor();
  final m = total ~/ 60;
  final sec = (total % 60).toString().padLeft(2, '0');
  return '$m:$sec';
}
