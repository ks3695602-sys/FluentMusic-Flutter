import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/mornye_player/models/settings.dart';
import 'package:musify/mornye_player/services/music_player_service.dart';

/// Player-facing preferences for the copied Mornye UI.
///
/// FluentMusic owns the real settings storage; this notifier keeps the handful
/// of values the player reads in memory and mirrors them into
/// [musicPlayerSettings] so the runtime's audio-info sheet sees the same
/// snapshot.
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  /// FluentMusic's player always shows the synced line under the title, as
  /// its own player did.
  @override
  AppSettings build() => const AppSettings(playerShowLyricSnippet: true);

  void _commit(AppSettings next) {
    state = next;
    musicPlayerSettings.value = next;
  }

  void setAutoplay(bool enabled) => _commit(state.copyWith(autoplay: enabled));

  void setAutoMix(bool enabled) => _commit(state.copyWith(autoMix: enabled));

  void setQueueLocked(bool locked) =>
      _commit(state.copyWith(queueLocked: locked));

  void setPlaybackSpeed(double speed) =>
      _commit(state.copyWith(playbackSpeed: playbackSpeedFromJson(speed)));

  void setPlaybackKeepPitch(bool keep) =>
      _commit(state.copyWith(playbackKeepPitch: keep));

  void setPlaybackPitch(double semitones) =>
      _commit(state.copyWith(playbackPitch: playbackPitchFromJson(semitones)));

  void setPlayerShowVolume(bool show) =>
      _commit(state.copyWith(playerShowVolume: show));

  void setPlayerShowLyricSnippet(bool show) =>
      _commit(state.copyWith(playerShowLyricSnippet: show));

  void resetPlaybackTempo() => _commit(
    state.copyWith(playbackSpeed: 1, playbackKeepPitch: true, playbackPitch: 0),
  );
}