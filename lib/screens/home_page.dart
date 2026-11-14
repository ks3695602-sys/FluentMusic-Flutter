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

import 'dart:ui' as ui;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/search_bridge.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/listening_stats_utils.dart';
import 'package:musify/widgets/announcement_box.dart';
import 'package:musify/widgets/home/home_artists_rail.dart';
import 'package:musify/widgets/home/home_genres.dart';
import 'package:musify/widgets/home/home_quick_picks.dart';
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
  late Future<List> _recommendedSongsFuture;

  @override
  void initState() {
    super.initState();
    _suggestedPlaylistsFuture = getPlaylists(
      playlistsNum: recommendedCubesNumber,
    );
    _recommendedSongsFuture = getRecommendedSongs();
    externalRecommendations.addListener(_refreshRecommendedSongs);
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
      backgroundColor: Colors.transparent,
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
              ),
            ),
            // Announcement (only when a remote message exists)
            SliverToBoxAdapter(
              child: ValueListenableBuilder<String?>(
                valueListenable: announcementURL,
                builder: (_, _url, __) {
                  if (_url == null) return const SizedBox.shrink();
                  final isSponsorshipAnnouncement = isSponsorshipAnnouncementUrl(
                    _url,
                  );
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
            // Songs first: recents → quick picks → playlists → recommended.
            SliverToBoxAdapter(child: _buildRecentlyPlayedSection()),
            SliverToBoxAdapter(child: _buildQuickPicksSection()),
            SliverToBoxAdapter(child: _buildSuggestedPlaylists()),
            SliverToBoxAdapter(
              child: _buildSuggestedPlaylists(showOnlyLiked: true),
            ),
            SliverToBoxAdapter(child: _buildRecommendedSongsSection()),
            // Artists come after every song rail.
            SliverToBoxAdapter(child: _buildArtistsSection()),
            SliverToBoxAdapter(child: _buildCurrentMonthRecapSection()),
            SliverToBoxAdapter(child: _buildGenresSection()),
            // Keeps the last row comfortably above the glass dock.
            const SliverMiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyPlayedSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemTitleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final itemSubColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.65)
        : const Color(0xFF8E8E93);

    return ValueListenableBuilder<List>(
      valueListenable: userRecentlyPlayed,
      builder: (context, recents, _) {
        if (recents.isEmpty) return const SizedBox.shrink();
        final displaySongs = recents.take(12).toList();
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
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                clipBehavior: Clip.none,
                itemCount: displaySongs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final song = displaySongs[index];
                  final title = song['title']?.toString() ?? '';
                  final artist = song['artist']?.toString() ?? '';
                  final image = song['highResImage'] ??
                      song['image'] ??
                      song['lowResImage'];

                  return SizedBox(
                    width: 140,
                    child: GestureDetector(
                      onTap: () async {
                        await audioHandler.playPlaylistSong(
                          playlist: {
                            'title': context.l10n?.recentlyPlayed ??
                                'Recently Played',
                            'list': recents,
                          },
                          songIndex: index,
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              children: [
                                PlaylistArtwork(
                                  playlistArtwork: image,
                                  size: 140,
                                  cubeIcon: CupertinoIcons.music_note,
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: CupertinoColors.black
                                          .withValues(alpha: 0.55),
                                      border: Border.all(
                                        color: CupertinoColors.white
                                            .withValues(alpha: 0.25),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.play_fill,
                                      color: CupertinoColors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: itemSubColor,
                              fontSize: 12,
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
    final itemTitleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final itemSubColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.65)
        : const Color(0xFF8E8E93);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            title: sectionTitle,
          ),
        ),
        SizedBox(
          height: 200,
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
              final subtitle = playlist['author']?.toString() ??
                  (playlist['isAlbum'] == true
                      ? (context.l10n?.album ?? 'Album')
                      : (context.l10n?.playlist ?? 'Playlist'));

              return SizedBox(
                width: 140,
                child: GestureDetector(
                  onTap: () =>
                      context.push('/home/playlist/${playlist['ytid']}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlaylistCube(
                        playlist,
                        size: 140,
                        borderRadius: 18,
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
                        style: TextStyle(
                          color: itemSubColor,
                          fontSize: 12,
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
  }

  static const int _quickPickCount = 6;

  Widget _buildQuickPicksSection() {
    return AsyncLoader<List<dynamic>>(
      future: _recommendedSongsFuture,
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();
        final picks = data.take(_quickPickCount).toList();
        return HomeQuickPicks(
          songs: picks,
          onSongTap: (index) => _playQuickPick(data, index),
        );
      },
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
              SectionHeader(
                title: context.l10n!.timeMachine,
              ),
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
  });

  final bool isDark;
  final Color iconBgColor;
  final Color iconBorderColor;
  final VoidCallback onProfileTap;

  static const double _maxExtent = 108;
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
    final surface = isDark ? const Color(0xFF120D1A) : const Color(0xFFF7F7FA);
    final titleSize = ui.lerpDouble(32, 19, t)!;
    final titleWeight = t > 0.55 ? FontWeight.w700 : FontWeight.w800;

    final content = Container(
      color: surface.withValues(alpha: 0.84 * t),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
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
              child: GestureDetector(
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
        oldDelegate.onProfileTap != onProfileTap;
  }
}
