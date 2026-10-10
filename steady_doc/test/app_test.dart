import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:steady_doc/game/session.dart';
import 'package:steady_doc/main.dart';
import 'package:steady_doc/services/app_state.dart';

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
    await tester.pumpWidget(SteadyDocApp(state: state, feedback: const SilentFeedback()));
    expect(find.text('Steady Doc'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Patient 1'), findsOneWidget);
    expect(find.text('Bobur'), findsOneWidget);
    // Patient 2 stays locked until patient 1 is cured.
    expect(find.text('Lola'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    expect(state.isUnlocked(2), isFalse);

    await tester.tap(find.text('Bobur'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('X-RAY'), findsOneWidget);
    expect(find.textContaining('Swallowed:'), findsOneWidget);

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

    await tester.pumpWidget(SteadyDocApp(state: state, feedback: const SilentFeedback()));
    expect(find.text("O'ynash"), findsOneWidget);
  });

  testWidgets('settings switch the language', (tester) async {
    final state = await _state({'lang': 'en'});
    await tester.pumpWidget(SteadyDocApp(state: state, feedback: const SilentFeedback()));
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Русский'));
    await tester.pump();
    expect(find.text('Настройки'), findsOneWidget);
    expect(state.language, 'ru');
  });
}
