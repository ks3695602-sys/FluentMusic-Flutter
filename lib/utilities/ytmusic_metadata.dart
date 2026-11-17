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

/// Metadata helpers shared by the YouTube Music library parser and the lyrics
/// query builder.
///
/// YouTube Music puts the item type in the first subtitle run of account
/// library rows (`Song`, `Single`, `Album`, ...). Treating that run as the
/// artist made synced songs look like they were performed by "Song" and broke
/// lyrics lookups. These helpers skip those labels instead.
library;

/// Item types YouTube Music renders before the artist in library rows.
const Set<String> _typeLabels = {
  'song',
  'songs',
  'single',
  'singles',
  'album',
  'albums',
  'ep',
  'eps',
  'playlist',
  'playlists',
  'video',
  'videos',
  'music video',
  'podcast',
  'podcasts',
  'upload',
  'auto-generated',
  'auto generated',
  'youtube music',
  'various artists',
  'va',
};

final RegExp _durationToken = RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?$');
final RegExp _yearToken = RegExp(r'^(?:19|20)\d{2}$');
final RegExp _viewsToken = RegExp(
  r'^[\d.,]+\s*[kmb]?\s*(?:views?|plays?|listeners?|likes?)$',
  caseSensitive: false,
);
final RegExp _separatorToken = RegExp(r'^[\s•·・|\-–—]+$');
final RegExp _bulletSplit = RegExp(r'\s*[•·・|]\s*');

/// True when [value] is an item type, duration, year, view count or separator
/// rather than an artist name.
bool isJunkArtist(String value) {
  final text = value.trim();
  if (text.isEmpty) return true;
  if (_typeLabels.contains(text.toLowerCase())) return true;
  if (_durationToken.hasMatch(text) || _yearToken.hasMatch(text)) return true;
  if (_viewsToken.hasMatch(text)) return true;
  if (_separatorToken.hasMatch(text)) return true;
  return false;
}

/// Returns the first artist-looking token in [runs], preserving their order.
String? pickArtistFromRuns(Iterable<String> runs) {
  for (final run in runs) {
    for (final part in run.split(_bulletSplit)) {
      final candidate = part.trim();
      if (candidate.isEmpty || isJunkArtist(candidate)) continue;
      return candidate;
    }
  }
  return null;
}

/// Returns the first artist-looking run across the raw subtitle [nodes].
///
/// Runs linked to a `UC...` browse endpoint win, because YouTube Music uses
/// that endpoint for artist channels while albums use `MPRE...` and playlists
/// use `VL...`. Falls back to text heuristics when the renderer has no links.
String? pickArtistFromSubtitles(Iterable<dynamic> nodes) {
  final fallback = <String>[];

  for (final node in nodes) {
    if (node is String) {
      fallback.add(node);
      continue;
    }
    if (node is! Map) continue;

    final runs = node['runs'];
    if (runs is List) {
      for (final run in runs) {
        if (run is! Map) continue;
        final text = run['text']?.toString().trim() ?? '';
        if (text.isEmpty) continue;
        final browseId = _browseIdOf(run);
        if (browseId != null &&
            browseId.startsWith('UC') &&
            !isJunkArtist(text)) {
          return text;
        }
        fallback.add(text);
      }
    }

    final simple = node['simpleText']?.toString().trim();
    if (runs is! List && simple != null && simple.isNotEmpty) {
      // `simpleText` keeps the whole line; split it so "Song • Artist" still
      // yields the artist.
      fallback.addAll(simple.split(_bulletSplit));
    } else if (simple != null && simple.isNotEmpty) {
      fallback.add(simple);
    }
  }

  return pickArtistFromRuns(fallback);
}

String? _browseIdOf(Map run) {
  final endpoint = run['navigationEndpoint'];
  if (endpoint is! Map) return null;
  final browse = endpoint['browseEndpoint'];
  if (browse is! Map) return null;
  final id = browse['browseId']?.toString().trim();
  return id == null || id.isEmpty ? null : id;
}
