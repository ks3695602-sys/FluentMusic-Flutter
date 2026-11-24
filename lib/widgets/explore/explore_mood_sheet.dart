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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/widgets/explore/explore_shimmer.dart';
import 'package:musify/widgets/glass/glass_sheet_style.dart';
import 'package:musify/widgets/song_bar.dart';

/// A one-tap discovery mood shown as a chip on Explore.
class ExploreMood {
  const ExploreMood({
    required this.label,
    required this.query,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  final String label;
  final String query;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
}

const exploreMoods = <ExploreMood>[
  ExploreMood(
    label: 'Chill',
    query: 'chill acoustic songs',
    subtitle: 'Slow down with soft acoustics',
    icon: CupertinoIcons.moon_stars_fill,
    colors: [Color(0xFF5E5CE6), Color(0xFF64D2FF)],
  ),
  ExploreMood(
    label: 'Focus',
    query: 'focus instrumental music',
    subtitle: 'Instrumentals that stay out of the way',
    icon: FluentIcons.headphones_20_filled,
    colors: [Color(0xFF30B0C7), Color(0xFF34C759)],
  ),
  ExploreMood(
    label: 'Energy',
    query: 'high energy workout songs',
    subtitle: 'A little extra voltage',
    icon: CupertinoIcons.bolt_fill,
    colors: [Color(0xFFFF9500), Color(0xFFFF2D55)],
  ),
  ExploreMood(
    label: 'Late Night',
    query: 'late night drive songs',
    subtitle: 'Headlights, empty roads, good speakers',
    icon: CupertinoIcons.moon_fill,
    colors: [Color(0xFF5856D6), Color(0xFF1C1C1E)],
  ),
  ExploreMood(
    label: 'Romance',
    query: 'romantic love songs',
    subtitle: 'For the soft-hearted playlist',
    icon: CupertinoIcons.heart_fill,
    colors: [Color(0xFFFF375F), Color(0xFFFF6482)],
  ),
  ExploreMood(
    label: 'Throwback',
    query: 'throwback hits',
    subtitle: 'Songs you forgot you knew every word to',
    icon: CupertinoIcons.clock_fill,
    colors: [Color(0xFFFFCC00), Color(0xFFFF9500)],
  ),
];

/// Opens the mood picker and plays songs from the chosen mood.
Future<void> showExploreMoodSheet(BuildContext context, ExploreMood mood) {
  final songsFuture = fetchSongsList(mood.query);

  return GlassModalSheet.show<void>(
    context: context,
    detents: const {GlassSheetDetent.medium, GlassSheetDetent.large},
    settings: glassSheetSettings(context),
    builder: (sheetContext) {
      final brightness = GlassTheme.brightnessOf(sheetContext);
      final labelColor = glassSheetLabelColor(
        sheetContext,
        brightness: brightness,
      );
      final subtitleColor = glassSheetSubtitleColor(
        sheetContext,
        brightness: brightness,
      );

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: mood.colors,
                      ),
                    ),
                    child: Icon(mood.icon, color: CupertinoColors.white),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mood.label,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mood.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List>(
                  future: songsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _MoodSkeleton();
                    }

                    final songs = (snapshot.data ?? const [])
                        .whereType<Map>()
                        .map(Map<String, dynamic>.from)
                        .toList(growable: false);
                    if (songs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nothing queued for this mood yet. Try again in a moment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 32),
                      itemCount: songs.length > 20 ? 20 : songs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return SongBar(
                          song,
                          false,
                          key: listItemKey('explore_mood_song', index, song),
                          showMusicDuration: true,
                          borderRadius: BorderRadius.circular(16),
                          onPlay: () {
                            Navigator.pop(sheetContext);
                            audioHandler.addPlaylistToQueue(
                              songs,
                              replace: true,
                              startIndex: index,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MoodSkeleton extends StatelessWidget {
  const _MoodSkeleton();

  @override
  Widget build(BuildContext context) {
    return ExploreShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Row(
          children: const [
            ExploreShimmerBox(width: 52, height: 52, borderRadius: 14),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExploreShimmerBox(
                    width: double.infinity,
                    height: 14,
                    borderRadius: 7,
                  ),
                  SizedBox(height: 8),
                  ExploreShimmerBox(width: 140, height: 12, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
