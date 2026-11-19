/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     FluentMusic is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/cupertino.dart';
import 'package:musify/main.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/lyrics/lyrics_models.dart';
import 'package:musify/services/lyrics_manager.dart';
import 'package:musify/services/settings_manager.dart';

/// One-line lyric preview shown on the player stage.
///
/// Mirrors the BitChord / Mornye layout: the current line stays bright with a
/// word sweep, the next line sits underneath in a quieter tone, and the whole
/// row is tappable to open the full lyrics mode. When a song has no timed
/// lyrics the widget collapses instead of leaving an empty gap.
class PlayerLyricPreview extends StatefulWidget {
  const PlayerLyricPreview({
    super.key,
    required this.metadata,
    required this.onTap,
    this.fontSize = 16,
  });

  final MediaItem metadata;
  final VoidCallback onTap;
  final double fontSize;

  @override
  State<PlayerLyricPreview> createState() => _PlayerLyricPreviewState();
}

class _PlayerLyricPreviewState extends State<PlayerLyricPreview> {
  String? _resolvedKey;
  Future<Lyrics?>? _lyricsFuture;

  @override
  void initState() {
    super.initState();
    _resolveIfNeeded();
  }

  @override
  void didUpdateWidget(PlayerLyricPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveIfNeeded();
  }

  void _resolveIfNeeded() {
    final key = '${widget.metadata.artist} - ${widget.metadata.title}';
    if (key == _resolvedKey) return;
    _resolvedKey = key;
    _lyricsFuture = getSongLyricsResult(
      widget.metadata.artist,
      widget.metadata.title,
      duration: widget.metadata.duration,
      album: widget.metadata.album,
      videoId: widget.metadata.extras?['ytid']?.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = _lyricsFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<Lyrics?>(
      future: future,
      builder: (context, snapshot) {
        final lyrics = snapshot.data;
        if (lyrics == null || !lyrics.isSynced) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<PositionData>(
          stream: audioHandler.positionDataStream,
          initialData: audioHandler.currentPositionData,
          builder: (context, positionSnapshot) {
            final data = positionSnapshot.data;
            if (data == null) return const SizedBox.shrink();

            final position =
                data.position + Duration(milliseconds: lyricsOffsetMs.value);
            final lines = lyrics.synced!;
            final index = lyrics.lineIndexAt(position);

            final Widget row;
            if (index < 0) {
              row = _PreviewRow(
                key: const ValueKey<int>(-1),
                onTap: widget.onTap,
                current: lines.isEmpty ? '' : lines.first.text,
                fontSize: widget.fontSize,
                words: const [],
                position: position,
              );
            } else {
              final current = lines[index];
              // One line only, exactly like the reference. The next line is a
              // tap away in the full lyrics screen, not a second row here.
              row = _PreviewRow(
                key: ValueKey<int>(index),
                onTap: widget.onTap,
                current: current.text,
                fontSize: widget.fontSize,
                words: current.words,
                position: position,
              );
            }

            // The row itself updates on every position tick (that is the word
            // sweep). Only a line change swaps the key, so only a line change
            // animates: the old line dissolves under the new one instead of
            // the text snapping.
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.centerLeft,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              child: row,
            );
          },
        );
      },
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    super.key,
    required this.onTap,
    required this.current,
    required this.fontSize,
    required this.words,
    required this.position,
  });

  final VoidCallback onTap;
  final String current;
  final double fontSize;
  final List<LyricWord> words;
  final Duration position;

  @override
  Widget build(BuildContext context) {
    if (current.trim().isEmpty) return const SizedBox.shrink();

    final bright = CupertinoColors.white.withValues(alpha: 0.94);
    final dim = CupertinoColors.white.withValues(alpha: 0.28);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: _SweptLine(
                text: current,
                words: words,
                position: position,
                fontSize: fontSize,
                baseColor: bright,
                dimColor: dim,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: CupertinoColors.white.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _SweptLine extends StatelessWidget {
  const _SweptLine({
    required this.text,
    required this.words,
    required this.position,
    required this.fontSize,
    required this.baseColor,
    required this.dimColor,
  });

  final String text;
  final List<LyricWord> words;
  final Duration position;
  final double fontSize;
  final Color baseColor;
  final Color dimColor;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: baseColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      );
    }

    final spans = <InlineSpan>[];
    for (final word in words) {
      final progress = _progress(word);
      spans.add(
        TextSpan(
          text: word.text,
          style: TextStyle(
            color: Color.lerp(dimColor, baseColor, progress),
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      );
      spans.add(const TextSpan(text: ' '));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  double _progress(LyricWord word) {
    if (position <= word.start) return 0;
    if (position >= word.end) return 1;
    final total = word.end.inMilliseconds - word.start.inMilliseconds;
    if (total <= 0) return 1;
    return ((position.inMilliseconds - word.start.inMilliseconds) / total)
        .clamp(0.0, 1.0);
  }
}
