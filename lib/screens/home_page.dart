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
import 'dart:ui' as ui;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/search_bridge.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/ytmusic_library_store.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/listening_stats_utils.dart';
import 'package:musify/widgets/announcement_box.dart';
import 'package:musify/widgets/home/home_artists_rail.dart';
import 'package:musify/widgets/home/home_genres.dart';
import 'package:musify/widgets/home/home_hero.dart';
import 'package:musify/widgets/home/home_quick_picks.dart';
import 'package:musify/widgets/home/home_ytmusic_shelves.dart';
import 'package:musify/widgets/listening_recap_card.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_artwork.dart';
import 'package:musify/widgets/playlist_cube.dart';
import 'package:musify/widgets/recommended_songs_section.dart';
import 'package:musify/widgets/section_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<List> _suggestedPlaylistsFuture;
  bool _showMore = false;
  late Future<List> _recommendedSongsFuture;

  @override
  void initState() {
    super.initState();
    _suggestedPlaylistsFuture = getPlaylists(
      playlistsNum: recommendedCubesNumber,
    );
    _recommendedSongsFuture = getRecommendedSongs();
    externalRecommendations.addListener(_refreshRecommendedSongs);
    // Restore the cached account library immediately, then refresh it in the
    // background if the last sync is older than six hours.
    unawaited(restoreYtMusicLibrary().then((_) => autoSyncYtMusicLibrary()));
  }

  @override
  void dispose() {
    externalRecommendations.removeListener(_refreshRecommendedSongs);
    super.dispose();
  }

  void _refreshRecommendedSongs() {
    if (!mounted) return;
    setState(() {
      _recommendedSongsFuture = getRecommendedSongs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBgColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.12)
        : const Color(0xFF000000).withValues(alpha: 0.08);
    final iconBorderColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.20)
        : const Color(0xFF000000).withValues(alpha: 0.15);

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure OLED black
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          // iOS-style rubber banding: the same spring feel as Apple Music.
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeHeaderDelegate(
                isDark: isDark,
                iconBgColor: iconBgColor,
                iconBorderColor: iconBorderColor,
                onProfileTap: () => context.go('/settings'),
                onThemeToggle: () {
                  final next = isDark ? ThemeMode.light : ThemeMode.dark;
                  addOrUpdateData<int>('settings', 'themeIndex', next.index);
                  Musify.updateAppState(context, newThemeMode: next);
                },
              ),
            ),
            // Announcement (only when a remote message exists)
            SliverToBoxAdapter(
              child: ValueListenableBuilder<String?>(
                valueListenable: announcementURL,
                builder: (_, _url, __) {
                  if (_url == null) return const SizedBox.shrink();
                  final isSponsorshipAnnouncement =
                      isSponsorshipAnnouncementUrl(_url);
                  final _message = isSponsorshipAnnouncement
                      ? context.l10n!.sponsorProject
                      : context.l10n!.newAnnouncement;
                  final _icon = isSponsorshipAnnouncement
                      ? FluentIcons.heart_24_filled
                      : FluentIcons.megaphone_24_filled;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: AnnouncementBox(
                      message: _message,
                      url: _url,
                      icon: _icon,
                      onDismiss: () async {
                        announcementURL.value = null;
                      },
                    ),
                  );
                },
              ),
            ),
            // Top Picks carousel is the primary, artwork-led Home entry point.
            SliverToBoxAdapter(child: _buildQuickPicksSection()),
            SliverToBoxAdapter(child: _buildRecentlyPlayedSection()),
            SliverToBoxAdapter(child: _buildMoreToggle()),
            if (_showMore) ...[
              // Retain the original hero actions and every discovery section.
              const SliverToBoxAdapter(child: HomeHero()),
              const SliverToBoxAdapter(child: HomeYtMusicShelves()),
              SliverToBoxAdapter(child: _buildSuggestedPlaylists()),
              SliverToBoxAdapter(
                child: _buildSuggestedPlaylists(showOnlyLiked: true),
              ),
              SliverToBoxAdapter(child: _buildRecommendedSongsSection()),
              SliverToBoxAdapter(child: _buildArtistsSection()),
              SliverToBoxAdapter(child: _buildCurrentMonthRecapSection()),
              SliverToBoxAdapter(child: _buildGenresSection()),
            ],
            // Keeps the last row comfortably above the glass dock.
            const SliverMiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyPlayedSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemTitleColor = isDark
        ? CupertinoColors.white
        : const Color(0xFF1C1C1E);
    final itemSubColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.65)
        : const Color(0xFF8E8E93);

    return ValueListenableBuilder<List>(
      valueListenable: userRecentlyPlayed,
      builder: (context, recents, _) {
        if (recents.isEmpty) return const SizedBox.shrink();
        final displaySongs = recents.take(16).toList();
        final columnCount = (displaySongs.length / 4).ceil();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                title: context.l10n?.recentlyPlayed ?? 'Recently Played',
              ),
            ),
            SizedBox(
              height: 280,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                clipBehavior: Clip.none,
                itemCount: columnCount,
                separatorBuilder: (_, __) => const SizedBox(width: 18),
                itemBuilder: (context, column) => SizedBox(
                  width: 286,
                  child: Column(
                    children: [
                      for (var row = 0; row < 4; row++)
                        if (column * 4 + row < displaySongs.length)
                          SizedBox(
                            height: 68,
                            child: _recentSongTile(
                              displaySongs[column * 4 + row],
                              column * 4 + row,
                              recents,
                              itemTitleColor,
                              itemSubColor,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuggestedPlaylists({bool showOnlyLiked = false}) {
    if (showOnlyLiked) {
      return ValueListenableBuilder<List<Map>>(
        valueListenable: userLikedPlaylists,
        builder: (_, likedPlaylists, __) => _buildSuggestedPlaylistsSection(
          likedPlaylists
              .where((playlist) => !isArtistPlaylist(playlist))
              .take(recommendedCubesNumber)
              .toList(),
          showOnlyLiked: true,
        ),
      );
    }

    return AsyncLoader<List<dynamic>>(
      future: _suggestedPlaylistsFuture,
      builder: (context, playlists) =>
          _buildSuggestedPlaylistsSection(playlists),
    );
  }

  Widget _buildSuggestedPlaylistsSection(
    List<dynamic> playlists, {
    bool showOnlyLiked = false,
  }) {
    if (playlists.isEmpty) return const SizedBox.shrink();

    final sectionTitle = showOnlyLiked
        ? context.l10n!.backToFavorites
        : context.l10n!.suggestedPlaylists;
    final itemsNumber = playlists.length.clamp(0, recommendedCubesNumber);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemTitleColor = isDark
        ? CupertinoColors.white
        : const Color(0xFF1C1C1E);
    final itemSubColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.65)
        : const Color(0xFF8E8E93);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(title: sectionTitle),
        ),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.none,
            itemCount: itemsNumber,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              final title = playlist['title']?.toString() ?? '';
              final subtitle =
                  playlist['author']?.toString() ??
                  (playlist['isAlbum'] == true
                      ? (context.l10n?.album ?? 'Album')
                      : (context.l10n?.playlist ?? 'Playlist'));

              return SizedBox(
                width: 168,
                child: GestureDetector(
                  onTap: () =>
                      context.push('/home/playlist/${playlist['ytid']}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlaylistCube(
                        playlist,
                        size: 168,
                        borderRadius: 20,
                        showTypeLabel: false,
                        showPlayBadge: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: itemTitleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: itemSubColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static const int _quickPickCount = 12;

  Widget _buildQuickPicksSection() {
    return AsyncLoader<List<dynamic>>(
      future: _recommendedSongsFuture,
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();
        final picks = data.take(_quickPickCount).toList();
        final width = MediaQuery.sizeOf(context).width * 0.43;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(title: 'Top Picks'),
            ),
            SizedBox(
              height: width * 4 / 3 + 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                clipBehavior: Clip.none,
                itemCount: picks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final song = picks[index];
                  final title = song['title']?.toString() ?? '';
                  final artist = song['artist']?.toString() ?? '';
                  final artwork =
                      song['highResImage'] ??
                      song['image'] ??
                      song['lowResImage'];
                  return SizedBox(
                    width: width,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _playQuickPick(data, index),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            clipBehavior: Clip.antiAlias,
                            child: SizedBox(
                              width: width,
                              height: width * 4 / 3,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.cover,
                                    clipBehavior: Clip.hardEdge,
                                    child: PlaylistArtwork(
                                      playlistArtwork: artwork?.toString(),
                                      playlistTitle: title,
                                      size: width * 4 / 3,
                                      cubeIcon: CupertinoIcons.music_note,
                                    ),
                                  ),
                                  // Progressive blur-bleed scrim
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: ClipRect(
                                      child: BackdropFilter(
                                        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20, tileMode: TileMode.decal),
                                        child: Container(
                                          height: (width * 4 / 3) * 0.40,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.85),
                                              ],
                                              stops: const [0.0, 1.0],
                                            ),
                                          ),
                                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Top Pick',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white.withOpacity(0.9),
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: -0.5,
                                                  height: 1.2,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                artist,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white.withOpacity(0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _recentSongTile(
    dynamic song,
    int index,
    List recents,
    Color titleColor,
    Color subtitleColor,
  ) {
    final title = song['title']?.toString() ?? '';
    final artist = song['artist']?.toString() ?? '';
    final image = song['highResImage'] ?? song['image'] ?? song['lowResImage'];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => audioHandler.playPlaylistSong(
        playlist: {
          'title': context.l10n?.recentlyPlayed ?? 'Recently Played',
          'list': recents,
        },
        songIndex: index,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PlaylistArtwork(
                playlistArtwork: image?.toString(),
                playlistTitle: title,
                size: 52,
                cubeIcon: CupertinoIcons.music_note,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white60
                          : subtitleColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(CupertinoIcons.ellipsis, size: 18, color: subtitleColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextButton.icon(
        onPressed: () => setState(() => _showMore = !_showMore),
        icon: Icon(
          _showMore ? CupertinoIcons.chevron_up : CupertinoIcons.ellipsis,
        ),
        label: Text(_showMore ? 'Less' : 'More'),
        style: TextButton.styleFrom(
          foregroundColor: isDark
              ? CupertinoColors.white
              : const Color(0xFF1C1C1E),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }

  Future<void> _playQuickPick(List<dynamic> songs, int index) async {
    if (songs.isEmpty) return;
    await audioHandler.playPlaylistSong(
      playlist: {'title': 'Quick Picks', 'list': songs},
      songIndex: index,
    );
  }

  Widget _buildArtistsSection() {
    return ValueListenableBuilder<List<Map>>(
      valueListenable: userLikedPlaylists,
      builder: (context, _, __) {
        final artists = getLikedArtistItems().take(12).toList();
        if (artists.isEmpty) return const SizedBox.shrink();
        return HomeArtistsRail(
          artists: artists,
          onArtistTap: (index) => _openArtist(artists[index]),
        );
      },
    );
  }

  void _openArtist(Map artist) {
    final id = (artist['ytid'] ?? artist['id'] ?? '').toString();
    if (id.isEmpty) return;
    context.push('/home/artist/${Uri.encodeComponent(id)}', extra: artist);
  }

  Widget _buildGenresSection() {
    return HomeGenres(
      onGenreTap: (genre) {
        // Queue the query for the search branch, then switch to it. The bridge
        // survives a cold SearchPage, so the results still appear.
        InlineSearchBridge.submit(genre);
        context.go('/search');
      },
    );
  }

  Widget _buildRecommendedSongsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AsyncLoader<List<dynamic>>(
        future: _recommendedSongsFuture,
        builder: (context, data) {
          final songs = data.skip(_quickPickCount).toList();
          if (songs.isEmpty) return const SizedBox.shrink();
          return RecommendedSongsSection(
            title: context.l10n!.recommendedForYou,
            songs: songs,
            listKeyPrefix: 'home_recommended',
          );
        },
      ),
    );
  }

  Widget _buildCurrentMonthRecapSection() {
    return ValueListenableBuilder<bool>(
      valueListenable: wrappedEnabled,
      builder: (_, isEnabled, __) {
        if (!isEnabled) return const SizedBox.shrink();

        final currentMonthKey = listeningStatsMonthKey(DateTime.now());
        final monthStats = listeningStatsService.monthStats(currentMonthKey);
        final songs = listeningStatsService.monthTopSongs(currentMonthKey);
        final displayMinutes = monthDisplayMinutes(monthStats);
        if (displayMinutes <= 0 && songs.isEmpty) {
          return const SizedBox.shrink();
        }

        final previewSongs = songs.take(wrappedShareSongsLimit).toList();
        final periodLabel = formatMonthPeriodLabel(
          Localizations.localeOf(context),
          currentMonthKey,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: context.l10n!.timeMachine),
              ListeningRecapCard(
                periodLabel: periodLabel,
                minutes: displayMinutes,
                songs: previewSongs,
                onSongTap: (index) => _playRecapSongs(previewSongs, index),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push('/home/timeMachine'),
                    icon: const Icon(FluentIcons.arrow_right_24_regular),
                    label: Text(context.l10n!.listeningStats),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _playRecapSongs(
    List<Map<String, dynamic>> songs,
    int index,
  ) async {
    if (songs.isEmpty) return;
    await audioHandler.playPlaylistSong(
      playlist: {'title': context.l10n!.timeMachine, 'list': songs},
      songIndex: index,
    );
  }
}

/// Large "Listen Now" title that collapses into a compact blurred bar.
///
/// The blur layer only exists once the header is actually collapsing, so the
/// page pays zero backdrop cost at rest.
class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HomeHeaderDelegate({
    required this.isDark,
    required this.iconBgColor,
    required this.iconBorderColor,
    required this.onProfileTap,
    required this.onThemeToggle,
  });

  final bool isDark;
  final Color iconBgColor;
  final Color iconBorderColor;
  final VoidCallback onProfileTap;
  final VoidCallback onThemeToggle;

  // Keep the large title close to the hero card. The old 108 px header left a
  // blank band above the title on every tunnel/punch-hole Android phone.
  static const double _maxExtent = 88;
  static const double _minExtent = 56;

  @override
  double get maxExtent => _maxExtent;

  @override
  double get minExtent => _minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / (_maxExtent - _minExtent)).clamp(0.0, 1.0);
    final titleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final surface = isDark ? const Color(0xFF000000) : const Color(0xFFF7F7FA);
    final titleSize = ui.lerpDouble(30, 19, t)!;
    final titleWeight = t > 0.55 ? FontWeight.w700 : FontWeight.w800;

    final content = Container(
      color: surface.withValues(alpha: 0.84 * t),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Listen Now',
                style: TextStyle(
                  color: titleColor,
                  fontSize: titleSize,
                  fontWeight: titleWeight,
                  letterSpacing: -0.6,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: isDark
                        ? 'Switch to light theme'
                        : 'Switch to dark theme',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onThemeToggle,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconBgColor,
                          border: Border.all(color: iconBorderColor, width: 1),
                        ),
                        child: Icon(
                          isDark
                              ? CupertinoIcons.moon_fill
                              : CupertinoIcons.sun_max_fill,
                          color: titleColor,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onProfileTap,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: iconBgColor,
                        border: Border.all(color: iconBorderColor, width: 1),
                      ),
                      child: Icon(
                        CupertinoIcons.person_crop_circle_fill,
                        color: titleColor,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (t <= 0.01) return content;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18 * t, sigmaY: 18 * t),
        child: content,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.iconBgColor != iconBgColor ||
        oldDelegate.iconBorderColor != iconBorderColor ||
        oldDelegate.onProfileTap != onProfileTap ||
        oldDelegate.onThemeToggle != onThemeToggle;
  }
}
