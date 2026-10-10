import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app.dart';
import '../core/geo.dart';
import '../run/location.dart';
import '../run/run_session.dart';
import '../services/phone_fitness.dart';
import 'run_screen.dart';
import 'theme.dart';

/// Default spot when the phone's location is unknown: central Tashkent.
const fallbackCenter = GeoPoint(41.3111, 69.2797);

/// Asks for what a run needs, then opens the run screen.
Future<void> startRun(BuildContext context) async {
  final app = AppScope.read(context);
  final s = app.settings.strings;
  final access = await DeviceLocation.ensureAccess();
  if (!context.mounted) return;
  if (access != LocationAccess.granted) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.surface,
        title: Text(s.locationNeededTitle),
        content: Text(switch (access) {
          LocationAccess.serviceOff => s.locationOff,
          LocationAccess.deniedForever => s.locationDeniedForever,
          _ => s.locationNeeded,
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
          if (access != LocationAccess.denied)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                access == LocationAccess.serviceOff
                    ? Geolocator.openLocationSettings()
                    : Geolocator.openAppSettings();
              },
              child: Text(s.openSettings),
            ),
        ],
      ),
    );
    return;
  }
  // The run notification needs this on Android 13+; the run works without it.
  if (defaultTargetPlatform == TargetPlatform.android) await Permission.notification.request();
  final steps = await PhoneFitness.steps();
  if (!context.mounted) return;
  final session = RunSession(
    source: DeviceLocation(notificationTitle: s.notificationTitle, notificationText: s.notificationText),
    territory: app.store.territory,
    weightKg: app.settings.weightKg,
    autoPause: app.settings.autoPause,
    steps: steps,
  );
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RunScreen(session: session)));
}

/// A pretend run near [center] that shows how claiming works.
Future<void> startDemo(BuildContext context, GeoPoint? center) async {
  final app = AppScope.read(context);
  final session = RunSession(
    source: DemoLocation(center ?? fallbackCenter),
    territory: app.store.territory,
    weightKg: app.settings.weightKg,
    demo: true,
  );
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RunScreen(session: session)));
}
