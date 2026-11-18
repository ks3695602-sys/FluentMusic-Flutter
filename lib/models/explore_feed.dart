/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

/// Categories that seed the Explore Shorts carousel.
const exploreShortCategories = <String>['New', 'Trending', 'Evergreen'];

/// One loaded Explore page: Shorts, banners, picks and curated playlists.
class ExploreFeed {
  const ExploreFeed({
    required this.shorts,
    required this.featured,
    required this.curated,
    required this.songPicks,
    required this.fetchedAt,
  });

  final List<Map<String, dynamic>> shorts;
  final List<Map<String, dynamic>> featured;
  final List<Map<String, dynamic>> curated;
  final List<Map<String, dynamic>> songPicks;
  final DateTime fetchedAt;

  bool get isEmpty =>
      shorts.isEmpty &&
      featured.isEmpty &&
      curated.isEmpty &&
      songPicks.isEmpty;
}

/// Normalises a song returned by search/YTM into the shape the queue expects.
///
/// Returns null for entries without a playable video id or a title. The
/// [category] is stored as `exploreCategory` for the Shorts badge.
Map<String, dynamic>? normalizeExploreSong(dynamic raw, {String? category}) {
  if (raw is! Map) return null;
  final song = Map<String, dynamic>.from(raw);

  final ytid = song['ytid']?.toString().trim() ?? '';
  final title = song['title']?.toString().trim() ?? '';
  if (ytid.isEmpty || title.isEmpty) return null;

  final image = _firstNonEmpty([
    song['highResImage'],
    song['image'],
    song['lowResImage'],
    song['artworkPath'],
  ]);
  final lowRes = _firstNonEmpty([
    song['lowResImage'],
    song['image'],
    song['highResImage'],
  ]);
  final artist = song['artist']?.toString().trim() ?? '';

  song['ytid'] = ytid;
  song['title'] = title;
  song['artist'] = artist.isEmpty ? 'Unknown artist' : artist;
  song['highResImage'] = image;
  song['lowResImage'] = lowRes ?? image;
  song['image'] = song['image'] ?? image;
  if (category != null && category.isNotEmpty) {
    song['exploreCategory'] = category;
  }
  return song;
}

/// Normalises a playlist search result for banner and cube rendering.
Map<String, dynamic>? normalizeExplorePlaylist(dynamic raw) {
  if (raw is! Map) return null;
  final playlist = Map<String, dynamic>.from(raw);

  final id = playlist['ytid']?.toString().trim() ?? '';
  final title = playlist['title']?.toString().trim() ?? '';
  final image = _firstNonEmpty([
    playlist['image'],
    playlist['highResImage'],
    playlist['lowResImage'],
  ]);
  if (id.isEmpty || title.isEmpty || image == null) return null;

  playlist['ytid'] = id;
  playlist['title'] = title;
  playlist['image'] = image;
  playlist['lowResImage'] = playlist['lowResImage'] ?? image;
  playlist['highResImage'] = playlist['highResImage'] ?? image;
  return playlist;
}

/// Interleaves [groups] into one list, tagging each entry with its label.
///
/// Duplicate video ids are dropped, and the order rotates through the groups
/// so the Shorts carousel genuinely mixes New, Trending and Evergreen instead
/// of showing one category at a time.
List<Map<String, dynamic>> mixExploreSongs(
  List<List<Map<String, dynamic>>> groups,
  List<String> labels, {
  int limit = 12,
}) {
  final seen = <String>{};
  final mixed = <Map<String, dynamic>>[];
  if (groups.isEmpty || limit <= 0) return mixed;

  var offset = 0;
  var added = true;
  while (added && mixed.length < limit) {
    added = false;
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      if (offset >= group.length) continue;
      added = true;

      final song = group[offset];
      final id = song['ytid']?.toString() ?? '';
      if (id.isEmpty || !seen.add(id)) continue;

      final label = groupIndex < labels.length ? labels[groupIndex] : null;
      final tagged = label == null
          ? Map<String, dynamic>.from(song)
          : (Map<String, dynamic>.from(song)..['exploreCategory'] = label);
      mixed.add(tagged);
      if (mixed.length >= limit) break;
    }
    offset++;
  }

  return mixed;
}

String? _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}
