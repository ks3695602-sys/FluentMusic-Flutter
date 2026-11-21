import 'package:flutter/foundation.dart';
import 'package:musify/mornye_player/models/settings.dart';

/// What the native deck applies to the stream, as the audio info sheet shows
/// it. FluentMusic's player keeps its own processing; nothing is reported.
class PlaybackProcessing {
  const PlaybackProcessing({
    required this.normalizationGain,
    required this.direct,
    required this.autoMixRate,
  });

  /// Linear volume from ReplayGain normalization; 1 when none applies.
  final double normalizationGain;

  /// A verified native direct path that bypasses the system mixer and DSP.
  final bool direct;

  /// AutoMix tempo matching; 1 outside a transition.
  final double autoMixRate;
}

/// The player behind the copied Mornye UI.
///
/// Playback itself stays on FluentMusic's [MusifyAudioHandler]; this object
/// only answers the facts the player surfaces ask for. Those surfaces all
/// treat a missing runtime as "nothing to report".
class MusicPlayerHandler {
  PlaybackProcessing? get processing => null;

  Future<void> refreshOutputStatus() async {}
}

/// The latest player-facing settings snapshot, kept in step by
/// `SettingsNotifier`. Read through [MusicPlayerRuntime.settings].
final musicPlayerSettings = ValueNotifier<AppSettings>(const AppSettings());

class MusicPlayerRuntime {
  MusicPlayerHandler? get handler => _handler;
  final MusicPlayerHandler _handler = MusicPlayerHandler();

  AppSettings get settings => musicPlayerSettings.value;

  Future<void> initialize() async {}
}

/// The single runtime the copied player UI talks to.
final musicPlayerRuntime = MusicPlayerRuntime();

/// Starts the runtime. FluentMusic's audio handler is already running by the
/// time the player can open, so there is nothing to boot.
Future<MusicPlayerHandler> initMusicPlayer() async => musicPlayerRuntime._handler;