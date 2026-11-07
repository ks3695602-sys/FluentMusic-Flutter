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
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide ColorScheme;
import 'package:musify/constants/app_constants.dart';
import 'package:musify/database/radio_stations.db.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/models/radio_model.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/artist_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/custom_bar.dart';
import 'package:musify/widgets/custom_search_bar.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_bar.dart';
import 'package:musify/widgets/radio_station_card.dart';
import 'package:musify/widgets/section_title.dart';
import 'package:musify/widgets/song_bar.dart';

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
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ValueNotifier<bool> _fetchingSongs = ValueNotifier(false);
  int maxSongsInList = 15;
  List<dynamic> _songsSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _albumsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<RadioStation> _radioStationsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;
  int _latestSuggestionRequest = 0;
  int _latestSearchRequest = 0;

  Future<void> _submitSearch([String? query]) async {
    if (query != null) {
      _searchBar.text = query;
      _searchBar.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchBar.text.length),
      );
    }

    _latestSuggestionRequest++;
    _debounce?.cancel();
    _suggestionsList = [];
    if (mounted) setState(() {});

    await search();
    _inputNode.unfocus();
  }

  @override
  void dispose() {
    _searchBar.dispose();
    _inputNode.dispose();
    _fetchingSongs.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> search() async {
    final query = _searchBar.text.trim();
    final requestId = ++_latestSearchRequest;

    if (query.isEmpty) {
      _songsSearchResult = [];
      _artistsSearchResult = [];
      _albumsSearchResult = [];
      _playlistsSearchResult = [];
      _radioStationsSearchResult = [];
      _suggestionsList = [];
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
          setState(() => _songsSearchResult = songs);
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
    final primaryColor = Theme.of(context).colorScheme.primary;
    return GlassScaffold(
      contentAwareBrightness: true,
      appBar: GlassAppBar(
        title: Text(
          context.l10n?.search ?? 'Search',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: CupertinoColors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final bar = ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 600 : double.infinity,
                  ),
                  child: CustomSearchBar(
                    loadingProgressNotifier: _fetchingSongs,
                    controller: _searchBar,
                    focusNode: _inputNode,
                    labelText: '${context.l10n!.search}...',
                    onChanged: (value) {
                      // debounce suggestions to avoid rapid API calls
                      _debounce?.cancel();
                      final query = value;
                      final requestId = ++_latestSuggestionRequest;

                      // An emptied field goes back to the search history, and
                      // the history only shows while nothing has been found
                      // yet. Dropping the suggestions is not enough: the
                      // results of the last search have to go with them.
                      if (query.isEmpty) {
                        unawaited(search());
                        return;
                      }

                      _debounce = Timer(
                        const Duration(milliseconds: 300),
                        () async {
                          final searchSuggestions = await getSearchSuggestions(
                            query,
                          );

                          if (!mounted ||
                              requestId != _latestSuggestionRequest ||
                              _searchBar.text != query) {
                            return;
                          }

                          _suggestionsList = List<String>.from(
                            searchSuggestions,
                          );
                          if (mounted) setState(() {});
                        },
                      );
                    },
                    onSubmitted: (String value) {
                      _submitSearch();
                    },
                  ),
                );
                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [bar],
                  );
                } else {
                  return bar;
                }
              },
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  (_suggestionsList.isNotEmpty ||
                      (_songsSearchResult.isEmpty &&
                          _artistsSearchResult.isEmpty &&
                          _albumsSearchResult.isEmpty &&
                          _playlistsSearchResult.isEmpty &&
                          _radioStationsSearchResult.isEmpty))
                  ? ValueListenableBuilder<List>(
                      valueListenable: searchHistoryNotifier,
                      builder: (context, searchHistory, _) {
                        final items = _suggestionsList.isEmpty
                            ? searchHistory
                            : _suggestionsList;

                        return _suggestionsList.isEmpty
                            ? _buildAppleBrowseSection(context, searchHistory)
                            : Column(
                                key: ValueKey('suggestions-${_suggestionsList.length}'),
                                children: [
                                  for (int index = 0; index < _suggestionsList.length; index++)
                                    CustomBar(
                                      _suggestionsList[index],
                                      FluentIcons.search_24_regular,
                                      borderRadius: getItemBorderRadius(index, _suggestionsList.length),
                                      onTap: () => _submitSearch(_suggestionsList[index]),
                                    ),
                                ],
                              );
                      },
                    )
                  : _buildSearchResults(context, primaryColor),
            ),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

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
            true,
            key: listItemKey('search_song', index, song),
            showMusicDuration: true,
            borderRadius: borderRadius,
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

  Widget _buildAppleBrowseSection(BuildContext context, List searchHistory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (searchHistory.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => _showConfirmationDialog(context).then((confirmed) {
                    if (confirmed == true) {
                      searchHistoryNotifier.value = [];
                      unawaited(addOrUpdateData<List>('user', 'searchHistory', []));
                    }
                  }),
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Color(0xFFFF2D55), fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              for (int i = 0; i < searchHistory.length && i < 5; i++)
                GlassListTile(
                  leading: const Icon(CupertinoIcons.search, color: Colors.white70, size: 18),
                  title: Text(
                    searchHistory[i].toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  trailing: const Icon(CupertinoIcons.arrow_up_left, color: Colors.white38, size: 16),
                  onTap: () => _submitSearch(searchHistory[i].toString()),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Browse Categories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _buildCategoryTile('Bollywood Hits', const [Color(0xFFFF2D55), Color(0xFFFF375F)], CupertinoIcons.music_note_2),
              _buildCategoryTile('Top 100 Global', const [Color(0xFF5856D6), Color(0xFFAF52DE)], CupertinoIcons.chart_bar_fill),
              _buildCategoryTile('Chill & Acoustic', const [Color(0xFF007AFF), Color(0xFF5AC8FA)], CupertinoIcons.headphones),
              _buildCategoryTile('Party & Dance', const [Color(0xFFFF9500), Color(0xFFFFCC00)], CupertinoIcons.flame_fill),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTile(String title, List<Color> gradientColors, IconData icon) {
    return GestureDetector(
      onTap: () {
        _searchBar.text = title;
        _submitSearch(title);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          confirmationMessage: context.l10n!.removeSearchQueryQuestion,
          submitMessage: context.l10n!.confirm,
          onCancel: () {
            Navigator.of(context).pop(false);
          },
          onSubmit: () {
            Navigator.of(context).pop(true);
          },
        );
      },
    );
  }
}
