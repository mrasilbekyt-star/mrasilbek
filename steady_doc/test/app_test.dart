import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:steady_doc/game/session.dart';
import 'package:steady_doc/main.dart';
import 'package:steady_doc/painting/art.dart';
import 'package:steady_doc/services/app_state.dart';
import 'package:steady_doc/services/services.dart';

final _services = Services(feedback: const SilentFeedback(), art: ArtAssets.none());

Future<AppState> _state(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  return AppState.load();
}

void main() {
  testWidgets('home, patient list and operating table', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = await _state({'lang': 'en'});
    await tester.pumpWidget(SteadyDocApp(state: state, services: _services));
    expect(find.text('STEADY DOC'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('PATIENT 1'), findsOneWidget);
    expect(find.text('Male, 24'), findsOneWidget);
    expect(find.text('coin'), findsOneWidget);
    // Patient 2 stays locked until patient 1 is cured.
    expect(find.text('Female, 31'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    expect(state.isUnlocked(2), isFalse);

    await tester.tap(find.text('Male, 24'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('X-RAY'), findsOneWidget);
    expect(find.text('Patient 1 · Male, 24'), findsOneWidget);
    expect(find.text('To remove: coin'), findsOneWidget);
    expect(find.text('HR'), findsOneWidget);
    expect(find.text('SpO2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('earned stars unlock the next patient', (tester) async {
    final state = await _state({'lang': 'uz', 'stars_1': 2});
    expect(state.isUnlocked(2), isTrue);
    expect(state.isUnlocked(3), isFalse);
    expect(state.totalStars, 2);

    await state.recordStars(1, 1);
    expect(state.starsFor(1), 2, reason: 'a worse result keeps the best one');
    await state.recordStars(1, 3);
    expect(state.starsFor(1), 3);

    await tester.pumpWidget(SteadyDocApp(state: state, services: _services));
    expect(find.text("O'ynash"), findsOneWidget);
  });

  testWidgets('settings switch the language', (tester) async {
    final state = await _state({'lang': 'en'});
    await tester.pumpWidget(SteadyDocApp(state: state, services: _services));
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Русский'));
    await tester.pump();
    expect(find.text('Настройки'), findsOneWidget);
    expect(state.language, 'ru');
  });

  testWidgets('the operating room pictures ship with the app', (tester) async {
    final art = (await tester.runAsync(() => ArtAssets.load(rootBundle)))!;
    expect(art.sceneClosed, isNotNull);
    expect(art.sceneOpen, isNotNull);
    expect(art.sceneXray, isNotNull);
    expect(art.sceneDone, isNotNull);
    // Scene pictures are 3:4 portrait, as the layout expects.
    for (final image in [art.sceneClosed!, art.sceneOpen!, art.sceneXray!, art.sceneDone!]) {
      expect(image.width / image.height, closeTo(0.75, 0.01));
    }
  });
}
