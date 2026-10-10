import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudud/app.dart';
import 'package:hudud/core/geo.dart';
import 'package:hudud/core/hex_grid.dart';
import 'package:hudud/data/models.dart';
import 'package:hudud/data/settings.dart';
import 'package:hudud/data/stats.dart';
import 'package:hudud/data/store.dart';
import 'package:hudud/l10n/strings.dart';
import 'package:hudud/map/hudud_map.dart';
import 'package:hudud/services/gpx.dart';
import 'package:hudud/services/pro.dart';
import 'package:hudud/ui/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppServices> services({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues({'lang': 'uz', ...prefs});
  final settings = await Settings.load();
  final store = HududStore(Directory.systemTemp.createTempSync('hudud_test'));
  final pro = ProService(settings, await SharedPreferences.getInstance());
  return AppServices(settings: settings, store: store, pro: pro);
}

RunRecord record(String id, DateTime start, {double km = 5, double area = 20000, int loops = 1}) => RunRecord(
      id: id,
      start: start,
      end: start.add(const Duration(minutes: 30)),
      movingSeconds: (km * 330).round(),
      distance: km * 1000,
      newArea: area,
      newCells: 10,
      loops: loops,
      biggestLoop: area,
      splits: [for (var i = 0; i < km.floor(); i++) 330 - i],
      calories: km * 70,
    );

/// Like pumpAndSettle, for screens with never-ending animations.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => hududMapPreview = true);

  testWidgets('first launch shows the three onboarding pages, then the map', (tester) async {
    phone(tester);
    final app = await services();
    await tester.pumpWidget(HududApp(services: app));
    final s = app.settings.strings;
    expect(find.text(s.onboardTitle1), findsOneWidget);
    await tester.tap(find.text(s.next));
    await settle(tester);
    expect(find.text(s.onboardTitle2), findsOneWidget);
    await tester.tap(find.text(s.next));
    await settle(tester);
    await tester.tap(find.text(s.letsGo));
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text(s.start), findsOneWidget);
  });

  testWidgets('every screen opens from home in all three languages', (tester) async {
    phone(tester);
    for (final lang in Strings.supported) {
      final app = await services(prefs: {'onboarded': true, 'lang': lang});
      await tester.pumpWidget(HududApp(services: app));
      await tester.pump();
      final s = app.settings.strings;
      await tester.tap(find.byTooltip(s.profile));
      await settle(tester);
      expect(find.text(s.weeklyMissions.toUpperCase()), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await settle(tester);
      expect(find.text(s.voiceCoach), findsWidgets);
      await tester.pageBack();
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.byTooltip(s.history));
      await settle(tester);
      expect(find.text(s.noRuns), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a demo run claims land, shows the summary and saves nothing', (tester) async {
    phone(tester);
    final app = await services(prefs: {'onboarded': true, 'voice': false});
    await tester.pumpWidget(HududApp(services: app));
    await tester.pump();
    final s = app.settings.strings;
    await tester.tap(find.text(s.demoRun));
    await tester.pump();
    // The demo runs ten times faster than life: about a minute of fixes.
    for (var i = 0; i < 700; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('+'), findsWidgets);
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    final stop = tester.getCenter(find.byIcon(Icons.stop_rounded));
    final gesture = await tester.startGesture(stop);
    // Holding fills the ring frame by frame; a quick tap would not finish.
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(s.greatRun), findsOneWidget);
    expect(find.text(s.demoNotSaved), findsOneWidget);
    expect(app.store.runs, isEmpty);
    expect(app.store.territory.length, 0);
  });

  test('stats: streaks, ranks, records and weekly missions', () {
    final now = DateTime(2026, 10, 14, 20); // a Wednesday
    final runs = [
      record('a', DateTime(2026, 10, 14, 6, 30)),
      record('b', DateTime(2026, 10, 13, 19)),
      record('c', DateTime(2026, 10, 12, 19), km: 10.5),
      record('d', DateTime(2026, 10, 8, 19)),
    ];
    final stats = Stats(runs, territoryArea: 60000, now: now);
    expect(stats.currentStreak, 3);
    expect(stats.bestStreak, 3);
    expect(stats.earlyRuns, 1);
    expect(stats.longestRun, 10500);
    expect(stats.fastestKm, 321);
    expect(stats.thisWeek, hasLength(3));
    expect(Mission.weekly.first.value(stats), 20500);
    expect(Mission.weekly.first.done(stats), isTrue);
    final unlocked = {for (final a in Achievement.all) if (a.unlocked(stats)) a.id};
    expect(unlocked, containsAll(['first_run', 'first_loop', 'area_1ha', 'km_5', 'km_10', 'streak_3', 'early']));
    expect(unlocked, isNot(contains('area_10ha')));
    expect(stats.rank, greaterThan(0));
  });

  test('the store saves runs and territory and reads them back', () async {
    final dir = Directory.systemTemp.createTempSync('hudud_store');
    final store = HududStore(dir);
    final cell = HexGrid.cellAtGeo(const GeoPoint(41.3111, 69.2797));
    final route = RunRoute([
      const RoutePoint(GeoPoint(41.3111, 69.2797), 0),
      const RoutePoint(GeoPoint(41.3112, 69.2799), 5),
      const RoutePoint(GeoPoint(41.3120, 69.2810), 60, startsStretch: true),
      const RoutePoint(GeoPoint(41.3121, 69.2812), 65),
    ], [cell]);
    await store.addRun(record('r1', DateTime(2026, 10, 11, 7)), route);

    final again = HududStore(dir);
    await again.load();
    expect(again.runs.single.id, 'r1');
    expect(again.territory.cells, {cell});
    final back = (await again.route('r1'))!;
    expect(back.stretches, hasLength(2));
    expect(back.points[1].pos.lat, closeTo(41.3112, 1e-6));
    expect(back.points[2].seconds, 60);

    final gpx = buildGpx([(again.runs.single, back)]);
    expect(RegExp('<trkseg>').allMatches(gpx), hasLength(2));
    expect(gpx, contains('lat="41.311200"'));

    await again.clear();
    expect(again.runs, isEmpty);
    expect(dir.existsSync(), isFalse);
  });

  test('a damaged index does not lock the player out', () async {
    final dir = Directory.systemTemp.createTempSync('hudud_broken');
    File('${dir.path}/index.json').writeAsStringSync('{not json');
    final store = HududStore(dir);
    await store.load();
    expect(store.runs, isEmpty);
    expect(File('${dir.path}/index.json.broken').existsSync(), isTrue);
  });
}
