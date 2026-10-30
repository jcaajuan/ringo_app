import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Reproduce los efectos de sonido de `assets/sounds/` cuando la app está en
/// primer plano. En segundo plano el sonido lo pone el canal de la
/// notificación (ver `local_notification_service.dart`).
///
/// Nunca lanza: si falta el archivo de audio o el dispositivo no puede
/// reproducirlo, solo se escribe en el log.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  /// Volumen de notificaciones, no el de música. Si el de medios está en cero
  /// y esto saliera por `USAGE_MEDIA`, la alerta se oiría en silencio.
  static final AudioContext _contextoAlerta = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  /// Reproduce una vez [archivo] (sin ruta ni extensión, p. ej.
  /// `ringo_mensaje` → `assets/sounds/ringo_mensaje.mp3`).
  /// Devuelve false si el archivo no existe o el dispositivo no puede tocarlo.
  Future<bool> reproducir(String archivo) async {
    AudioPlayer? player;
    try {
      player = AudioPlayer();
      final actual = player;
      unawaited(
        actual.onPlayerComplete.first
            .timeout(const Duration(seconds: 30), onTimeout: () {})
            .whenComplete(() => _liberar(actual)),
      );
      await actual.play(
        AssetSource('sounds/$archivo.mp3'),
        volume: 1,
        mode: PlayerMode.mediaPlayer,
        ctx: _contextoAlerta,
      );
      return true;
    } catch (error) {
      debugPrint('No se pudo reproducir $archivo: $error');
      await _liberar(player);
      return false;
    }
  }

  Future<void> _liberar(AudioPlayer? player) async {
    if (player == null) return;
    try {
      await player.dispose();
    } catch (_) {}
  }
}
