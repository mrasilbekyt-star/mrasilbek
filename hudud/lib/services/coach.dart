import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../l10n/strings.dart';

/// Speaks during the run with the phone's text-to-speech.
///
/// Phones rarely ship an Uzbek voice, so the coach falls back to Russian and
/// then English, and speaks the sentence in the language it can pronounce.
class VoiceCoach {
  final FlutterTts _tts = FlutterTts();
  Strings? _voice;
  bool _ready = false;

  Future<void> prepare(Strings app) async {
    if (_ready) return;
    try {
      for (final lang in {app.lang, 'ru', 'en'}) {
        final strings = Strings(lang);
        if (await _tts.isLanguageAvailable(strings.speechLocale) == true) {
          await _tts.setLanguage(strings.speechLocale);
          _voice = strings;
          break;
        }
      }
      await _tts.setSpeechRate(0.5);
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Lowers the music instead of pausing it, like navigation apps do.
        await _tts.setAudioAttributesForNavigation();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ]);
      }
      _ready = true;
    } catch (e) {
      debugPrint('Hudud: no text-to-speech: $e');
    }
  }

  /// Says [line] in the coach's language.
  void say(String Function(Strings s) line) {
    final voice = _voice;
    if (!_ready || voice == null) return;
    unawaited(_tts.speak(line(voice)).catchError((Object _) => null));
  }

  Future<void> stop() async {
    if (_ready) await _tts.stop();
  }
}
