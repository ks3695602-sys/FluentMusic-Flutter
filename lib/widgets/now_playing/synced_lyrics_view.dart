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
import 'package:flutter_lyric/lyric_ui/lyric_ui.dart';
import 'package:flutter_lyric/lyrics_model_builder.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/services/lyrics/lyrics_models.dart';
import 'package:musify/services/settings_manager.dart';

class AppleMusicLyricUI extends LyricUI {
  @override
  TextStyle getPlayingMainTextStyle() => const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFA2D48),
        height: 1.4,
      );

  @override
  TextStyle getPlayingExtTextStyle() => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFFFA2D48),
        height: 1.4,
      );

  @override
  TextStyle getOtherMainTextStyle() => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.38),
        height: 1.4,
      );

  @override
  TextStyle getOtherExtTextStyle() => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.38),
        height: 1.4,
      );

  @override
  double getLineSpace() => 24.0;

  @override
  double getInlineSpace() => 12.0;

  @override
  double getPlayingLineBias() => 0.45;

  @override
  LyricAlign getLyricHorizontalAlign() => LyricAlign.CENTER;

  @override
  double get bias => 0.45;

  @override
  double get lineGap => 24.0;

  @override
  LyricAlign get lyricAlign => LyricAlign.CENTER;

  @override
  bool enableHighlight() => true;
}

/// Shows time-synced lyrics: the current line is highlighted and kept in view,
/// tapping a line seeks to it, and the timing can be nudged with +/- buttons
/// when a lyrics file is slightly early or late.
class SyncedLyricsView extends StatefulWidget {
  const SyncedLyricsView({super.key, required this.lyrics});

  final Lyrics lyrics;

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  static const Duration _offsetStep = Duration(milliseconds: 500);
  static const Duration _manualScrollPause = Duration(seconds: 4);
  static const Duration _scrollDuration = Duration(milliseconds: 350);

  StreamSubscription<PositionData>? _positionSubscription;
  List<GlobalKey> _lineKeys = const [];
  Duration _position = Duration.zero;
  Duration _offset = Duration.zero;
  int _activeIndex = -1;
  DateTime _autoScrollResumesAt = DateTime.fromMillisecondsSinceEpoch(0);

  List<LyricLine> get _lines => widget.lyrics.synced ?? const <LyricLine>[];

  @override
  void initState() {
    super.initState();
    _prepareLines();
    _position = audioHandler.currentPositionData.position;
    _activeIndex = _computeActiveIndex();
    _positionSubscription = audioHandler.positionDataStream.listen((data) {
      _position = data.position;
      _refreshActiveLine();
    });
    _scheduleScrollToActive(animate: false);
  }

  @override
  void didUpdateWidget(SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lyrics, widget.lyrics)) {
      _prepareLines();
      _offset = Duration.zero;
      _activeIndex = _computeActiveIndex();
      _scheduleScrollToActive(animate: false);
    }
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }

  void _prepareLines() {
    _lineKeys = List<GlobalKey>.generate(_lines.length, (_) => GlobalKey());
  }

  int _computeActiveIndex() => widget.lyrics.lineIndexAt(_position + _offset);

  void _refreshActiveLine() {
    final index = _computeActiveIndex();
    if (index == _activeIndex || !mounted) return;
    setState(() => _activeIndex = index);
    _scheduleScrollToActive();
  }

  void _scheduleScrollToActive({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (DateTime.now().isBefore(_autoScrollResumesAt)) return;
      if (_activeIndex < 0 || _activeIndex >= _lineKeys.length) return;

      final lineContext = _lineKeys[_activeIndex].currentContext;
      if (lineContext == null) return;

      unawaited(
        Scrollable.ensureVisible(
          lineContext,
          alignment: 0.4,
          duration: animate ? _scrollDuration : Duration.zero,
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _changeOffset(Duration delta) {
    setState(() {
      _offset = delta == Duration.zero ? Duration.zero : _offset + delta;
      _activeIndex = _computeActiveIndex();
    });
    _autoScrollResumesAt = DateTime.fromMillisecondsSinceEpoch(0);
    _scheduleScrollToActive();
  }

  void _seekToLine(LyricLine line) {
    final target = line.start - _offset;
    unawaited(audioHandler.seek(target.isNegative ? Duration.zero : target));
    _autoScrollResumesAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get _offsetLabel {
    if (_offset == Duration.zero) return '0.0s';
    final seconds = _offset.inMilliseconds / 1000;
    return '${seconds > 0 ? '+' : ''}${seconds.toStringAsFixed(1)}s';
  }

  String _buildLrcString(List<LyricLine> lines) {
    final sb = StringBuffer();
    for (final l in lines) {
      final m = l.start.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = l.start.inSeconds.remainder(60).toString().padLeft(2, '0');
      final ms = (l.start.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
      sb.writeln('[$m:$s.$ms]${l.text}');
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSecondaryContainer;
    final lines = _lines;

    return Column(
      children: [
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: appleMusicLyricsEnabled,
            builder: (context, useAppleMusic, _) {
              if (useAppleMusic && lines.isNotEmpty) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final lrc = _buildLrcString(lines);
                    final model = LyricsModelBuilder.create()
                        .bindLyricToMain(lrc)
                        .getModel();
                    return LyricsReader(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      model: model,
                      position: (_position + _offset).inMilliseconds,
                      lyricUi: AppleMusicLyricUI(),
                      playing: audioHandler.playbackState.value.playing,
                      size: Size(double.infinity, constraints.maxHeight),
                      emptyBuilder: () => Center(
                        child: Text(
                          widget.lyrics.plain ?? 'No Lyrics',
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                      ),
                      onTap: () {},
                    );
                  },
                );
              }

              return NotificationListener<ScrollStartNotification>(
                onNotification: (notification) {
                  if (notification.dragDetails != null) {
                    _autoScrollResumesAt =
                        DateTime.now().add(_manualScrollPause);
                  }
                  return false;
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final edgePadding = constraints.maxHeight * 0.4;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        edgePadding,
                        20,
                        edgePadding,
                      ),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          for (var i = 0; i < lines.length; i++)
                            _buildLine(i, lines[i], textColor),
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Text(
                              '© ${widget.lyrics.source}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        _buildOffsetControls(textColor),
      ],
    );
  }

  Widget _buildLine(int index, LyricLine line, Color baseColor) {
    final isActive = index == _activeIndex;
    return GestureDetector(
      key: _lineKeys[index],
      onTap: () => _seekToLine(line),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontSize: isActive ? 20 : 16,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? const Color(0xFFFA2D48) : baseColor.withValues(alpha: 0.6),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
          child: Text(line.text),
        ),
      ),
    );
  }

  Widget _buildOffsetControls(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Earlier (-0.5s)',
            icon: const Icon(FluentIcons.subtract_24_regular, size: 18),
            color: textColor,
            onPressed: () => _changeOffset(-_offsetStep),
          ),
          Text(
            _offsetLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          IconButton(
            tooltip: 'Later (+0.5s)',
            icon: const Icon(FluentIcons.add_24_regular, size: 18),
            color: textColor,
            onPressed: () => _changeOffset(_offsetStep),
          ),
          if (_offset != Duration.zero)
            IconButton(
              tooltip: 'Reset offset',
              icon: const Icon(FluentIcons.dismiss_24_regular, size: 18),
              color: textColor,
              onPressed: () => _changeOffset(Duration.zero),
            ),
        ],
      ),
    );
  }
}
