import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/models.dart';

/// The phone's own fitness features, all optional: Health Connect (and
/// Samsung Health through it) or Apple Health, and the step counter.
class PhoneFitness {
  final Health _health = Health();
  bool _configured = false;

  List<HealthDataType> get _types => defaultTargetPlatform == TargetPlatform.iOS
      ? const [HealthDataType.WORKOUT, HealthDataType.DISTANCE_WALKING_RUNNING, HealthDataType.ACTIVE_ENERGY_BURNED]
      : const [HealthDataType.WORKOUT, HealthDataType.DISTANCE_DELTA, HealthDataType.TOTAL_CALORIES_BURNED];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Whether Health Connect is missing and has to be installed first.
  Future<bool> needsHealthConnect() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _configure();
      return await _health.getHealthConnectSdkStatus() != HealthConnectSdkStatus.sdkAvailable;
    } catch (_) {
      return true;
    }
  }

  Future<void> installHealthConnect() => _health.installHealthConnect();

  /// Asks to write runs to the health app; true when allowed.
  Future<bool> connect() async {
    try {
      await _configure();
      return await _health.requestAuthorization(
        _types,
        permissions: [for (final _ in _types) HealthDataAccess.WRITE],
      );
    } catch (e) {
      debugPrint('Hudud: health permission failed: $e');
      return false;
    }
  }

  /// Writes a finished run as a workout; false when it could not.
  Future<bool> saveRun(RunRecord run, {required String title}) async {
    try {
      await _configure();
      return await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.RUNNING,
        start: run.start,
        end: run.end,
        totalDistance: run.distance.round(),
        totalEnergyBurned: run.calories.round(),
        title: title,
      );
    } catch (e) {
      debugPrint('Hudud: could not save the run to the health app: $e');
      return false;
    }
  }

  /// Steps counted from the first reading of the phone's step sensor, or
  /// null when the sensor or its permission is missing.
  static Future<Stream<int>?> steps() async {
    if (defaultTargetPlatform == TargetPlatform.android &&
        !await Permission.activityRecognition.request().isGranted) {
      return null;
    }
    int? first;
    return Pedometer.stepCountStream.map((e) {
      first ??= e.steps;
      return e.steps - first!;
    }).handleError((Object e) => debugPrint('Hudud: step counter: $e'));
  }
}
