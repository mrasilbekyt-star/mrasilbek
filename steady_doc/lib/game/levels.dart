import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';

/// Fixed coordinates of the operating table, in design units.
///
/// Everything in the game is laid out on a 1000 x 1400 canvas that is scaled
/// to fit the screen, so speeds and tolerances behave the same on every phone.
abstract final class BodyLayout {
  static const Size design = Size(1000, 1400);

  /// Steel dish where extracted objects are collected (on the drapes).
  static const Rect tray = Rect.fromLTRB(790, 1170, 990, 1390);

  /// How far the syringe plunger travels, and how far below its end the
  /// needle tip is.
  static const double plungerTravel = 280;
  static const double needleBelowPlunger = 130;
}

enum Region { belly, hand, appendix, gallbladder, knee, flank, shoulder }

/// One patient's operating field: which pictures to show and where things are.
///
/// Pictures live in assets/art/ as `<id>_closed`, `<id>_open`, `<id>_xray` and
/// `<id>_done`. They are 3:4 portrait and cover the whole 1000 x 1400 canvas
/// (25 units cropped at each side); the coordinates below are measured on them.
class SceneDef {
  const SceneDef({
    required this.id,
    required this.region,
    required this.skin,
    required this.incisionStart,
    required this.incisionEnd,
    required this.workZone,
    this.syringe = const Offset(330, 440),
    this.itemSide = 0,
    this.opening,
    this.reach,
  });

  final String id;
  final Region region;

  /// Exposed skin between the drapes; everything happens inside it.
  final RRect skin;

  /// The incision runs from start to end; objects come out at its middle.
  final Offset incisionStart;
  final Offset incisionEnd;

  /// Where the findings can sit once the wound is open.
  final Rect workZone;

  /// Top of the syringe plunger before the injection.
  final Offset syringe;

  /// Side of the incision the findings sit on: 0 alternates between both
  /// sides, -1 or 1 keeps them on the one side where the organ is.
  final double itemSide;

  /// Outline of the opened wound when it is not a plain box; the findings
  /// stay inside it.
  final List<Offset>? opening;

  /// Farthest the findings can sit from the middle of the incision in a
  /// narrow wound; caps [LevelDef.minExitDistance].
  final double? reach;

  /// Corridors may bend slightly outside [workZone].
  Rect get corridorZone => workZone.inflate(30);
}

/// Geometry of every patient picture, measured on its `_open` layer.
SceneDef _scene(String id) => switch (id) {
      'hand_a' => SceneDef(
          id: id,
          region: Region.hand,
          skin: RRect.fromLTRBR(200, 430, 780, 1000, const Radius.circular(120)),
          incisionStart: const Offset(490, 590),
          incisionEnd: const Offset(490, 880),
          workZone: const Rect.fromLTRB(380, 560, 600, 900),
          syringe: const Offset(300, 360),
        ),
      'appendix_a' => SceneDef(
          id: id,
          region: Region.appendix,
          skin: RRect.fromLTRBR(60, 300, 940, 1250, const Radius.circular(160)),
          incisionStart: const Offset(230, 560),
          incisionEnd: const Offset(660, 1130),
          workZone: const Rect.fromLTRB(170, 640, 720, 1120),
          syringe: const Offset(800, 400),
        ),
      'torso_a' => SceneDef(
          id: id,
          region: Region.belly,
          skin: RRect.fromLTRBR(60, 80, 940, 1300, const Radius.circular(200)),
          incisionStart: const Offset(480, 150),
          incisionEnd: const Offset(480, 1150),
          workZone: const Rect.fromLTRB(180, 250, 760, 1100),
        ),
      'gall_a' => SceneDef(
          id: id,
          region: Region.gallbladder,
          skin: RRect.fromLTRBR(40, 100, 960, 1250, const Radius.circular(160)),
          incisionStart: const Offset(150, 820),
          incisionEnd: const Offset(760, 450),
          workZone: const Rect.fromLTRB(140, 440, 620, 800),
          syringe: const Offset(820, 520),
          itemSide: -1,
        ),
      'knee_a' => SceneDef(
          id: id,
          region: Region.knee,
          skin: RRect.fromLTRBR(80, 60, 920, 1250, const Radius.circular(160)),
          incisionStart: const Offset(500, 270),
          incisionEnd: const Offset(510, 1000),
          workZone: const Rect.fromLTRB(220, 300, 780, 1080),
        ),
      'flank_a' => SceneDef(
          id: id,
          region: Region.flank,
          skin: RRect.fromLTRBR(40, 100, 960, 1250, const Radius.circular(160)),
          incisionStart: const Offset(440, 320),
          incisionEnd: const Offset(470, 1010),
          workZone: const Rect.fromLTRB(170, 360, 720, 980),
          syringe: const Offset(780, 420),
        ),
      'shoulder_a' => SceneDef(
          id: id,
          region: Region.shoulder,
          skin: RRect.fromLTRBR(60, 80, 940, 1250, const Radius.circular(160)),
          incisionStart: const Offset(470, 200),
          incisionEnd: const Offset(470, 1040),
          workZone: const Rect.fromLTRB(220, 250, 720, 700),
          syringe: const Offset(820, 400),
        ),
      'belly_b' => SceneDef(
          id: id,
          region: Region.belly,
          skin: RRect.fromLTRBR(50, 310, 950, 1170, const Radius.circular(100)),
          incisionStart: const Offset(495, 395),
          incisionEnd: const Offset(500, 980),
          workZone: const Rect.fromLTRB(310, 385, 695, 990),
          opening: const [
            Offset(495, 388), Offset(555, 450), Offset(610, 500), Offset(675, 545),
            Offset(685, 790), Offset(620, 850), Offset(530, 950), Offset(500, 985),
            Offset(470, 950), Offset(380, 850), Offset(320, 790), Offset(320, 550),
            Offset(390, 500), Offset(440, 450),
          ],
          reach: 150,
        ),
      'belly_c' => SceneDef(
          id: id,
          region: Region.belly,
          skin: RRect.fromLTRBR(90, 210, 900, 1220, const Radius.circular(120)),
          incisionStart: const Offset(477, 310),
          incisionEnd: const Offset(482, 1040),
          workZone: const Rect.fromLTRB(290, 310, 690, 1045),
          opening: const [Offset(477, 305), Offset(690, 672), Offset(482, 1048), Offset(288, 670)],
          reach: 120,
        ),
      'belly_d' => SceneDef(
          id: id,
          region: Region.belly,
          skin: RRect.fromLTRBR(70, 100, 940, 1140, const Radius.circular(120)),
          incisionStart: const Offset(210, 730),
          incisionEnd: const Offset(800, 730),
          workZone: const Rect.fromLTRB(200, 610, 805, 1010),
          itemSide: 1,
          opening: const [
            Offset(195, 690), Offset(340, 635), Offset(480, 612), Offset(640, 628),
            Offset(800, 680), Offset(805, 735), Offset(700, 850), Offset(495, 1010),
            Offset(380, 920), Offset(220, 790), Offset(198, 745),
          ],
          reach: 160,
        ),
      'belly_e' => SceneDef(
          id: id,
          region: Region.belly,
          skin: RRect.fromLTRBR(90, 70, 920, 1250, const Radius.circular(140)),
          incisionStart: const Offset(485, 345),
          incisionEnd: const Offset(490, 1030),
          workZone: const Rect.fromLTRB(255, 345, 710, 1030),
          opening: const [
            Offset(420, 350), Offset(560, 350), Offset(640, 410), Offset(690, 520),
            Offset(705, 650), Offset(690, 800), Offset(650, 900), Offset(570, 990),
            Offset(490, 1030), Offset(410, 990), Offset(320, 900), Offset(270, 800),
            Offset(255, 650), Offset(270, 520), Offset(330, 410),
          ],
          reach: 210,
        ),
      // belly_a: a long midline laparotomy.
      _ => SceneDef(
          id: id,
          region: Region.belly,
          skin: RRect.fromLTRBR(160, 180, 840, 1240, const Radius.circular(140)),
          incisionStart: const Offset(500, 340),
          incisionEnd: const Offset(500, 1170),
          workZone: const Rect.fromLTRB(250, 300, 750, 1130),
        ),
    };

enum Sex { male, female }

/// Emoji used to draw each finding until a photo for it (`obj_<id>`) is added
/// to assets/art/.
const findingEmoji = {
  'coin': '🪙',
  'ring': '💍',
  'key': '🔑',
  'denture': '🦷',
  'battery': '🔋',
  'magnet': '🧲',
  'gallstone': '🪨',
  'kidneystone': '🪨',
  'bolt': '🔩',
  'pin': '🧷',
  'dice': '🎲',
  'pawn': '♟️',
  'spoon': '🥄',
  'toothbrush': '🪥',
  'fishhook': '🪝',
  'appendix': '🪱',
  'glass': '💎',
  'bone': '🦴',
  'metal': '⚙️',
};

/// What is wrong with a patient, as a key for [Strings.diagnosis].
enum Diagnosis {
  foreignBody,
  fishhook,
  appendicitis,
  glass,
  gallstones,
  looseBodies,
  kidneyStones,
  metal,
}

class LevelDef {
  const LevelDef({
    required this.number,
    required this.sex,
    required this.age,
    required this.scene,
    required this.diagnosis,
    required this.items,
    required this.injection,
    required this.difficulty,
    required this.skin,
  });

  final int number;
  final Sex sex;
  final int age;
  final SceneDef scene;
  final Diagnosis diagnosis;

  /// What has to come out, as keys of [findingEmoji].
  final List<String> items;

  /// Whether the level starts with an anesthesia injection.
  final bool injection;

  /// 0 for the first patient, 1 for the hardest one.
  final double difficulty;

  /// Skin tone for the drawn scene, used until the patient's pictures exist.
  final Color skin;

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

  /// How far the findings sit from the opening, shortened for small fields.
  double get minExitDistance =>
      math.min(mix(130, 270, difficulty), scene.reach ?? scene.workZone.shortestSide * 0.6);

  int get cutWaves => difficulty < 0.3
      ? 1
      : difficulty < 0.7
          ? 2
          : 3;
  double get cutAmplitude => mix(6, 30, difficulty);
  double get cutTolerance => mix(58, 32, difficulty);

  /// Distance between stitches along the incision.
  double get stitchSpacing => mix(115, 72, difficulty);
  double get stitchHitRadius => mix(44, 28, difficulty);
  double get stitchTolerance => mix(78, 46, difficulty);

  /// Fastest allowed plunger speed, in design units per second.
  double get injectSpeedLimit => mix(230, 130, difficulty);

  double get bpmPerMistake => mix(12, 19, difficulty);
}

final List<LevelDef> levels = _buildLevels();

List<LevelDef> _buildLevels() {
  const cases = <(Sex, int, String, Diagnosis, List<String>, Color)>[
    (Sex.male, 24, 'belly_a', Diagnosis.foreignBody, ['coin'], Color(0xFFE3B694)),
    (Sex.male, 45, 'hand_a', Diagnosis.fishhook, ['fishhook'], Color(0xFFC68E6A)),
    (Sex.female, 19, 'appendix_a', Diagnosis.appendicitis, ['appendix'], Color(0xFFD1A47A)),
    (Sex.male, 28, 'torso_a', Diagnosis.glass, ['glass', 'glass'], Color(0xFF6B4430)),
    (Sex.female, 31, 'belly_b', Diagnosis.foreignBody, ['ring', 'pin'], Color(0xFFA8754F)),
    (Sex.male, 54, 'gall_a', Diagnosis.gallstones, ['gallstone', 'gallstone'], Color(0xFFEFCFB8)),
    (Sex.female, 36, 'knee_a', Diagnosis.looseBodies, ['bone', 'bone'], Color(0xFFF1D2BE)),
    (Sex.male, 63, 'flank_a', Diagnosis.kidneyStones, ['kidneystone', 'kidneystone'], Color(0xFFB98260)),
    (Sex.male, 19, 'belly_c', Diagnosis.foreignBody, ['battery', 'magnet', 'dice'], Color(0xFFC4936B)),
    (Sex.male, 41, 'shoulder_a', Diagnosis.metal, ['metal', 'metal', 'metal'], Color(0xFFB07A55)),
    (Sex.female, 70, 'belly_d', Diagnosis.foreignBody, ['denture', 'spoon'], Color(0xFFEBD3C4)),
    (Sex.male, 49, 'belly_e', Diagnosis.foreignBody, ['key', 'bolt', 'toothbrush'], Color(0xFF5E3A28)),
  ];
  return [
    for (var i = 0; i < cases.length; i++)
      LevelDef(
        number: i + 1,
        sex: cases[i].$1,
        age: cases[i].$2,
        scene: _scene(cases[i].$3),
        diagnosis: cases[i].$4,
        items: cases[i].$5,
        injection: i > 0,
        difficulty: i / (cases.length - 1),
        skin: cases[i].$6,
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

  /// The incision, from the scene's start point to its end point.
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
    final scene = level.scene;
    final rnd = math.Random(level.seed);
    double between(double a, double b) => a + rnd.nextDouble() * (b - a);

    // Incision: a gentle wave along the scene's incision line.
    final a = scene.incisionStart;
    final b = scene.incisionEnd;
    final axis = (b - a) / (b - a).distance;
    final across = Offset(-axis.dy, axis.dx);
    final phase = rnd.nextBool() ? 1.0 : -1.0;
    final cutPts = <Offset>[];
    const steps = 80;
    for (var j = 0; j <= steps; j++) {
      final t = j / steps;
      cutPts.add(Offset.lerp(a, b, t)! +
          across * (phase * level.cutAmplitude * math.sin(math.pi * level.cutWaves * t)));
    }
    final cut = Polyline(resample(cutPts, 6));
    final exit = cut.at(cut.length / 2);

    // Objects: on the scene's side of the incision (or alternating sides), away
    // from it, from the exit and from each other.
    double side(Offset p) {
      final d = p - a;
      return d.dx * across.dx + d.dy * across.dy;
    }

    final zone = scene.workZone;
    final items = <Offset>[];
    for (var i = 0; i < level.items.length; i++) {
      final wantSide = scene.itemSide != 0 ? scene.itemSide : (i.isEven ? -1.0 : 1.0);
      Offset? chosen;
      Offset candidate = zone.center;
      for (var attempt = 0; attempt < 2000 && chosen == null; attempt++) {
        candidate = Offset(between(zone.left + 25, zone.right - 25),
            between(zone.top + 25, zone.bottom - 25));
        final inWound = scene.opening == null ||
            insidePolygon(scene.opening!, candidate, margin: 30);
        final offCut = side(candidate) * wantSide >= 75;
        final farFromExit = (candidate - exit).distance >= level.minExitDistance;
        final farFromOthers = items.every((q) => (candidate - q).distance >= 150);
        if (inWound && offCut && farFromExit && farFromOthers) chosen = candidate;
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
        pts.add(clampToRect(p, scene.corridorZone));
      }
      corridors.add(Polyline(resample(pts, 6)));
    }

    // Stitches zigzag across the incision, spaced for its length.
    final stitchTargets = <Offset>[];
    final count = (cut.length / level.stitchSpacing).round().clamp(5, 14);
    for (var i = 0; i < count; i++) {
      final s = cut.length * (i + 0.5) / count;
      final sideSign = i.isEven ? 1.0 : -1.0;
      stitchTargets.add(cut.at(s) + cut.normalAt(s) * (42 * sideSign));
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
