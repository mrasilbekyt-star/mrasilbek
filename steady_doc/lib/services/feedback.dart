import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/session.dart';
import 'app_state.dart';

/// Plays the game's sounds and vibrations, respecting the player's settings.
class DeviceFeedback implements FeedbackSink {
  DeviceFeedback(this._app);

  final AppState _app;
  final Map<Sfx, AudioPlayer> _players = {};

  static const _volume = {
    Sfx.buzz: 0.9,
    Sfx.found: 0.7,
    Sfx.pop: 0.8,
    Sfx.stitch: 0.5,
    Sfx.stage: 0.7,
    Sfx.win: 0.8,
    Sfx.fail: 0.8,
  };

  /// Lets game sounds mix with the player's music instead of stopping it.
  static Future<void> configureAudio() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
    } catch (e) {
      debugPrint('Audio setup failed: $e');
    }
  }

  @override
  void play(Sfx sfx) {
    if (!_app.soundOn) return;
    unawaited(_play(sfx));
  }

  Future<void> _play(Sfx sfx) async {
    try {
      final player = _players.putIfAbsent(sfx, AudioPlayer.new);
      await player.stop();
      await player.play(
        AssetSource('sfx/${sfx.name}.wav'),
        volume: _volume[sfx],
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('Sound ${sfx.name} failed: $e');
    }
  }

  @override
  void haptic(Haptic haptic) {
    if (!_app.hapticsOn) return;
    final future = switch (haptic) {
      Haptic.light => HapticFeedback.lightImpact(),
      Haptic.medium => HapticFeedback.mediumImpact(),
      Haptic.heavy => HapticFeedback.heavyImpact(),
    };
    unawaited(future.catchError((Object e) => debugPrint('Haptic failed: $e')));
  }

  void dispose() {
    for (final player in _players.values) {
      unawaited(player.dispose());
    }
    _players.clear();
  }
}
