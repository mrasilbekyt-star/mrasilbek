import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/settings.dart';
import 'data/store.dart';
import 'services/auth.dart';
import 'services/pro.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF070B12),
  ));
  final settings = await Settings.load();
  final store = await HududStore.open();
  final pro = await ProService.start(settings);
  final auth = await AuthService.start();
  runApp(HududApp(services: AppServices(settings: settings, store: store, pro: pro, auth: auth)));
}
