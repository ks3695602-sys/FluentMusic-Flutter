/*
 * Portions derived from BitChord (kushagrasinghx/BitChord), GPL-3.0.
 * https://github.com/kushagrasinghx/BitChord
 *
 * Apple Music's motion artwork — the animated sleeves the web player shows on
 * an album page, exposed on the catalog API as `editorialVideo`.
 */

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:musify/services/canvas/canvas_artwork.dart';
import 'package:musify/services/canvas/canvas_http.dart';

class AppleMusicCanvas {
  AppleMusicCanvas._();

  static final AppleMusicCanvas instance = AppleMusicCanvas._();

  static const String _webPlayer = 'https://music.apple.com/us/browse';
  static const int _minScore = 12;
  static const int _tokenRetryMs = 30 * 60 * 1000;

  String? _cachedToken;
  int _tokenExpiresAtMs = 0;
  int _retryTokenAfterMs = 0;
  final Set<String> _rejectedTokens = <String>{};

  String get _storefront {
    final locale = Platform.localeName.replaceAll('-', '_');
    final parts = locale.split('_');
    final country = parts.length > 1 ? parts.last : '';
    return country.length == 2 ? country.toLowerCase() : 'us';
  }

  /// Searches the catalogue for the release a track belongs to.
  ///
  /// Albums carry `editorialVideo` inline, so asking for the release directly
  /// is both fewer requests and a better match than picking the first song
  /// that happens to sit on the right record.
  Future<CanvasArtwork?> search({
    required String title,
    required String artist,
    String? album,
  }) async {
    final bearer = await _token();
    if (bearer == null) return null;

    final term = StringBuffer();
    if (!title.toLowerCase().contains(artist.toLowerCase())) {
      term
        ..write(artist)
        ..write(' ');
    }
    term.write(title);
    if (album != null &&
        album.isNotEmpty &&
        !title.toLowerCase().contains(album.toLowerCase())) {
      term
        ..write(' ')
        ..write(album);
    }

    final songs = await _searchSongs(term.toString(), bearer);
    for (final hit in songs) {
      final score = _scoreSong(hit, title, artist, album);
      if (score == null || score < _minScore) continue;

      final attributes = _map(hit['attributes']);
      final video = _map(attributes?['editorialVideo']);
      final inline = _motionUrls(video);
      if (inline != null) {
        return CanvasArtwork(
          url: inline.$1,
          fallbackUrl: inline.$2,
          title: _string(attributes?['name']) ?? title,
          artist: _string(attributes?['artistName']) ?? artist,
          album: _string(attributes?['albumName']) ?? album,
          source: CanvasSource.apple,
        );
      }

      final albumId = _albumId(hit);
      if (albumId != null) {
        final release = await _album(albumId, bearer);
        if (release != null) return release;
      }
    }

    // A song search may miss an album whose title differs from the track.
    // The release search is the cheaper second chance, not the first move.
    if (album != null && album.isNotEmpty) {
      return _searchAlbum(album, artist, bearer);
    }
    return null;
  }

  Future<CanvasArtwork?> _searchAlbum(
    String album,
    String artist,
    String bearer,
  ) async {
    final uri = Uri.https(
      'amp-api.music.apple.com',
      '/v1/catalog/$_storefront/search',
      {
        'term': album.toLowerCase().contains(artist.toLowerCase())
            ? album
            : '$artist $album',
        'types': 'albums',
        'limit': '10',
        'extend': 'editorialVideo',
      },
    );
    final body = await _getJson(uri, bearer);
    final hits = _list(_map(_map(body?['results'])?['albums'])?['data']);
    for (final hit in hits) {
      final record = _map(hit);
      if (record == null) continue;
      final attributes = _map(record['attributes']);
      final name = _string(attributes?['name']);
      final credit = _string(attributes?['artistName']);
      if (name == null || credit == null) continue;
      if (_scoreRelease(name, credit, album, artist) < _minScore) continue;
      final video = _map(attributes?['editorialVideo']);
      final urls = _motionUrls(video);
      if (urls == null) continue;
      return CanvasArtwork(
        url: urls.$1,
        fallbackUrl: urls.$2,
        title: name,
        artist: credit,
        album: name,
        source: CanvasSource.apple,
      );
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _searchSongs(
    String term,
    String bearer,
  ) async {
    final uri = Uri.https(
      'amp-api.music.apple.com',
      '/v1/catalog/$_storefront/search',
      {
        'term': term,
        'types': 'songs',
        'limit': '10',
        'extend': 'editorialVideo',
        'include': 'albums',
      },
    );
    final body = await _getJson(uri, bearer);
    return _list(_map(_map(body?['results'])?['songs'])?['data'])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  Future<CanvasArtwork?> _album(String id, String bearer) async {
    final uri = Uri.https(
      'amp-api.music.apple.com',
      '/v1/catalog/$_storefront/albums/$id',
      {'extend': 'editorialVideo'},
    );
    final body = await _getJson(uri, bearer);
    final record = _map(_list(body?['data']).firstOrNull);
    if (record == null) return null;
    final attributes = _map(record['attributes']);
    final video = _map(attributes?['editorialVideo']);
    final urls = _motionUrls(video);
    if (urls == null) return null;
    return CanvasArtwork(
      url: urls.$1,
      fallbackUrl: urls.$2,
      title: _string(attributes?['name']),
      artist: _string(attributes?['artistName']),
      album: _string(attributes?['name']),
      source: CanvasSource.apple,
    );
  }

  int? _scoreSong(
    Map<String, dynamic> hit,
    String title,
    String artist,
    String? album,
  ) {
    final attributes = _map(hit['attributes']);
    if (attributes == null) return null;
    final name = _string(attributes['name']);
    final credit = _string(attributes['artistName']);
    final release = _string(attributes['albumName']);
    if (name == null || credit == null) return null;

    final wantedArtist = artist.normalizeForMatch();
    final gotArtist = credit.normalizeForMatch();
    if (wantedArtist.isEmpty || gotArtist.isEmpty) return null;
    if (!gotArtist.contains(wantedArtist) &&
        !wantedArtist.contains(gotArtist)) {
      return null;
    }

    var score = gotArtist == wantedArtist ? 10 : 6;
    final wantedTitle = title.normalizeForMatch();
    final gotTitle = name.normalizeForMatch();
    if (gotTitle == wantedTitle) {
      score += 14;
    } else if (gotTitle.contains(wantedTitle) ||
        wantedTitle.contains(gotTitle)) {
      score += 7;
    }
    if (album != null && album.trim().isNotEmpty) {
      final wantedAlbum = album.normalizeForMatch();
      final gotAlbum = (release ?? '').normalizeForMatch();
      if (gotAlbum == wantedAlbum) score += 5;
    }
    return score;
  }

  int _scoreRelease(
    String name,
    String credit,
    String wantName,
    String wantArtist,
  ) {
    var score = 0;
    final wantedArtist = wantArtist.normalizeForMatch();
    final gotArtist = credit.normalizeForMatch();
    if (wantedArtist.isNotEmpty && gotArtist.contains(wantedArtist))
      score += 10;
    final wantedName = wantName.normalizeForMatch();
    final gotName = name.normalizeForMatch();
    if (gotName == wantedName) {
      score += 14;
    } else if (gotName.contains(wantedName) || wantedName.contains(gotName)) {
      score += 7;
    }
    if (name.toLowerCase().contains('deluxe') ||
        name.toLowerCase().contains('compilation')) {
      score -= 3;
    }
    return score;
  }

  String? _albumId(Map<String, dynamic> song) {
    final relationships = _map(song['relationships']);
    final albums = _list(_map(relationships?['albums'])?['data']);
    for (final album in albums) {
      final id = _string(_map(album)?['id']);
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  /// The square rendition first — it fills a square sleeve without cropping.
  /// The tall rendition is the same clip framed for a phone-shaped surface and
  /// is the retry when the square will not play.
  (String, String?)? _motionUrls(Map<String, dynamic>? video) {
    if (video == null) return null;
    final square =
        _link(video, 'motionDetailSquare') ??
        _link(video, 'motionSquareVideo1x1');
    final raw = _link(video, 'motionDetailRaw');
    final tall =
        _link(video, 'motionDetailTall') ?? _link(video, 'motionTallVideo3x4');
    final primary = square ?? raw ?? tall;
    if (primary == null) return null;
    final alternate = [
      square,
      raw,
      tall,
    ].whereType<String>().firstWhere((url) => url != primary, orElse: () => '');
    return (primary, alternate.isEmpty ? null : alternate);
  }

  String? _link(Map<String, dynamic> video, String key) {
    final asset = _map(video[key]);
    if (asset == null) return null;
    for (final field in ['video', 'videoUrl', 'hlsUrl', 'url']) {
      final value = _string(asset[field]);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getJson(Uri uri, String bearer) async {
    final body = await CanvasHttp.getText(
      uri,
      headers: {
        'Authorization': 'Bearer $bearer',
        'Origin': 'https://music.apple.com',
        'Referer': 'https://music.apple.com/',
      },
    );
    if (body == null || body.isEmpty) {
      _rejectedTokens.add(bearer);
      if (_cachedToken == bearer) {
        _cachedToken = null;
        _tokenExpiresAtMs = 0;
      }
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _token() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _cachedToken;
    if (cached != null && now < _tokenExpiresAtMs - 60_000) return cached;
    if (now < _retryTokenAfterMs) return null;

    final html = await CanvasHttp.getText(Uri.parse(_webPlayer));
    if (html == null) {
      _retryTokenAfterMs = now + _tokenRetryMs;
      return null;
    }
    final scripts = RegExp(r'/assets/index(?:-legacy)?[~-][A-Za-z0-9_-]+\.js')
        .allMatches(html)
        .map((match) => match.group(0)!)
        .toSet();

    for (final path in scripts.take(8)) {
      final script = await CanvasHttp.getText(
        Uri.parse('https://music.apple.com$path'),
      );
      if (script == null) continue;
      final candidates =
          RegExp(r'ey[A-Za-z0-9_-]+\.ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+')
              .allMatches(script)
              .map((match) => match.group(0)!)
              .where((jwt) => !_rejectedTokens.contains(jwt))
              .toSet();
      for (final jwt in candidates) {
        final expiry = _expiry(jwt);
        if (expiry == null || expiry <= now) continue;
        if (_isWebPlayerToken(jwt) || candidates.length == 1) {
          _cachedToken = jwt;
          _tokenExpiresAtMs = expiry;
          return jwt;
        }
      }
    }

    _retryTokenAfterMs = now + _tokenRetryMs;
    return null;
  }

  bool _isWebPlayerToken(String jwt) {
    try {
      final parts = jwt.split('.');
      final header = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[0])),
      );
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return header.contains('WebPlayKid') || payload.contains('AMPWebPlay');
    } catch (_) {
      return false;
    }
  }

  int? _expiry(String jwt) {
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(jwt.split('.')[1])),
      );
      final match = RegExp(r'"exp"\s*:\s*(\d+)').firstMatch(payload);
      final seconds = int.tryParse(match?.group(1) ?? '');
      return seconds == null ? null : seconds * 1000;
    } catch (_) {
      return null;
    }
  }
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<dynamic> _list(dynamic value) => value is List ? value : const [];

String? _string(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
