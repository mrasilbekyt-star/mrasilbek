import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/geo.dart';
import '../core/gps_filter.dart';

/// Where GPS readings come from during a run.
abstract class LocationSource {
  /// Readings while the run lasts; listening starts the GPS.
  Stream<Fix> fixes();

  /// The clock the run is timed with.
  DateTime now();
}

enum LocationAccess { granted, denied, deniedForever, serviceOff }

/// The phone's GPS, kept alive with a notification while the screen is off.
class DeviceLocation implements LocationSource {
  DeviceLocation({required this.notificationTitle, required this.notificationText});

  final String notificationTitle;
  final String notificationText;

  static Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  /// Where the phone is now, without asking for permission.
  static Future<Fix?> current() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        return null;
      }
      final p = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(timeLimit: Duration(seconds: 15)),
          );
      return _toFix(p);
    } catch (_) {
      return null;
    }
  }

  /// A light stream for showing the runner on the map outside a run.
  static Stream<Fix> watch() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(distanceFilter: 5),
      ).map(_toFix);

  static Fix _toFix(Position p) =>
      Fix(GeoPoint(p.latitude, p.longitude), time: p.timestamp, accuracy: p.accuracy);

  @override
  Stream<Fix> fixes() {
    final LocationSettings settings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: notificationTitle,
            notificationText: notificationText,
            notificationChannelName: 'Hudud',
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      TargetPlatform.iOS => AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        ),
      _ => const LocationSettings(accuracy: LocationAccuracy.best),
    };
    return Geolocator.getPositionStream(locationSettings: settings).map(_toFix);
  }

  @override
  DateTime now() => DateTime.now();
}

/// A pretend run around two blocks near [center], ten times faster than
/// life, so the capture can be tried from the sofa. Demo runs are not saved.
class DemoLocation implements LocationSource {
  DemoLocation(this.center, {this.speed = 3.3, this.speedUp = 10, DateTime? start})
      : _now = start ?? DateTime.now();

  final GeoPoint center;

  /// Meters per second of the pretend runner.
  final double speed;

  /// How many pretend seconds pass in one real second.
  final int speedUp;

  DateTime _now;

  /// The pretend route, one point per pretend second.
  List<GeoPoint> route() {
    final o = Plane.toPlane(center) - const Vec(90, 70);
    final waypoints = <Vec>[
      // Block one, all the way round and a little past the start.
      const Vec(0, 0), const Vec(160, 0), const Vec(160, 120), const Vec(0, 120), const Vec(0, -18),
      // Across the street to block two, and round it.
      const Vec(190, -18), const Vec(380, -18), const Vec(380, 150), const Vec(190, 150), const Vec(190, -35),
    ];
    final rnd = math.Random(7);
    final out = <GeoPoint>[];
    var carry = 0.0;
    for (var i = 1; i < waypoints.length; i++) {
      final a = waypoints[i - 1];
      final b = waypoints[i];
      final length = a.distanceTo(b);
      var s = carry;
      for (; s < length; s += speed) {
        final p = a + (b - a) * (s / length);
        final noise = Vec(rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1) * 1.2;
        out.add(Plane.toGeo(o + p + noise));
      }
      carry = s - length;
    }
    return out;
  }

  @override
  Stream<Fix> fixes() async* {
    for (final p in route()) {
      await Future<void>.delayed(Duration(milliseconds: 1000 ~/ speedUp));
      _now = _now.add(const Duration(seconds: 1));
      yield Fix(p, time: _now, accuracy: 4);
    }
  }

  @override
  DateTime now() => _now;
}
