import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';

/// Fixed coordinates of the operating table, in design units.
///
/// Everything in the game is laid out on a 1000 x 1400 canvas that is scaled
/// to fit the screen, so speeds and tolerances behave the same on every phone.
abstract final class BodyLayout {
  static const Size design = Size(1000, 1400);

  static const Offset headCenter = Offset(500, 240);
  static const double headRadius = 130;

  static final RRect torso =
      RRect.fromLTRBR(250, 390, 750, 1260, const Radius.circular(170));
  static const Rect leftArm = Rect.fromLTRB(128, 420, 238, 1080);
  static const Rect rightArm = Rect.fromLTRB(762, 420, 872, 1080);

  /// Where swallowed objects can sit.
  static const Rect workZone = Rect.fromLTRB(300, 480, 700, 1170);

  /// Corridors may bend slightly outside [workZone] but never leave the torso.
  static const Rect corridorZone = Rect.fromLTRB(290, 460, 710, 1190);

  static const double incisionTop = 590;
  static const double incisionBottom = 1070;

  /// Syringe on the left arm: the plunger handle travels from start to end.
  static const double syringeX = 183;
  static const double plungerStart = 440;
  static const double plungerEnd = 720;
  static const double needleTipY = 850;

  /// Where extracted objects are collected.
  static const Rect tray = Rect.fromLTRB(790, 1170, 990, 1390);
}

enum HairStyle { short, long, bald, bun, spiky }

class LevelDef {
  const LevelDef({
    required this.number,
    required this.patient,
    required this.items,
    required this.injection,
    required this.difficulty,
    required this.skin,
    required this.hair,
    required this.hairStyle,
  });

  final int number;
  final String patient;

  /// Emoji of the objects the patient swallowed.
  final List<String> items;

  /// Whether the level starts with an anesthesia injection.
  final bool injection;

  /// 0 for the first patient, 1 for the hardest one.
  final double difficulty;

  final Color skin;
  final Color hair;
  final HairStyle hairStyle;

  int get seed => number * 7919 + 17;

  double get corridorWidth => mix(150, 88, difficulty);
  int get corridorWaves => difficulty < 0.15
      ? 0
      : difficulty < 0.5
          ? 1
          : difficulty < 0.8
              ? 2
              : 3;
  double get corridorAmplitude => mix(22, 60, difficulty);
  double get minExitDistance => mix(130, 270, difficulty);

  int get cutWaves => difficulty < 0.3
      ? 1
      : difficulty < 0.7
          ? 2
          : 3;
  double get cutAmplitude => mix(12, 55, difficulty);
  double get cutTolerance => mix(58, 32, difficulty);

  int get stitchCount => 4 + (difficulty * 4).round();
  double get stitchHitRadius => mix(44, 28, difficulty);
  double get stitchTolerance => mix(78, 46, difficulty);

  /// Fastest allowed plunger speed, in design units per second.
  double get injectSpeedLimit => mix(230, 130, difficulty);

  double get bpmPerMistake => mix(12, 19, difficulty);
}

const _skins = [
  Color(0xFFF2C9A0),
  Color(0xFFE0AC69),
  Color(0xFFC68642),
  Color(0xFFF7D7C4),
  Color(0xFF8D5524),
];

final List<LevelDef> levels = _buildLevels();

List<LevelDef> _buildLevels() {
  const specs = <(String, List<String>, HairStyle, Color)>[
    ('Bobur', ['🚗'], HairStyle.short, Color(0xFF2B2B2B)),
    ('Lola', ['🐟'], HairStyle.long, Color(0xFF6B3E26)),
    ('Timur', ['🔑', '🪙'], HairStyle.spiky, Color(0xFF3B2A20)),
    ('Zara buvi', ['🦆'], HairStyle.bun, Color(0xFFBDBDBD)),
    ('Mr. Pickles', ['📱', '🔋'], HairStyle.bald, Color(0xFF000000)),
    ('Ozod', ['🎲', '🧦'], HairStyle.short, Color(0xFF4A3426)),
    ('Nilufar', ['🍌', '🍓'], HairStyle.long, Color(0xFF1E1E1E)),
    ('Kapitan Bek', ['⚓', '🦀'], HairStyle.spiky, Color(0xFFB5531F)),
    ('Sardor', ['🎮', '🔦'], HairStyle.short, Color(0xFF2E2016)),
    ('Malika', ['💍', '💎', '🪙'], HairStyle.bun, Color(0xFF5A2E1A)),
    ('Jasur', ['🧲', '🔩', '⚙️'], HairStyle.spiky, Color(0xFF151515)),
    ('Big Boss', ['🍔', '🍟', '🌭'], HairStyle.bald, Color(0xFF000000)),
  ];
  return [
    for (var i = 0; i < specs.length; i++)
      LevelDef(
        number: i + 1,
        patient: specs[i].$1,
        items: specs[i].$2,
        injection: i > 0,
        difficulty: i / (specs.length - 1),
        skin: _skins[i % _skins.length],
        hair: specs[i].$4,
        hairStyle: specs[i].$3,
      ),
  ];
}

/// Positions and paths for one level, generated deterministically from its seed.
class LevelLayout {
  LevelLayout._({
    required this.cut,
    required this.exit,
    required this.items,
    required this.corridors,
    required this.stitchTargets,
  });

  /// The incision, from top to bottom.
  final Polyline cut;

  /// Opening in the incision where objects are pulled out.
  final Offset exit;

  /// Where each swallowed object sits, in the order of [LevelDef.items].
  final List<Offset> items;

  /// Safe channel from each object to [exit].
  final List<Polyline> corridors;

  /// Stitch points, alternating sides of the incision.
  final List<Offset> stitchTargets;

  factory LevelLayout.generate(LevelDef level) {
    final rnd = math.Random(level.seed);
    double between(double a, double b) => a + rnd.nextDouble() * (b - a);

    // Incision: a gentle wave down the middle of the torso.
    final phase = rnd.nextBool() ? 1.0 : -1.0;
    final cutPts = <Offset>[];
    const steps = 80;
    for (var j = 0; j <= steps; j++) {
      final t = j / steps;
      cutPts.add(Offset(
        500 + phase * level.cutAmplitude * math.sin(math.pi * level.cutWaves * t),
        mix(BodyLayout.incisionTop, BodyLayout.incisionBottom, t),
      ));
    }
    final cut = Polyline(resample(cutPts, 6));
    final exit = cut.at(cut.length / 2);

    // Objects: alternate left and right of the incision, away from the exit
    // and from each other.
    final items = <Offset>[];
    for (var i = 0; i < level.items.length; i++) {
      final left = i.isEven;
      Offset? chosen;
      Offset candidate = Offset.zero;
      for (var attempt = 0; attempt < 300 && chosen == null; attempt++) {
        candidate = Offset(
          left ? between(320, 420) : between(580, 680),
          between(510, 1150),
        );
        final farFromExit = (candidate - exit).distance >= level.minExitDistance;
        final farFromOthers =
            items.every((q) => (candidate - q).distance >= 170);
        if (farFromExit && farFromOthers) chosen = candidate;
      }
      items.add(chosen ?? candidate);
    }

    // Corridors: a wavy channel from each object to the exit.
    final corridors = <Polyline>[];
    for (final start in items) {
      final delta = exit - start;
      final len = delta.distance;
      final dir = delta / len;
      final normal = Offset(-dir.dy, dir.dx);
      final waves = level.corridorWaves;
      final amp = waves == 0 ? 0.0 : math.min(level.corridorAmplitude, len * 0.22);
      final sign = rnd.nextBool() ? 1.0 : -1.0;
      final n = math.max(8, (len / 6).ceil());
      final pts = <Offset>[];
      for (var j = 0; j <= n; j++) {
        final t = j / n;
        final p = start + delta * t + normal * (sign * amp * math.sin(math.pi * waves * t));
        pts.add(clampToRect(p, BodyLayout.corridorZone));
      }
      corridors.add(Polyline(resample(pts, 6)));
    }

    // Stitches zigzag across the incision.
    final stitchTargets = <Offset>[];
    final count = level.stitchCount;
    for (var i = 0; i < count; i++) {
      final s = cut.length * (i + 0.5) / count;
      final side = i.isEven ? 1.0 : -1.0;
      stitchTargets.add(cut.at(s) + cut.normalAt(s) * (42 * side));
    }

    return LevelLayout._(
      cut: cut,
      exit: exit,
      items: items,
      corridors: corridors,
      stitchTargets: stitchTargets,
    );
  }
}
