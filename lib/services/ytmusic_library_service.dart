/*
 * FluentMusic — YouTube Music library reader
 *
 * Account-bound reads on top of [InnerTubeClient]:
 *   - library playlists       (browse FEmusic_liked_playlists)
 *   - liked songs             (browse VLLM, fallback FEmusic_liked_videos)
 *   - playlist / album tracks (browse VL<id> / MPRE<id>) with continuations
 *   - account home shelves    (browse FEmusic_home)
 *
 * Everything is parsed defensively: InnerTube shuffles renderer nesting
 * between builds, so the parser walks the tree for known renderer keys
 * instead of hard-coding a path and hoping Google keeps it.
 *
 * This file is network-only. Persistence and library merging live in
 * `ytmusic_library_store.dart`, so `playlists_manager.dart` can import the
 * fetcher without an import cycle.
 */

import 'dart:async';

import 'package:musify/services/innertube_client.dart';
import 'package:musify/services/ytmusic_auth_service.dart';
import 'package:musify/utilities/ytmusic_metadata.dart';

/// One account home shelf, e.g. "Listen again", "Speed dial" or
/// "Forgotten favourites".
class YtMusicShelf {
  const YtMusicShelf({required this.title, required this.items});

  final String title;

  /// Parsed items. Songs use the app's song layout; playlists use the app's
  /// playlist layout. Both carry `kind` (`song` / `playlist`) so callers can
  /// split a mixed shelf without re-inspecting fields.
  final List<Map<String, dynamic>> items;

  Map<String, dynamic> toJson() => {'title': title, 'items': items};

  static YtMusicShelf? fromJson(dynamic json) {
    if (json is! Map) return null;
    final title = json['title']?.toString().trim();
    final rawItems = json['items'];
    if (title == null || title.isEmpty || rawItems is! List) return null;
    final items = rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (items.isEmpty) return null;
    return YtMusicShelf(title: title, items: items);
  }
}

/// Everything one sync pass can produce.
class YtMusicLibrarySnapshot {
  const YtMusicLibrarySnapshot({
    required this.playlists,
    required this.likedSongs,
    required this.homeShelves,
  });

  final List<Map<String, dynamic>> playlists;
  final List<Map<String, dynamic>> likedSongs;
  final List<YtMusicShelf> homeShelves;

  int get songCount => likedSongs.length;
  int get playlistCount => playlists.length;
}

class YtMusicLibraryService {
  YtMusicLibraryService({
    InnerTubeClient? client,
    YtMusicAuthService? authService,
  })  : _client = client ?? InnerTubeClient(),
        _authService = authService ?? ytMusicAuthService;

  final InnerTubeClient _client;
  final YtMusicAuthService _authService;

  bool get canSync => _authService.isConnected;

  InnerTubeAuth _requireAuth() {
    if (!_authService.isConnected) {
      throw InnerTubeAuthException('Sign in to YouTube Music first.');
    }
    return _authService.auth;
  }

  /// One full library pass. Home is optional so a manual "sync library" press
  /// can skip the extra round trip.
  Future<YtMusicLibrarySnapshot> fetchLibrary({
    bool includeHome = true,
    int playlistLimit = 60,
    int songLimit = 300,
  }) async {
    final playlists = await fetchLibraryPlaylists(limit: playlistLimit);
    final songs = await fetchLikedSongs(limit: songLimit);

    // Home is a bonus rail set. Google has changed this endpoint's params more
    // than once, so never let it sink an otherwise good library sync.
    var shelves = const <YtMusicShelf>[];
    if (includeHome) {
      try {
        shelves = await fetchHomeShelves(limit: 8);
      } catch (_) {
        shelves = const <YtMusicShelf>[];
      }
    }

    return YtMusicLibrarySnapshot(
      playlists: playlists,
      likedSongs: songs,
      homeShelves: shelves,
    );
  }

  Future<List<Map<String, dynamic>>> fetchLibraryPlaylists({
    int limit = 60,
  }) async {
    final auth = _requireAuth();
    final response = await _browse(auth, browseId: 'FEmusic_liked_playlists');
    final items = <Map<String, dynamic>>[];
    _collectItems(response['contents'], items);
    await _paginate(
      auth,
      response,
      items,
      maxItems: limit,
      songsOnly: false,
    );
    return _dedupe(
      items
          .where((item) => item['kind'] == 'playlist')
          .where((item) => !item['ytid'].toString().startsWith('FEmusic'))
          .toList(),
    ).take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> fetchLikedSongs({
    int limit = 300,
  }) async {
    final auth = _requireAuth();
    final items = <Map<String, dynamic>>[];

    // "LM" is the auto-generated Liked Music playlist. If that ever comes
    // back empty (or 400s), the library landing page still exposes the same
    // songs.
    for (final browseId in const ['VLLM', 'FEmusic_liked_videos']) {
      try {
        final response = await _browse(auth, browseId: browseId);
        _collectItems(response['contents'], items);
        if (items.any((item) => item['kind'] == 'song')) {
          await _paginate(
            auth,
            response,
            items,
            maxItems: limit,
            songsOnly: true,
          );
          break;
        }
      } catch (_) {
        // Try the next endpoint.
      }
    }

    return _dedupe(
      items.where((item) => item['kind'] == 'song').toList(),
    ).take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> fetchPlaylistSongs(
    String playlistId, {
    int limit = 300,
  }) async {
    final id = normalizePlaylistId(playlistId);
    if (id.isEmpty) return const [];
    final auth = _requireAuth();
    final response = await _browse(
      auth,
      browseId: _browseIdForPlaylist(id),
    );
    final items = <Map<String, dynamic>>[];
    _collectItems(response['contents'], items);

    // Album/track pages sometimes wrap the rows in more than one section;
    // keep paginating while a continuation exists.
    await _paginate(
      auth,
      response,
      items,
      maxItems: limit,
      songsOnly: true,
    );

    final songs = items.where((item) => item['kind'] == 'song').toList();
    for (var i = 0; i < songs.length; i++) {
      songs[i]['id'] = i;
    }
    return _dedupe(songs).take(limit).toList();
  }

  Future<List<YtMusicShelf>> fetchHomeShelves({int limit = 8}) async {
    final auth = _requireAuth();
    final response = await _browse(auth, browseId: 'FEmusic_home');
    final rawShelves = <({String? title, dynamic contents})>[];
    _collectShelves(response['contents'], rawShelves);

    final shelves = <YtMusicShelf>[];
    for (final raw in rawShelves) {
      final title = raw.title?.trim();
      if (title == null || title.isEmpty) continue;
      final items = <Map<String, dynamic>>[];
      _collectItems(raw.contents, items);
      final usable = items
          .where(
            (item) =>
                item['kind'] == 'song' || item['kind'] == 'playlist',
          )
          .toList();
      if (usable.isEmpty) continue;
      shelves.add(YtMusicShelf(title: title, items: usable.take(12).toList()));
      if (shelves.length >= limit) break;
    }
    return shelves;
  }

  // ---------------------------------------------------------------------
  // Requests
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _browse(
    InnerTubeAuth auth, {
    String? browseId,
    String? continuation,
  }) {
    return _client.post(
      'browse',
      {
        'context': _client.buildContext(auth),
        if (browseId != null) 'browseId': browseId,
        if (continuation != null) 'continuation': continuation,
      },
      auth: auth,
      authenticated: true,
    );
  }

  Future<void> _paginate(
    InnerTubeAuth auth,
    Map<String, dynamic> response,
    List<Map<String, dynamic>> out, {
    required int maxItems,
    required bool songsOnly,
    int maxPages = 6,
  }) async {
    var token = _continuationToken(response);
    var pages = 0;
    while (token != null && pages < maxPages) {
      final current = songsOnly
          ? out.where((item) => item['kind'] == 'song').length
          : out.where((item) => item['kind'] == 'playlist').length;
      if (current >= maxItems) break;

      final continuation = await _browse(auth, continuation: token);
      _collectItems(continuation['continuationContents'], out);
      _collectItems(continuation['contents'], out);
      token = _continuationToken(continuation);
      pages++;
    }
  }

  // ---------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------

  void _collectItems(dynamic node, List<Map<String, dynamic>> out) {
    if (node is Map) {
      final twoRow = node['musicTwoRowItemRenderer'];
      if (twoRow is Map) {
        final item = _parseTwoRowItem(twoRow);
        if (item != null) out.add(item);
        return;
      }

      final songRow = node['musicResponsiveListItemRenderer'];
      if (songRow is Map) {
        final item = _parseSongRow(songRow);
        if (item != null) out.add(item);
        return;
      }

      // Playlist header rows in the library landing page.
      final responsiveHeader = node['musicResponsiveHeaderRenderer'];
      if (responsiveHeader is Map) {
        final item = _parseResponsiveHeader(responsiveHeader);
        if (item != null) out.add(item);
        return;
      }

      for (final value in node.values) {
        _collectItems(value, out);
      }
    } else if (node is List) {
      for (final value in node) {
        _collectItems(value, out);
      }
    }
  }

  void _collectShelves(
    dynamic node,
    List<({String? title, dynamic contents})> out,
  ) {
    if (node is Map) {
      final carousel = node['musicCarouselShelfRenderer'];
      if (carousel is Map) {
        final header = carousel['header'];
        final headerRenderer = header is Map
            ? header['musicCarouselShelfBasicHeaderRenderer']
            : null;
        final shelfTitle = headerRenderer is Map
            ? headerRenderer['title']
            : null;
        out.add((
          title: _textOf(shelfTitle),
          contents: carousel['contents'],
        ));
        return;
      }

      final shelf = node['musicShelfRenderer'];
      if (shelf is Map) {
        out.add((title: _textOf(shelf['title']), contents: shelf['contents']));
        return;
      }

      final grid = node['gridRenderer'];
      if (grid is Map) {
        out.add((title: _textOf(grid['header']), contents: grid['contents']));
        return;
      }

      for (final value in node.values) {
        _collectShelves(value, out);
      }
    } else if (node is List) {
      for (final value in node) {
        _collectShelves(value, out);
      }
    }
  }

  Map<String, dynamic>? _parseTwoRowItem(Map renderer) {
    final title = _textOf(renderer['title'])?.trim();
    if (title == null || title.isEmpty) return null;

    final navigation = renderer['navigationEndpoint'];
    final videoId = _nestedString(navigation, const [
      'watchEndpoint',
      'videoId',
    ]);
    final browseId = _nestedString(navigation, const [
      'browseEndpoint',
      'browseId',
    ]);
    final image = _thumbnailUrl(renderer);
    final subtitleRuns = _runsOf(renderer['subtitle']);
    final author = pickArtistFromSubtitles([renderer['subtitle']]);

    if (videoId != null && videoId.isNotEmpty) {
      return _songLayout(
        videoId: videoId,
        title: title,
        artist: author,
        image: image,
        duration: _durationFrom(subtitleRuns),
      );
    }

    final id = normalizePlaylistId(browseId ?? '');
    if (id.isEmpty || !_looksLikePlaylist(id)) return null;

    return {
      'id': 0,
      'ytid': id,
      'title': title,
      'author': author,
      'artist': author,
      'image': image,
      'lowResImage': image,
      'highResImage': image,
      'isAlbum': id.startsWith('MPRE'),
      'source': 'ytmusic',
      'kind': 'playlist',
      'list': <dynamic>[],
    };
  }

  Map<String, dynamic>? _parseResponsiveHeader(Map renderer) {
    final title = _textOf(renderer['title'])?.trim();
    final browseId = _nestedString(renderer['navigationEndpoint'], const [
      'browseEndpoint',
      'browseId',
    ]);
    final id = normalizePlaylistId(browseId ?? '');
    if (title == null || title.isEmpty || id.isEmpty) return null;
    if (!_looksLikePlaylist(id)) return null;

    final subtitleRuns = _runsOf(renderer['subtitle']);
    return {
      'id': 0,
      'ytid': id,
      'title': title,
      'author': pickArtistFromRuns(subtitleRuns),
      'image': _thumbnailUrl(renderer),
      'source': 'ytmusic',
      'kind': 'playlist',
      'list': <dynamic>[],
    };
  }

  Map<String, dynamic>? _parseSongRow(Map renderer) {
    var videoId = _nestedString(renderer['playlistItemData'], const [
      'videoId',
    ]);
    videoId ??= _nestedString(renderer['navigationEndpoint'], const [
      'watchEndpoint',
      'videoId',
    ]);

    final columns = renderer['flexColumns'];
    String? title;
    final secondaryRuns = <String>[];
    final secondaryNodes = <dynamic>[];

    if (columns is List) {
      for (var i = 0; i < columns.length; i++) {
        final column = columns[i];
        final columnRenderer = column is Map
            ? column['musicResponsiveListItemFlexColumnRenderer']
            : null;
        final text = columnRenderer is Map ? columnRenderer['text'] : null;
        if (i == 0) {
          title = _textOf(text);
        } else {
          secondaryNodes.add(text);
          secondaryRuns.addAll(_runsOf(text));
        }
      }
    }

    // Some renderers keep the subtitle outside `flexColumns`.
    final rendererSubtitle = renderer['subtitle'];
    if (rendererSubtitle != null) {
      secondaryNodes.add(rendererSubtitle);
      secondaryRuns.addAll(_runsOf(rendererSubtitle));
    }

    title ??= _textOf(renderer['title']);
    if (title == null || title.trim().isEmpty) return null;

    // Some rows (private uploads, unavailable tracks) have no video id.
    if (videoId == null || videoId.isEmpty) return null;

    // Account library rows lead with the item type ("Song", "Single", ...),
    // followed by the real artist. Pick the artist run instead of blindly
    // taking the first subtitle token.
    final artist = pickArtistFromSubtitles(secondaryNodes);

    return _songLayout(
      videoId: videoId,
      title: title.trim(),
      artist: artist,
      image: _thumbnailUrl(renderer),
      duration: _durationFrom(secondaryRuns),
    );
  }

  Map<String, dynamic> _songLayout({
    required String videoId,
    required String title,
    required String? artist,
    required String? image,
    required int? duration,
  }) {
    return {
      'id': 0,
      'ytid': videoId,
      'title': title,
      'artist': artist ?? '',
      'artistId': '',
      'videoAuthor': artist ?? '',
      'image': image,
      'lowResImage': image,
      'highResImage': image,
      'duration': duration,
      'isLive': false,
      'source': 'ytmusic',
      'kind': 'song',
    };
  }

  /// Splits `Artist • Album • 3:42` runs into plain strings.
  static List<String> _runsOf(dynamic node) {
    final out = <String>[];
    if (node is Map) {
      final runs = node['runs'];
      if (runs is List) {
        for (final run in runs) {
          if (run is Map) {
            final text = run['text']?.toString().trim();
            if (text != null && text.isNotEmpty) out.add(text);
          }
        }
      }
      final simple = node['simpleText']?.toString().trim();
      if (out.isEmpty && simple != null && simple.isNotEmpty) {
        for (final part in simple.split('•')) {
          final text = part.trim();
          if (text.isNotEmpty) out.add(text);
        }
      }
    } else if (node is String && node.trim().isNotEmpty) {
      out.add(node.trim());
    }
    return out;
  }

  static String? _textOf(dynamic node) {
    if (node == null) return null;
    if (node is String) return node;
    if (node is Map) {
      final simple = node['simpleText']?.toString();
      if (simple != null && simple.trim().isNotEmpty) return simple.trim();
      final runs = node['runs'];
      if (runs is List) {
        final buffer = StringBuffer();
        for (final run in runs) {
          if (run is Map) {
            final text = run['text']?.toString();
            if (text != null) buffer.write(text);
          }
        }
        final text = buffer.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  static String? _nestedString(dynamic node, List<String> path) {
    var current = node;
    for (final key in path) {
      if (current is! Map) return null;
      current = current[key];
    }
    final value = current?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Finds the first `thumbnails` list under [node] and returns its largest
  /// entry. Renderer nesting differs between shelves, so this walks the tree.
  static String? _thumbnailUrl(dynamic node) {
    final thumbnails = _findThumbnails(node);
    if (thumbnails.isEmpty) return null;
    for (final entry in thumbnails.reversed) {
      if (entry is Map) {
        final url = entry['url']?.toString();
        if (url != null && url.isNotEmpty) return url;
      }
    }
    return null;
  }

  static List<dynamic> _findThumbnails(dynamic node, [int depth = 0]) {
    if (depth > 6) return const [];
    if (node is Map) {
      final direct = node['thumbnails'];
      if (direct is List && direct.isNotEmpty) return direct;
      for (final value in node.values) {
        final found = _findThumbnails(value, depth + 1);
        if (found.isNotEmpty) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findThumbnails(value, depth + 1);
        if (found.isNotEmpty) return found;
      }
    }
    return const [];
  }

  static int? _durationFrom(List<String> runs) {
    for (final run in runs.reversed) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(
        run.trim(),
      );
      if (match == null) continue;
      final first = int.tryParse(match.group(1) ?? '');
      final second = int.tryParse(match.group(2) ?? '');
      final third = match.group(3) == null
          ? null
          : int.tryParse(match.group(3)!);
      if (first == null || second == null) continue;
      if (third != null) return first * 3600 + second * 60 + third;
      return first * 60 + second;
    }
    return null;
  }

  static String? _continuationToken(dynamic node, [int depth = 0]) {
    if (node == null || depth > 8) return null;
    if (node is Map) {
      final renderer = node['continuationItemRenderer'];
      if (renderer is Map) {
        final command = renderer['continuationEndpoint'];
        final token = command is Map
            ? _nestedString(command, const ['continuationCommand', 'token'])
            : null;
        if (token != null) return token;
        final next = renderer['nextContinuationData'];
        final legacy = next is Map ? next['continuation']?.toString() : null;
        if (legacy != null && legacy.isNotEmpty) return legacy;
      }
      for (final value in node.values) {
        final token = _continuationToken(value, depth + 1);
        if (token != null) return token;
      }
    } else if (node is List) {
      for (final value in node) {
        final token = _continuationToken(value, depth + 1);
        if (token != null) return token;
      }
    }
    return null;
  }

  static bool _looksLikePlaylist(String id) {
    if (id.isEmpty) return false;
    return id.startsWith('PL') ||
        id.startsWith('OLAK') ||
        id.startsWith('RD') ||
        id.startsWith('MPRE') ||
        id == 'LM' ||
        id.startsWith('VL');
  }

  static String normalizePlaylistId(String raw) {
    var id = raw.trim();
    while (id.startsWith('VL') && id.length > 2) {
      id = id.substring(2);
    }
    return id;
  }

  static String _browseIdForPlaylist(String id) {
    if (id.startsWith('MPRE') || id.startsWith('FEmusic')) return id;
    return 'VL$id';
  }

  static List<Map<String, dynamic>> _dedupe(
    List<Map<String, dynamic>> items,
  ) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final item in items) {
      final id = item['ytid']?.toString();
      if (id == null || id.isEmpty || !seen.add(id)) continue;
      out.add(item);
    }
    return out;
  }
}

final ytMusicLibraryService = YtMusicLibraryService();
