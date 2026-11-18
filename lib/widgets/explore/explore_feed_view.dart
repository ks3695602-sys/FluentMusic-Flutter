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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/main.dart';
import 'package:musify/services/explore_service.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/widgets/explore/explore_mood_sheet.dart';
import 'package:musify/widgets/explore/explore_shimmer.dart';
import 'package:musify/widgets/explore/shorts_viewer_page.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_cube.dart';
import 'package:musify/widgets/song_bar.dart';

/// The discovery feed shown on the Explore tab whenever no query is active.
class ExploreFeedView extends StatefulWidget {
  const ExploreFeedView({
    required this.recentSearches,
    required this.onSearch,
    super.key,
  });

  final List<String> recentSearches;
  final ValueChanged<String> onSearch;

  @override
  State<ExploreFeedView> createState() => _ExploreFeedViewState();
}

class _ExploreFeedViewState extends State<ExploreFeedView> {
  final PageController _bannerController = PageController(
    viewportFraction: 0.9,
  );

  ExploreFeed? _feed;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _feed = ExploreService.instance.cached;
    _loading = _feed == null;
    _load();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (force && mounted) {
      setState(() => _failed = false);
    }
    try {
      final feed = await ExploreService.instance.load(force: force);
      if (!mounted) return;
      setState(() {
        _feed = feed;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _openShorts(int index, Rect? fromRect) {
    final feed = _feed;
    if (feed == null) return;
    ShortsViewerPage.show(
      context,
      songs: feed.shorts,
      initialIndex: index,
      fromRect: fromRect,
    );
  }

  void _playSongPick(int index) {
    final songs = _feed?.songPicks ?? const <Map<String, dynamic>>[];
    if (songs.isEmpty) return;
    audioHandler.addPlaylistToQueue(songs, replace: true, startIndex: index);
  }

  void _openPlaylist(Map<String, dynamic> playlist) {
    final id = playlist['ytid']?.toString() ?? '';
    if (id.isEmpty) return;
    context.push(
      '${NavigationManager.searchPath}/playlist/${Uri.encodeComponent(id)}',
      extra: playlist,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;

    if (feed == null) {
      if (_loading) return const ExploreFeedSkeleton();
      return _ExploreEmptyView(
        failed: _failed,
        onRetry: () => _load(force: true),
      );
    }

    if (feed.isEmpty) {
      return _ExploreEmptyView(
        failed: _failed,
        onRetry: () => _load(force: true),
      );
    }

    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final subColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.62)
        : const Color(0xFF636366);
    final topPadding = MediaQuery.paddingOf(context).top;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => _load(force: true),
        ),
        SliverPadding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          'Explore',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                            letterSpacing: -0.8,
                            height: 1.05,
                          ),
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFF375F).withValues(alpha: 0.9),
                              const Color(0xFFFF9F0A).withValues(alpha: 0.9),
                            ],
                          ),
                        ),
                        child: const Icon(
                          FluentIcons.sparkle_24_filled,
                          color: CupertinoColors.white,
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Shorts, fresh songs and playlists picked for you.',
                    style: TextStyle(fontSize: 14, color: subColor),
                  ),
                ],
              ),
            ),
          ),
          if (widget.recentSearches.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                    child: Text(
                      'Recent searches',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: widget.recentSearches.length > 8
                          ? 8
                          : widget.recentSearches.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final query = widget.recentSearches[index];
                        return GestureDetector(
                          onTap: () => widget.onSearch(query),
                          child: GlassContainer(
                            shape: const LiquidRoundedRectangle(
                              borderRadius: 19,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.clock,
                                  size: 12,
                                  color: subColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  query,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: titleColor,
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
              ),
            ),
          if (feed.shorts.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _ExploreSectionHeader(
                title: 'Music Shorts',
                subtitle: '15–30 second previews',
                icon: FluentIcons.play_24_filled,
                topPadding: 26,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 262,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: feed.shorts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _ShortsCard(
                    song: feed.shorts[index],
                    onTap: (rect) => _openShorts(index, rect),
                  ),
                ),
              ),
            ),
          ],
          if (feed.featured.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _ExploreSectionHeader(
                title: 'Featured playlists',
                subtitle: 'Editorial picks to start from',
                icon: FluentIcons.megaphone_24_filled,
                topPadding: 26,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: SizedBox(
                  height: 180,
                  child: PageView.builder(
                    controller: _bannerController,
                    padEnds: false,
                    physics: const BouncingScrollPhysics(),
                    itemCount: feed.featured.length,
                    itemBuilder: (context, index) {
                      final playlist = feed.featured[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _FeaturedBanner(
                          playlist: playlist,
                          onTap: () => _openPlaylist(playlist),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: _ExploreSectionHeader(
              title: 'Moods',
              subtitle: 'Pick a feeling, get a queue',
              icon: CupertinoIcons.wand_stars,
              topPadding: 26,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mood in exploreMoods)
                    _MoodChip(
                      mood: mood,
                      onTap: () => showExploreMoodSheet(context, mood),
                    ),
                ],
              ),
            ),
          ),
          if (feed.songPicks.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _ExploreSectionHeader(
                title: 'Made for you',
                subtitle: 'Songs that fit right now',
                icon: FluentIcons.music_note_2_24_filled,
                topPadding: 30,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = feed.songPicks[index];
                  return SongBar(
                    song,
                    false,
                    key: listItemKey('explore_song', index, song),
                    showMusicDuration: true,
                    borderRadius: getItemBorderRadius(
                      index,
                      feed.songPicks.length,
                    ),
                    onPlay: () => _playSongPick(index),
                  );
                }, childCount: feed.songPicks.length),
              ),
            ),
          ],
          if (feed.curated.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _ExploreSectionHeader(
                title: 'Curated playlists',
                subtitle: 'Longer listens for later',
                icon: FluentIcons.apps_list_24_filled,
                topPadding: 28,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 214,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: feed.curated.length > 12
                      ? 12
                      : feed.curated.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final playlist = feed.curated[index];
                    final title =
                        playlist['title']?.toString() ?? 'Playlist';
                    final subtitle =
                        playlist['author']?.toString() ?? 'Playlist';
                    return SizedBox(
                      width: 150,
                      child: GestureDetector(
                        onTap: () => _openPlaylist(playlist),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlaylistCube(
                              playlist,
                              size: 150,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: subColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          const SliverMiniPlayerBottomSpace(),
      ],
    );
  }
}

class _ExploreSectionHeader extends StatelessWidget {
  const _ExploreSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.topPadding = 24,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final subColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.55)
        : const Color(0xFF8E8E93);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: isDark
                  ? CupertinoColors.white.withValues(alpha: 0.10)
                  : CupertinoColors.black.withValues(alpha: 0.05),
            ),
            child: Icon(icon, size: 15, color: titleColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    letterSpacing: -0.35,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: subColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortsCard extends StatelessWidget {
  const _ShortsCard({required this.song, required this.onTap});

  final Map<String, dynamic> song;
  final ValueChanged<Rect?> onTap;

  @override
  Widget build(BuildContext context) {
    final image = (song['highResImage'] ??
            song['image'] ??
            song['lowResImage'])
        ?.toString();
    final category = song['exploreCategory']?.toString() ?? 'New';

    void handleTap() {
      final box = context.findRenderObject() as RenderBox?;
      final rect = box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      onTap(rect);
    }

    return GestureDetector(
      onTap: handleTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: 144,
          height: 256,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image == null || image.isEmpty)
                const ColoredBox(
                  color: Color(0xFF1C1C1E),
                  child: Center(
                    child: Icon(
                      FluentIcons.music_note_2_24_regular,
                      color: CupertinoColors.white,
                    ),
                  ),
                )
              else
                CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (_, __) => const ColoredBox(
                    color: Color(0xFF1C1C1E),
                  ),
                  errorWidget: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF1C1C1E),
                    child: Center(
                      child: Icon(
                        FluentIcons.music_note_2_24_regular,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0x22000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.0, 0.35, 0.55, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.black.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.white.withValues(alpha: 0.22),
                      width: 0.7,
                    ),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      color: CupertinoColors.white.withValues(alpha: 0.92),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CupertinoColors.black.withValues(alpha: 0.38),
                    border: Border.all(
                      color: CupertinoColors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    FluentIcons.play_24_filled,
                    color: CupertinoColors.white,
                    size: 18,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song['title']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      song['artist']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CupertinoColors.white.withValues(alpha: 0.7),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.playlist, required this.onTap});

  final Map<String, dynamic> playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = (playlist['image'] ??
            playlist['highResImage'] ??
            playlist['lowResImage'])
        ?.toString();
    final title = playlist['title']?.toString() ?? 'Featured playlist';

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image == null || image.isEmpty)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3A3A3C), Color(0xFF1C1C1E)],
                  ),
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => const ColoredBox(
                  color: Color(0xFF1C1C1E),
                ),
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: Color(0xFF1C1C1E),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xD9000000)],
                  stops: [0.25, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 14,
              bottom: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FEATURED PLAYLIST',
                          style: TextStyle(
                            color: CupertinoColors.white.withValues(
                              alpha: 0.65,
                            ),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CupertinoColors.white.withValues(alpha: 0.18),
                      border: Border.all(
                        color: CupertinoColors.white.withValues(alpha: 0.28),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.chevron_forward,
                      color: CupertinoColors.white,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.mood, required this.onTap});

  final ExploreMood mood;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        shape: const LiquidRoundedRectangle(borderRadius: 20),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: mood.colors,
                ),
              ),
              child: Icon(mood.icon, size: 11, color: CupertinoColors.white),
            ),
            const SizedBox(width: 7),
            Text(
              mood.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreEmptyView extends StatelessWidget {
  const _ExploreEmptyView({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final subColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.6)
        : const Color(0xFF8E8E93);
    final topPadding = MediaQuery.paddingOf(context).top;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(28, topPadding + 14, 28, 40),
      children: [
          Text(
            'Explore',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: titleColor,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 80),
          Icon(
            failed
                ? FluentIcons.cloud_off_24_regular
                : CupertinoIcons.compass_fill,
            size: 46,
            color: subColor,
          ),
          const SizedBox(height: 14),
          Text(
            failed
                ? 'Explore could not load right now.'
                : 'Nothing to explore yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check your connection and try again. Search still works from the dock.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.35, color: subColor),
          ),
          const SizedBox(height: 20),
          Center(
            child: GlassButton.custom(
              onTap: onRetry,
              height: 44,
              width: 132,
              shape: const LiquidRoundedRectangle(borderRadius: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.arrow_counterclockwise,
                    size: 15,
                    color: titleColor,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Try again',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
