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

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/database/radio_stations.db.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/models/radio_model.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/search_bridge.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/artist_bar.dart';
import 'package:musify/widgets/explore/explore_feed_view.dart';
import 'package:musify/widgets/glass/glass_sheet_style.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_bar.dart';
import 'package:musify/widgets/radio_station_card.dart';
import 'package:musify/widgets/section_title.dart';
import 'package:musify/widgets/song_bar.dart';

/// Explore owns the search branch. With no query it shows the discovery feed;
/// a query from the dock's inline search replaces it with results.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

// Global ValueNotifier for search history to make it reactive
final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>(
  Hive.box('user').get('searchHistory', defaultValue: []),
);

void reloadSearchHistoryFromStorage() {
  searchHistoryNotifier.value = Hive.box('user')
      .get('searchHistory', defaultValue: []);
}

class _SearchPageState extends State<SearchPage> {
  final ValueNotifier<bool> _fetchingSongs = ValueNotifier(false);
  int maxSongsInList = 15;
  String _query = '';
  List<dynamic> _songsSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _albumsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<RadioStation> _radioStationsSearchResult = [];
  int _latestSearchRequest = 0;

  bool get _isExploring => _query.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    InlineSearchBridge.request.addListener(_handleInlineSearch);
    InlineSearchBridge.clearRequest.addListener(_handleInlineClear);
    // Consume a query that was typed in the bar while this branch was cold.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = InlineSearchBridge.takePending();
      if (pending != null) {
        unawaited(_submitSearch(pending));
        return;
      }
      if (InlineSearchBridge.takeClearRequest()) _resetToExplore();
    });
  }

  void _handleInlineSearch() {
    final pending = InlineSearchBridge.takePending();
    if (pending == null || !mounted) return;
    unawaited(_submitSearch(pending));
  }

  void _handleInlineClear() {
    if (!InlineSearchBridge.takeClearRequest() || !mounted) return;
    if (_isExploring) return;
    _resetToExplore();
  }

  Future<void> _submitSearch([String? query]) async {
    final nextQuery = (query ?? _query).trim();
    if (!mounted) return;

    if (nextQuery.isEmpty) {
      _resetToExplore();
      return;
    }

    setState(() => _query = nextQuery);
    await search();
  }

  void _resetToExplore() {
    _latestSearchRequest++;
    _query = '';
    _songsSearchResult = [];
    _artistsSearchResult = [];
    _albumsSearchResult = [];
    _playlistsSearchResult = [];
    _radioStationsSearchResult = [];
    _fetchingSongs.value = false;
    FocusManager.instance.primaryFocus?.unfocus();
    // The dock owns its own field; ask it to collapse back to the pill.
    InlineSearchBridge.requestCollapse();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    InlineSearchBridge.request.removeListener(_handleInlineSearch);
    InlineSearchBridge.clearRequest.removeListener(_handleInlineClear);
    _fetchingSongs.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final query = _query.trim();
    final requestId = ++_latestSearchRequest;

    if (query.isEmpty) {
      _songsSearchResult = [];
      _artistsSearchResult = [];
      _albumsSearchResult = [];
      _playlistsSearchResult = [];
      _radioStationsSearchResult = [];
      _fetchingSongs.value = false;
      if (mounted) setState(() {});
      return;
    }
    _fetchingSongs.value = true;

    _songsSearchResult = [];
    _artistsSearchResult = [];
    _albumsSearchResult = [];
    _playlistsSearchResult = [];
    _radioStationsSearchResult = radioStationsDB
        .where(
          (station) =>
              station.name.toLowerCase().contains(query.toLowerCase()) ||
              (station.genre?.toLowerCase().contains(query.toLowerCase()) ??
                  false),
        )
        .toList();
    if (mounted) setState(() {});

    if (!searchHistoryNotifier.value.contains(query)) {
      final updatedHistory = List.from(searchHistoryNotifier.value)
        ..insert(0, query);
      searchHistoryNotifier.value = updatedHistory;
      unawaited(addOrUpdateData<List>('user', 'searchHistory', updatedHistory));
    }

    try {
      final artistsFuture = searchArtists(query);

      Future<void> publishSongs() async {
        try {
          var songs = await fetchSongsList(query);
          if (!mounted || requestId != _latestSearchRequest) return;

          if (songs.isEmpty) {
            final artists = await artistsFuture;
            if (!mounted || requestId != _latestSearchRequest) return;
            if (_artistsSearchResult.isEmpty) {
              _artistsSearchResult = artists
                  .whereType<Map>()
                  .map(Map<String, dynamic>.from)
                  .toList();
            }
            if (_artistsSearchResult.isNotEmpty) {
              songs = await _fetchSongsForResolvedArtist(query);
            }
          }

          if (!mounted || requestId != _latestSearchRequest) return;
          final prioritized = _prioritizeStudioTracks(songs, query);
          setState(() => _songsSearchResult = prioritized);
        } catch (e, stackTrace) {
          logger.log(
            'Error while searching online songs',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      Future<void> publishArtists() async {
        try {
          final artists = await artistsFuture;
          if (!mounted || requestId != _latestSearchRequest) return;
          setState(() {
            _artistsSearchResult = artists
                .whereType<Map>()
                .map(Map<String, dynamic>.from)
                .toList();
          });
        } catch (e, stackTrace) {
          logger.log(
            'Error while searching online artists',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      Future<void> publishAlbums() async {
        try {
          final albums = await getPlaylists(query: query, type: 'album');
          if (!mounted || requestId != _latestSearchRequest) return;
          setState(() => _albumsSearchResult = albums);
        } catch (e, stackTrace) {
          logger.log(
            'Error while searching online albums',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      Future<void> publishPlaylists() async {
        try {
          final playlists = await getPlaylists(query: query, type: 'playlist');
          if (!mounted || requestId != _latestSearchRequest) return;
          setState(() => _playlistsSearchResult = playlists);
        } catch (e, stackTrace) {
          logger.log(
            'Error while searching online playlists',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      await Future.wait([
        publishSongs(),
        publishArtists(),
        publishAlbums(),
        publishPlaylists(),
      ]);
    } catch (e, stackTrace) {
      logger.log(
        'Error while searching online songs',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (requestId == _latestSearchRequest) {
        _fetchingSongs.value = false;
        if (mounted) setState(() {});
      }
    }
  }

  Future<List<dynamic>> _fetchSongsForResolvedArtist(String query) async {
    final artistName = _artistsSearchResult.first['title']?.toString().trim();
    if (artistName == null || artistName.isEmpty) return [];

    final fallbackQueries = <String>{
      if (artistName.toLowerCase() != query.trim().toLowerCase()) artistName,
      '$artistName songs',
      '$artistName music',
    };

    for (final fallbackQuery in fallbackQueries) {
      final songs = await fetchSongsList(fallbackQuery);
      if (songs.isNotEmpty) return songs;
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_isExploring) {
      return ValueListenableBuilder<List>(
        valueListenable: searchHistoryNotifier,
        builder: (context, history, _) {
          final recent = history
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .take(8)
              .toList(growable: false);
          return ExploreFeedView(
            recentSearches: recent,
            onSearch: (query) => unawaited(_submitSearch(query)),
          );
        },
      );
    }

    return _buildResultsPage(context);
  }

  Widget _buildResultsPage(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return GlassScaffold(
      contentAwareBrightness: true,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchResultsHeader(
              query: _query,
              fetching: _fetchingSongs,
              onBack: _resetToExplore,
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _hasResults
                  ? _buildSearchResults(
                      context,
                      Theme.of(context).colorScheme.primary,
                    )
                  : _SearchResultsEmpty(
                      query: _query,
                      fetching: _fetchingSongs,
                    ),
            ),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  bool get _hasResults =>
      _songsSearchResult.isNotEmpty ||
      _artistsSearchResult.isNotEmpty ||
      _albumsSearchResult.isNotEmpty ||
      _playlistsSearchResult.isNotEmpty ||
      _radioStationsSearchResult.isNotEmpty;

  Widget _buildSearchResults(BuildContext context, Color primaryColor) {
    final widgets = <Widget>[];

    // Artists section
    if (_artistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.artists,
          primaryColor,
          icon: FluentIcons.person_24_filled,
        ),
      );

      final artists = _artistsSearchResult.take(3).toList();
      for (var index = 0; index < artists.length; index++) {
        final artist = Map<String, dynamic>.from(artists[index]);
        final artistId =
            artist['ytid']?.toString() ?? artist['title']?.toString() ?? '';
        if (artistId.isEmpty) continue;

        final borderRadius = getItemBorderRadius(index, artists.length);
        widgets.add(
          ArtistBar(
            key: listItemKey('search_artist', index, artist),
            artist: artist,
            borderRadius: borderRadius,
            onTap: () {
              context.push(
                '${NavigationManager.searchPath}/artist/${Uri.encodeComponent(artistId)}',
                extra: artist,
              );
            },
          ),
        );
      }
    }

    // Songs section
    if (_songsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.songs,
          primaryColor,
          icon: FluentIcons.music_note_1_24_filled,
        ),
      );

      final songsCount = _songsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _songsSearchResult.length;

      for (var index = 0; index < songsCount; index++) {
        final song = _songsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, songsCount);
        widgets.add(
          SongBar(
            song,
            false,
            key: listItemKey('search_song', index, song),
            showMusicDuration: true,
            borderRadius: borderRadius,
            onPlay: () => _handleSearchSongPlay(song, index),
          ),
        );
      }
    }

    // Albums section
    if (_albumsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.albums,
          primaryColor,
          icon: FluentIcons.album_24_filled,
        ),
      );

      final albumsCount = _albumsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _albumsSearchResult.length;

      for (var index = 0; index < albumsCount; index++) {
        final playlist = _albumsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, albumsCount);

        widgets.add(
          PlaylistBar(
            key: listItemKey('search_album', index, playlist),
            playlist['title'],
            playlistId: playlist['ytid'],
            playlistArtwork: playlist['image'],
            cubeIcon: FluentIcons.cd_16_filled,
            isAlbum: true,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Playlists section
    if (_playlistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.playlists,
          primaryColor,
          icon: FluentIcons.text_bullet_list_24_filled,
        ),
      );

      final playlistsCount = _playlistsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _playlistsSearchResult.length;

      for (var index = 0; index < playlistsCount; index++) {
        final playlist = _playlistsSearchResult[index];
        final isLast = index == playlistsCount - 1;
        final borderRadius = getItemBorderRadius(index, playlistsCount);

        widgets.add(
          Padding(
            padding: isLast ? commonListViewBottomPadding : EdgeInsets.zero,
            child: PlaylistBar(
              key: listItemKey('search_playlist', index, playlist),
              playlist['title'],
              playlistId: playlist['ytid'],
              playlistArtwork: playlist['image'],
              cubeIcon: FluentIcons.apps_list_24_filled,
              borderRadius: borderRadius,
            ),
          ),
        );
      }
    }

    // Radio Stations section
    if (_radioStationsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.radioStations,
          primaryColor,
          icon: FluentIcons.speaker_2_24_filled,
        ),
      );

      final stationsCount = _radioStationsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _radioStationsSearchResult.length;

      for (var index = 0; index < stationsCount; index++) {
        final station = _radioStationsSearchResult[index];
        final isLast = index == stationsCount - 1;

        widgets.add(
          Padding(
            padding: isLast ? commonListViewBottomPadding : EdgeInsets.zero,
            child: RadioStationCard(
              key: listItemKey('search_radio_station', index, station),
              station: station,
              onPressed: () async {
                final success = await audioHandler.playRadioStream(
                  id: station.id,
                  name: station.name,
                  streamUrl: station.streamUrl,
                  image: station.image,
                  genre: station.genre,
                );
                if (!success && context.mounted) {
                  showToast(context, context.l10n!.failedPlayingRadio);
                }
              },
            ),
          ),
        );
      }
    }

    return Column(
      key: ValueKey(
        'results-${_songsSearchResult.length}-${_artistsSearchResult.length}-${_albumsSearchResult.length}-${_playlistsSearchResult.length}',
      ),
      children: widgets,
    );
  }

  List<dynamic> _prioritizeStudioTracks(List<dynamic> songs, String query) {
    final lowerQuery = query.toLowerCase();
    final isSearchingForLive = lowerQuery.contains('live') || lowerQuery.contains('concert');
    if (isSearchingForLive) return songs;

    final studioList = <dynamic>[];
    final liveList = <dynamic>[];

    for (final song in songs) {
      if (song is Map) {
        final title = (song['title'] ?? '').toString().toLowerCase();
        final isLiveOrUnofficial = title.contains('(live') ||
            title.contains('[live') ||
            title.contains('live at') ||
            title.contains('live from') ||
            title.contains('fancam') ||
            title.contains('concert');
        if (isLiveOrUnofficial) {
          liveList.add(song);
        } else {
          studioList.add(song);
        }
      } else {
        studioList.add(song);
      }
    }
    return [...studioList, ...liveList];
  }

  void _handleSearchSongPlay(dynamic song, int index) {
    if (song is! Map) return;
    final mode = searchQueueMode.value;
    if (mode == 'related_autoplay') {
      audioHandler.playSongWithRelated(song);
    } else if (mode == 'ask_every_time') {
      _showSearchQueueChoiceSheet(context, song, index);
    } else {
      // Default: 'search_results'
      final songsList = _songsSearchResult.whereType<Map>().toList();
      audioHandler.addPlaylistToQueue(songsList, replace: true, startIndex: index);
    }
  }

  Future<void> _showSearchQueueChoiceSheet(
    BuildContext context,
    Map song,
    int index,
  ) {
    return GlassModalSheet.show<void>(
      context: context,
      detents: const {GlassSheetDetent.medium},
      settings: glassSheetSettings(context),
      builder: (sheetContext) {
        final labelColor = glassSheetLabelColor(sheetContext);
        final subtitleColor = glassSheetSubtitleColor(sheetContext);
        final isDark =
            GlassTheme.brightnessOf(sheetContext) == Brightness.dark;
        final rowColor = isDark
            ? CupertinoColors.white.withValues(alpha: 0.09)
            : CupertinoColors.black.withValues(alpha: 0.045);
        final selectedColor = isDark
            ? CupertinoColors.white.withValues(alpha: 0.14)
            : CupertinoColors.black.withValues(alpha: 0.08);

        Widget actionRow({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
        }) {
          return CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: rowColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 20, color: labelColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 15,
                    color: subtitleColor,
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  song['title']?.toString() ?? 'Play Song',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: labelColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  song['artist']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                actionRow(
                  icon: CupertinoIcons.list_bullet,
                  title: 'Play with Search Queue',
                  subtitle: 'Keep the whole result list lined up next',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final songsList =
                        _songsSearchResult.whereType<Map>().toList();
                    audioHandler.addPlaylistToQueue(
                      songsList,
                      replace: true,
                      startIndex: index,
                    );
                  },
                ),
                const SizedBox(height: 10),
                actionRow(
                  icon: CupertinoIcons.radiowaves_right,
                  title: 'Play with Related Songs',
                  subtitle: 'Let the algorithm do its little dance',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    audioHandler.playSongWithRelated(song);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchResultsHeader extends StatelessWidget {
  const _SearchResultsHeader({
    required this.query,
    required this.fetching,
    required this.onBack,
  });

  final String query;
  final ValueNotifier<bool> fetching;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final subColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.6)
        : const Color(0xFF8E8E93);

    return Row(
      children: [
        GlassIconButton(
          icon: Icon(CupertinoIcons.back, color: titleColor),
          onPressed: onBack,
          size: 42,
          iconSize: 19,
          semanticLabel: 'Back to Explore',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search results',
                style: TextStyle(fontSize: 12, color: subColor),
              ),
              Text(
                query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                  color: titleColor,
                ),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: fetching,
          builder: (context, loading, _) => AnimatedOpacity(
            opacity: loading ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: const CupertinoTheme(
              data: CupertinoThemeData(brightness: Brightness.dark),
              child: CupertinoActivityIndicator(radius: 9),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchResultsEmpty extends StatelessWidget {
  const _SearchResultsEmpty({required this.query, required this.fetching});

  final String query;
  final ValueNotifier<bool> fetching;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final subColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.6)
        : const Color(0xFF8E8E93);

    return ValueListenableBuilder<bool>(
      valueListenable: fetching,
      builder: (context, loading, _) {
        if (loading) {
          return const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: CupertinoTheme(
                data: CupertinoThemeData(brightness: Brightness.dark),
                child: CupertinoActivityIndicator(radius: 16),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
          child: Column(
            children: [
              Icon(
                FluentIcons.search_24_regular,
                size: 44,
                color: subColor,
              ),
              const SizedBox(height: 14),
              Text(
                'No results for “$query”',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try the dock search with a different spelling, artist or album.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.35, color: subColor),
              ),
            ],
          ),
        );
      },
    );
  }
}
