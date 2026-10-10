import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/geo.dart';
import '../l10n/strings.dart';
import '../map/map_style.dart';

/// Colors a territory can be painted in. The first one is free.
const skins = <Color>[
  Color(0xFF3DFFA2), // mint
  Color(0xFF22E5FF), // cyan
  Color(0xFF9B7BFF), // violet
  Color(0xFFFF4FD8), // magenta
  Color(0xFFFFB020), // amber
  Color(0xFFFF5E6C), // coral
  Color(0xFFFFD84D), // gold
  Color(0xFFC6FF3D), // lime
];

/// Whether this build lets testers switch Pro on without paying
/// (`flutter build apk --dart-define=PRO_PREVIEW=true`).
const proPreviewBuild = bool.fromEnvironment('PRO_PREVIEW');

/// The player's choices, saved on the phone.
class Settings extends ChangeNotifier {
  Settings(this._prefs);

  final SharedPreferences _prefs;

  static Future<Settings> load() async => Settings(await SharedPreferences.getInstance());

  String get language {
    final saved = _prefs.getString('lang');
    if (saved != null && Strings.supported.contains(saved)) return saved;
    final device = PlatformDispatcher.instance.locale.languageCode;
    return Strings.supported.contains(device) ? device : 'uz';
  }

  Strings get strings => Strings(language);

  double get weightKg => _prefs.getDouble('weight') ?? 70;
  int get skinIndex => (_prefs.getInt('skin') ?? 0).clamp(0, skins.length - 1);
  Color get skin => skins[skinIndex];
  MapTheme get mapTheme => MapTheme.byId(_prefs.getString('map'));
  bool get voiceCoach => _prefs.getBool('voice') ?? true;
  bool get haptics => _prefs.getBool('haptics') ?? true;
  bool get healthSync => _prefs.getBool('health') ?? false;
  bool get autoPause => _prefs.getBool('autoPause') ?? true;
  bool get onboarded => _prefs.getBool('onboarded') ?? false;
  bool get proPreview => proPreviewBuild && (_prefs.getBool('proPreview') ?? true);

  /// The privacy zone: around this point shared routes are hidden.
  GeoPoint? get home {
    final lat = _prefs.getDouble('homeLat');
    final lon = _prefs.getDouble('homeLon');
    return lat == null || lon == null ? null : GeoPoint(lat, lon);
  }

  static const homeRadius = 250.0;

  Future<void> _set(Future<bool> write) async {
    await write;
    notifyListeners();
  }

  Future<void> setLanguage(String code) => _set(_prefs.setString('lang', code));
  Future<void> setWeight(double kg) => _set(_prefs.setDouble('weight', kg));
  Future<void> setSkin(int index) => _set(_prefs.setInt('skin', index));
  Future<void> setMapTheme(MapTheme theme) => _set(_prefs.setString('map', theme.id));
  Future<void> setVoiceCoach(bool on) => _set(_prefs.setBool('voice', on));
  Future<void> setHaptics(bool on) => _set(_prefs.setBool('haptics', on));
  Future<void> setHealthSync(bool on) => _set(_prefs.setBool('health', on));
  Future<void> setAutoPause(bool on) => _set(_prefs.setBool('autoPause', on));
  Future<void> setOnboarded() => _set(_prefs.setBool('onboarded', true));
  Future<void> setProPreview(bool on) => _set(_prefs.setBool('proPreview', on));

  Future<void> setHome(GeoPoint? p) async {
    if (p == null) {
      await _prefs.remove('homeLat');
      await _prefs.remove('homeLon');
    } else {
      await _prefs.setDouble('homeLat', p.lat);
      await _prefs.setDouble('homeLon', p.lon);
    }
    notifyListeners();
  }
}
