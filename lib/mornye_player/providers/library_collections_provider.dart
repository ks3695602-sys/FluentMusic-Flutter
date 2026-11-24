import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/utilities/mediaitem.dart';

/// A song the player can add to or remove from FluentMusic's liked songs.
///
/// Mornye keeps a Library database; FluentMusic identifies a song by its
/// YouTube id, carried in the [MediaItem]'s extras.
class CollectionTrack {
  const CollectionTrack({required this.item, this.ytid});

  final MediaItem item;
  final String? ytid;

  /// The song data FluentMusic stores for a liked song.
  Map<String, dynamic> get songData => mediaItemToMap(item);
}

class LibraryCollectionsState {
  const LibraryCollectionsState({this.lovedIds = const {}});

  final Set<String> lovedIds;

  bool isLoved(CollectionTrack track) {
    final id = track.ytid;
    return id != null && id.isNotEmpty && lovedIds.contains(id);
  }
}

Set<String> _lovedIds() => {
  for (final song in userLikedSongsList.value)
    if (song is Map && (song['ytid']?.toString() ?? '').isNotEmpty)
      song['ytid'].toString(),
};

/// FluentMusic's liked songs, as a stream the provider layer can watch.
final _lovedSongIdsProvider = StreamProvider<Set<String>>((ref) {
  final events = StreamController<Set<String>>.broadcast();
  void changed() => events.add(_lovedIds());
  userLikedSongsList.addListener(changed);
  events.add(_lovedIds());
  ref.onDispose(() {
    userLikedSongsList.removeListener(changed);
    unawaited(events.close());
  });
  return events.stream;
});

final libraryCollectionsProvider =
    NotifierProvider<LibraryCollectionsNotifier, LibraryCollectionsState>(
      LibraryCollectionsNotifier.new,
    );

class LibraryCollectionsNotifier extends Notifier<LibraryCollectionsState> {
  @override
  LibraryCollectionsState build() {
    final ids = ref.watch(_lovedSongIdsProvider).value ?? const <String>{};
    return LibraryCollectionsState(lovedIds: ids);
  }

  /// Adds the track to FluentMusic's liked songs, or removes it. Returns
  /// whether it is loved afterwards.
  Future<bool> toggleLoved(CollectionTrack track) async {
    final id = track.ytid;
    if (id == null || id.isEmpty) return false;
    final loved = state.isLoved(track);
    await updateSongLikeStatus(id, !loved, songData: track.songData);
    return !loved;
  }
}