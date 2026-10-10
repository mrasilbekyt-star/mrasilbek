import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/levels.dart';
import '../l10n/strings.dart';

/// Settings and progress, saved on the device.
class AppState extends ChangeNotifier {
  AppState._(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppState> load() async =>
      AppState._(await SharedPreferences.getInstance());

  String get language {
    final saved = _prefs.getString('lang');
    if (saved != null && Strings.supported.contains(saved)) return saved;
    final device = PlatformDispatcher.instance.locale.languageCode;
    return Strings.supported.contains(device) ? device : 'en';
  }

  Strings get strings => Strings(language);

  bool get soundOn => _prefs.getBool('sound') ?? true;
  bool get hapticsOn => _prefs.getBool('haptics') ?? true;

  int starsFor(int levelNumber) => _prefs.getInt('stars_$levelNumber') ?? 0;

  int get totalStars =>
      levels.fold(0, (sum, level) => sum + starsFor(level.number));

  bool isUnlocked(int levelNumber) =>
      levelNumber == 1 || starsFor(levelNumber - 1) > 0;

  Future<void> setLanguage(String code) async {
    await _prefs.setString('lang', code);
    notifyListeners();
  }

  Future<void> setSound(bool on) async {
    await _prefs.setBool('sound', on);
    notifyListeners();
  }

  Future<void> setHaptics(bool on) async {
    await _prefs.setBool('haptics', on);
    notifyListeners();
  }

  /// Keeps the best result for each level.
  Future<void> recordStars(int levelNumber, int stars) async {
    if (stars > starsFor(levelNumber)) {
      await _prefs.setInt('stars_$levelNumber', stars);
      notifyListeners();
    }
  }

  Future<void> resetProgress() async {
    for (final level in levels) {
      await _prefs.remove('stars_${level.number}');
    }
    notifyListeners();
  }
}

/// Makes [AppState] available to the widget tree and rebuilds on changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Like [of], without rebuilding the caller when the state changes.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
