import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/mornye_player/providers/library_collections_provider.dart';
import 'package:musify/mornye_player/services/music_player_service.dart';
import 'package:musify/utilities/mediaitem.dart';

final musicPlayerRuntimeProvider = Provider<MusicPlayerRuntime>(
  (ref) => musicPlayerRuntime,
);

/// The device that plays is always this one: FluentMusic has no remote player.
final activeRemotePlaybackProvider = Provider<Object?>((ref) => null);

/// Whether this device sounds too while [activeRemotePlaybackProvider]
/// plays. There is no remote device, so this is always false.
final soundsBesideRemoteProvider = Provider<bool>((ref) => false);

/// External apps own playback on this device in Mornye. FluentMusic always
/// plays here, so its player controls stay live.
final playerUiEnabledProvider = Provider<bool>((ref) => true);

/// The active remote device's volume, 0 to 1; no value while this device
/// plays.
final activeRemoteVolumeProvider = StreamProvider<double>(
  (ref) => const Stream<double>.empty(),
);

final playbackStateProvider = StreamProvider<PlaybackState>(
  (ref) => audioHandler.playbackStateStream,
);

/// Small derived providers keep position ticks from rebuilding widgets that
/// only care about transport state (and vice versa).
final playbackPositionProvider = Provider<Duration>((ref) {
  return ref.watch(
    playbackStateProvider.select(
      (state) => state.value?.position ?? Duration.zero,
    ),
  );
});

final playbackPlayingProvider = Provider<bool>((ref) {
  return ref.watch(
    playbackStateProvider.select((state) => state.value?.playing ?? false),
  );
});

final playbackLoadingProvider = Provider<bool>((ref) {
  return ref.watch(
    playbackStateProvider.select((state) {
      final processingState = state.value?.processingState;
      return processingState == AudioProcessingState.loading ||
          processingState == AudioProcessingState.buffering;
    }),
  );
});

final playQueueProvider = StreamProvider<List<MediaItem>>(
  (ref) => audioHandler.queue,
);

/// What the player screens show: this device always plays, so it is simply the
/// handler's current item.
final currentMediaItemProvider = StreamProvider<MediaItem?>(
  (ref) => audioHandler.mediaItem,
);

/// Prefers the reported queue index while it still names an entry.
final currentQueueIndexProvider = Provider<int>((ref) {
  final queue = ref.watch(playQueueProvider).value ?? const <MediaItem>[];
  final index = ref.watch(
    playbackStateProvider.select((state) => state.value?.queueIndex),
  );
  if (index != null && index >= 0 && index < queue.length) return index;
  final fallback = audioHandler.currentQueueIndex;
  return fallback >= 0 && fallback < queue.length ? fallback : 0;
});

/// The song a queue entry is, for adding it to FluentMusic's liked songs.
final playerCollectionTrackProvider = FutureProvider.autoDispose
    .family<CollectionTrack, MediaItem>((ref, item) async {
      final ytid = item.extras?['ytid']?.toString();
      return CollectionTrack(
        item: item,
        ytid: ytid == null || ytid.isEmpty ? null : ytid,
      );
    });

/// Drives the player screens, mapped onto FluentMusic's audio handler.
class MusicPlayerController {
  Future<void> togglePlayPause(bool playing) =>
      playing ? audioHandler.pause() : audioHandler.play();

  Future<void> next() => audioHandler.skipToNext();

  Future<void> previous() => audioHandler.skipToPrevious();

  Future<void> seek(Duration position) => audioHandler.seek(position);

  Future<void> setShuffle(bool enabled) => audioHandler.setShuffleMode(
    enabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
  );

  Future<void> setRepeatMode(AudioServiceRepeatMode mode) =>
      audioHandler.setRepeatMode(mode);

  Future<void> jumpTo(int index) => audioHandler.skipToQueueItem(index);

  Future<void> moveQueueItem(int oldIndex, int newIndex) =>
      audioHandler.reorderQueue(oldIndex, newIndex);

  Future<void> removeQueuedItem(MediaItem item) async {
    final queue = audioHandler.queue.valueOrNull ?? const <MediaItem>[];
    final index = queue.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) await audioHandler.removeFromQueue(index);
  }

  /// Queues a copy of [item] right after the playing song. Resolves false
  /// when the song has nothing FluentMusic can queue.
  Future<bool> playQueuedItemNext(MediaItem item) async {
    final song = mediaItemToMap(item);
    if ((song['title']?.toString() ?? '').isEmpty) return false;
    await audioHandler.addToQueue(song, playNext: true);
    return true;
  }
}

final musicPlayerControllerProvider = Provider<MusicPlayerController>(
  (ref) => MusicPlayerController(),
);