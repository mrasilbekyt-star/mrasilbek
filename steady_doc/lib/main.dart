import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/session.dart';
import 'services/app_state.dart';
import 'services/feedback.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = await AppState.load();
  await DeviceFeedback.configureAudio();
  runApp(SteadyDocApp(state: state, feedback: DeviceFeedback(state)));
}

class SteadyDocApp extends StatelessWidget {
  const SteadyDocApp({super.key, required this.state, required this.feedback});

  final AppState state;
  final FeedbackSink feedback;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Steady Doc',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
        ),
        home: HomeScreen(feedback: feedback),
      ),
    );
  }
}
