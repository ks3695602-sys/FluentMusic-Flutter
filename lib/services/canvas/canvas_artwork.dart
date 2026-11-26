/*
 * Portions derived from BitChord (kushagrasinghx/BitChord), GPL-3.0.
 * https://github.com/kushagrasinghx/BitChord
 *
 * FluentMusic is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 */

/// Which catalogue answered a canvas lookup.
///
/// Spotify is deliberately absent: its Canvas endpoint needs the listener's
/// own session cookie, and FluentMusic's canvas chain is tokenless.
enum CanvasSource { apple, tidal, community }

/// A looping clip that can stand in for a track's still cover art.
///
/// [url] is what the player mounts. [fallbackUrl] is tried once if the first
/// rendition fails to decode, which is how Apple hands over its alternate
/// motion asset. The metadata fields are not decoration: every provider
/// searches by free text and will happily return the wrong release, so
/// [matches] re-checks the answer against the track that is playing.
class CanvasArtwork {
  const CanvasArtwork({
    required this.url,
    this.fallbackUrl,
    this.title,
    this.artist,
    this.album,
    this.source = CanvasSource.community,
  });

  final String url;
  final String? fallbackUrl;
  final String? title;
  final String? artist;
  final String? album;
  final CanvasSource source;

  /// Whether this clip belongs to the track we asked about.
  ///
  /// Title and credited artists must line up once case, accents and
  /// punctuation are folded away. The album is only held to that standard
  /// when both sides know it: a track queued from search often has no album,
  /// and requiring one would mean no canvas for most of a session.
  bool matches(String wantTitle, String wantArtist, String? wantAlbum) {
    final titleOk =
        title == null ||
        wantTitle.trim().isEmpty ||
        title!.normalizeForMatch() == wantTitle.normalizeForMatch();

    final wantedArtists = splitArtists(wantArtist);
    final ourArtists = splitArtists(artist ?? '');
    final artistOk =
        artist == null ||
        wantArtist.trim().isEmpty ||
        (wantedArtists.isNotEmpty &&
            ourArtists.isNotEmpty &&
            wantedArtists.every(
              (want) => ourArtists.any((credit) => credit == want),
            ));

    final albumOk =
        album == null ||
        album!.trim().isEmpty ||
        wantAlbum == null ||
        wantAlbum.trim().isEmpty ||
        album!.normalizeForMatch() == wantAlbum.normalizeForMatch();

    return titleOk && artistOk && albumOk;
  }
}

/// Case, accents and punctuation all differ between YouTube Music, Apple and
/// Tidal for the same release — "Beyoncé - CRAZY IN LOVE (feat. JAY-Z)" against
/// "Beyonce Crazy in Love feat Jay Z". Fold all three away before comparing.
String normalizeCanvasMatch(String raw) {
  final folded = StringBuffer();
  for (final rune in raw.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    folded.write(_diacritics[char] ?? char);
  }
  return folded
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

extension CanvasMatchString on String {
  String normalizeForMatch() => normalizeCanvasMatch(this);
}

/// One credit string into its individual artists. Every service picks its own
/// separator — commas, ampersands, "feat.", a bare "x" between collaborators —
/// so comparing the joined strings would fail on formatting alone.
List<String> splitArtists(String raw) {
  return raw
      .split(_artistSeparators)
      .map((part) => part.normalizeForMatch())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

final RegExp _artistSeparators = RegExp(
  r'(?:\s*,\s*|\s*&\s*|\s+×\s+|\s+x\s+|\bfeat\.?\b|\bft\.?\b|\bfeaturing\b|\bwith\b)',
  caseSensitive: false,
);

const Map<String, String> _diacritics = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'ď': 'd',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'į': 'i',
  'ı': 'i',
  'ñ': 'n',
  'ń': 'n',
  'ň': 'n',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ø': 'o',
  'ō': 'o',
  'ő': 'o',
  'ř': 'r',
  'ś': 's',
  'š': 's',
  'ş': 's',
  'ť': 't',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ů': 'u',
  'ű': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
  'ß': 'ss',
  'æ': 'ae',
  'œ': 'oe',
};
