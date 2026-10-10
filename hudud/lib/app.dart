import 'package:flutter/material.dart';

import 'data/settings.dart';
import 'data/store.dart';
import 'map/map_style.dart';
import 'services/coach.dart';
import 'services/phone_fitness.dart';
import 'services/pro.dart';
import 'ui/home_screen.dart';
import 'ui/onboarding.dart';
import 'ui/theme.dart';

/// Everything the screens share.
class AppServices {
  AppServices({
    required this.settings,
    required this.store,
    required this.pro,
    VoiceCoach? coach,
    PhoneFitness? fitness,
  })  : coach = coach ?? VoiceCoach(),
        fitness = fitness ?? PhoneFitness();

  final Settings settings;
  final HududStore store;
  final ProService pro;
  final VoiceCoach coach;
  final PhoneFitness fitness;

  /// The territory color actually shown: Pro colors need Pro.
  Color get skin => pro.isPro ? settings.skin : skins.first;

  /// The map look actually shown: Pro styles need Pro.
  MapTheme get mapTheme {
    final theme = settings.mapTheme;
    return theme.pro && !pro.isPro ? MapTheme.night : theme;
  }

  /// Fires when settings, saved runs or the Pro status change.
  late final Listenable changes = Listenable.merge([settings, store, pro]);
}

/// Gives every screen the services, and rebuilds the ones that use [of]
/// whenever settings, runs or Pro change.
class AppScope extends InheritedNotifier<Listenable> {
  AppScope({super.key, required this.services, required super.child}) : super(notifier: services.changes);

  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;

  /// For callbacks and initState, where the widget must not subscribe.
  static AppServices read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.services;
}

class HududApp extends StatelessWidget {
  const HududApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) => AppScope(
        services: services,
        child: ListenableBuilder(
          listenable: services.changes,
          builder: (context, _) => MaterialApp(
            title: 'Hudud',
            debugShowCheckedModeBanner: false,
            theme: hududTheme(services.skin),
            home: services.settings.onboarded ? const HomeScreen() : const OnboardingScreen(),
          ),
        ),
      );
}
