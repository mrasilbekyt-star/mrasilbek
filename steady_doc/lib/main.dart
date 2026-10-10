import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'painting/art.dart';
import 'services/app_state.dart';
import 'services/feedback.dart';
import 'services/services.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = await AppState.load();
  await DeviceFeedback.configureAudio();
  final art = await ArtAssets.load(rootBundle);
  runApp(SteadyDocApp(
    state: state,
    services: Services(feedback: DeviceFeedback(state), art: art),
  ));
}

class SteadyDocApp extends StatelessWidget {
  const SteadyDocApp({super.key, required this.state, required this.services});

  final AppState state;
  final Services services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Steady Doc',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1FA67A),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF070D0B),
        ),
        home: HomeScreen(services: services),
      ),
    );
  }
}
