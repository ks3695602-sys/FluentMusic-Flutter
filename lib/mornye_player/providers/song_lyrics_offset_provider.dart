import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/mornye_player/providers/theme_provider.dart';

/// The key a song's own lyric timing offset is kept under: its title and
/// artist, trimmed and lowercased. Empty for a song without a title.
String songLyricsOffsetKey(String? title, String? artist) {
  final name = (title ?? '').trim().toLowerCase();
  if (name.isEmpty) return '';
  final by = (artist ?? '').trim().toLowerCase();
  return by.isEmpty ? name : '$name\u0000$by';
}

/// [songLyricsOffsetKey] of [item], or empty without one.
String songLyricsOffsetKeyOf(MediaItem? item) =>
    item == null ? '' : songLyricsOffsetKey(item.title, item.artist);

/// One song's own offset and when it was last set on this device.
@immutable
class SongLyricsOffset {
  const SongLyricsOffset(this.offsetMs, this.editedMs);

  final int offsetMs;
  final int editedMs;

  @override
  bool operator ==(Object other) =>
      other is SongLyricsOffset &&
      other.offsetMs == offsetMs &&
      other.editedMs == editedMs;

  @override
  int get hashCode => Object.hash(offsetMs, editedMs);
}

/// FluentMusic has no per-song lyric offset editor, so nothing is stored.
final songLyricsOffsetsProvider =
    Provider<Map<String, SongLyricsOffset>>((ref) => const {});

/// The song's own offset under [key], 0 for none.
final songLyricsOffsetMsProvider = Provider.autoDispose.family<int, String>(
  (ref, key) => ref.watch(
    songLyricsOffsetsProvider.select(
      (offsets) => offsets[key]?.offsetMs ?? 0,
    ),
  ),
);

/// The offset synced lyrics of the song under [key] are drawn with: the
/// app-wide offset plus the song's own.
final lyricsOffsetMsForSongProvider = Provider.autoDispose.family<int, String>(
  (ref, key) =>
      ref.watch(themeProvider.select((theme) => theme.lyricsOffsetMs)) +
      ref.watch(songLyricsOffsetMsProvider(key)),
);