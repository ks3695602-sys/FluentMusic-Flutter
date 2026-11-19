/*
 *     Copyright (C) 2026 jaypakash sahu
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
 *
 *     FluentMusic by jaypakash sahu
 *     https://github.com/ks3695602-sys/FluentMusic-Flutter
 */

import 'dart:async';

import 'package:audio_service/audio_service.dart' show PlaybackState;
import 'package:characters/characters.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:musify/main.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/services/lyrics/lyrics_models.dart';
import 'package:musify/services/settings_manager.dart';

/// BitChord / Mornye-style word-synced lyrics stage.
///
/// Only the active line repaints while the song plays: the position lives in a
/// [ValueNotifier] and the active row listens to it, while every neighbour is
/// built once per line change. That keeps long lyrics lists at 90/120 Hz without
/// re-blurring the whole column on every frame.
class SyncedLyricsView extends StatefulWidget {
  const SyncedLyricsView({
    super.key,
    required this.lyrics,
    this.showProvider = false,
    this.activeFontSize = 28,
  });

  final Lyrics lyrics;
  final bool showProvider;
  final double activeFontSize;

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView>
    with SingleTickerProviderStateMixin {
  static const _scrollDuration = Duration(milliseconds: 520);
  static const _scrollCurve = Curves.easeOutCubic;

  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _lineKeys = <GlobalKey>[];

  late final Ticker _ticker;
  StreamSubscription<PositionData>? _positionSubscription;
  StreamSubscription<PlaybackState>? _playbackSubscription;

  Duration _offset = Duration.zero;
  Duration _lastPosition = Duration.zero;
  DateTime _lastPositionTime = DateTime.now();
  bool _isPlaying = false;
  int _activeIndex = -1;

  List<LyricLine> get _lines => widget.lyrics.synced ?? const <LyricLine>[];

  @override
  void initState() {
    super.initState();
    _offset = Duration(milliseconds: lyricsOffsetMs.value);
    lyricsOffsetMs.addListener(_onOffsetChanged);
    _rebuildKeys();

    _ticker = createTicker(_onTick);

    _positionSubscription = audioHandler.positionDataStream.listen((data) {
      if (!mounted) return;
      _lastPosition = data.position;
      _lastPositionTime = DateTime.now();
      _syncPosition();
    });

    _playbackSubscription = audioHandler.playbackState.listen((state) {
      if (!mounted) return;
      _setPlaying(state.playing);
    });

    try {
      _lastPosition = audioHandler.currentPositionData.position;
      _lastPositionTime = DateTime.now();
      _isPlaying = audioHandler.playbackState.value.playing;
      _syncPosition();
      if (_isPlaying) _ticker.start();
    } catch (_) {}
  }

  void _rebuildKeys() {
    _lineKeys
      ..clear()
      ..addAll(List<GlobalKey>.generate(_lines.length, (_) => GlobalKey()));
  }

  void _setPlaying(bool playing) {
    if (_isPlaying == playing) return;
    _isPlaying = playing;
    if (playing) {
      _lastPositionTime = DateTime.now();
      if (!_ticker.isTicking) _ticker.start();
    } else {
      if (_ticker.isTicking) _ticker.stop();
    }
  }

  void _onTick(Duration _) {
    if (!_isPlaying) return;
    final elapsed = DateTime.now().difference(_lastPositionTime);
    final estimated = _lastPosition + elapsed + _offset;
    _syncTo(estimated.isNegative ? Duration.zero : estimated);
  }

  void _syncPosition() {
    final effective = _lastPosition + _offset;
    _syncTo(effective.isNegative ? Duration.zero : effective);
  }

  void _syncTo(Duration position) {
    _position.value = position;
    final nextIndex = widget.lyrics.lineIndexAt(position);
    if (nextIndex == _activeIndex) return;
    _activeIndex = nextIndex;
    if (mounted) setState(() {});
    _scrollToActive();
  }

  void _scrollToActive() {
    if (_activeIndex < 0 || _activeIndex >= _lineKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _lineKeys[_activeIndex].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.32,
        duration: _scrollDuration,
        curve: _scrollCurve,
      );
    });
  }

  void _onOffsetChanged() {
    if (!mounted) return;
    setState(() {
      _offset = Duration(milliseconds: lyricsOffsetMs.value);
    });
    _syncPosition();
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      _rebuildKeys();
      _activeIndex = -1;
      _syncPosition();
    }
  }

  @override
  void dispose() {
    lyricsOffsetMs.removeListener(_onOffsetChanged);
    _ticker.dispose();
    _positionSubscription?.cancel();
    _playbackSubscription?.cancel();
    _position.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.lyrics.isSynced) {
      return _plainFallback();
    }

    final lines = _lines;
    if (lines.isEmpty) {
      return _plainFallback();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stageHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                22,
                stageHeight * 0.28,
                22,
                stageHeight * 0.30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    RepaintBoundary(
                      key: _lineKeys[i],
                      child: _LyricLineTile(
                        line: lines[i],
                        index: i,
                        activeIndex: _activeIndex,
                        position: _position,
                        activeFontSize: widget.activeFontSize,
                        onTap: () => _seekToLine(lines[i]),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.showProvider || widget.lyrics.credit != null)
              Positioned(
                left: 22,
                right: 22,
                bottom: 10,
                // Left-aligned with the lyric column and underlined, exactly
                // like the reference. Attribution is not a footnote, it is a
                // condition of using these lyrics.
                child: Text(
                  widget.lyrics.attribution,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: CupertinoColors.white.withValues(alpha: 0.70),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                    decoration: TextDecoration.underline,
                    decorationColor:
                        CupertinoColors.white.withValues(alpha: 0.42),
                    decorationThickness: 1.1,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _plainFallback() {
    final cleanPlain = wrapLongLyricTokens(
      (widget.lyrics.plain ?? '')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\[\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?\]'), '')
          .trim(),
    );
    if (cleanPlain.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'No Lyrics Available',
            style: TextStyle(
              color: CupertinoColors.white.withValues(alpha: 0.6),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Center(
        child: Text(
          cleanPlain,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _seekToLine(LyricLine line) {
    final target = line.start - _offset;
    audioHandler.seek(target.isNegative ? Duration.zero : target);
  }
}

class _LyricLineTile extends StatelessWidget {
  const _LyricLineTile({
    required this.line,
    required this.index,
    required this.activeIndex,
    required this.position,
    required this.activeFontSize,
    required this.onTap,
  });

  final LyricLine line;
  final int index;
  final int activeIndex;
  final ValueNotifier<Duration> position;
  final double activeFontSize;
  final VoidCallback onTap;

  bool get _isActive => index == activeIndex;

  @override
  Widget build(BuildContext context) {
    final text = line.text.trim();
    if (text.isEmpty) return const SizedBox(height: 10);

    final base = _LyricText(
      line: line,
      active: _isActive,
      position: position,
      activeFontSize: activeFontSize,
    );

    // Lines melt away with distance instead of all sharing one opacity: the
    // next line stays legible, the one after is a hint, the rest is texture.
    //
    // This is deliberately done with opacity and type size alone. A blur per
    // line looks lovely in a screenshot but allocates one saveLayer for every
    // visible line, and that is exactly what makes a lyrics screen drop frames
    // on a phone that is already decoding audio.
    final distance = (index - activeIndex).abs();
    final opacity = switch (distance) {
      0 => 1.0,
      1 => 0.52,
      2 => 0.32,
      3 => 0.22,
      _ => 0.14,
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: _isActive ? 9 : 7),
          child: base,
        ),
      ),
    );
  }
}

class _LyricText extends StatelessWidget {
  const _LyricText({
    required this.line,
    required this.active,
    required this.position,
    required this.activeFontSize,
  });

  final LyricLine line;
  final bool active;
  final ValueNotifier<Duration> position;
  final double activeFontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: active ? activeFontSize : activeFontSize * 0.76,
      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
      height: 1.28,
      letterSpacing: active ? -0.6 : -0.3,
      color: CupertinoColors.white,
      shadows: const [
        Shadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 2)),
      ],
    );

    if (!active || line.words.isEmpty) {
      return Text(line.text, style: style);
    }

    return ValueListenableBuilder<Duration>(
      valueListenable: position,
      builder: (context, pos, _) {
        return Text.rich(
          TextSpan(children: _spans(pos, style)),
          style: style,
        );
      },
    );
  }

  List<InlineSpan> _spans(Duration pos, TextStyle style) {
    final spans = <InlineSpan>[];
    final dim = CupertinoColors.white.withValues(alpha: 0.34);
    for (final word in line.words) {
      final progress = _wordProgress(word, pos);
      final chars = word.text.characters.toList();
      final revealed = (progress * chars.length).floor().clamp(0, chars.length);
      final current = revealed < chars.length
          ? Color.lerp(dim, CupertinoColors.white, progress)!
          : CupertinoColors.white;

      if (revealed > 0) {
        spans.add(
          TextSpan(
            text: chars.take(revealed).join(),
            style: style.copyWith(color: CupertinoColors.white),
          ),
        );
      }
      if (revealed < chars.length) {
        spans.add(
          TextSpan(
            text: chars.skip(revealed).join(),
            style: style.copyWith(color: current),
          ),
        );
      }
      spans.add(const TextSpan(text: ' '));
    }
    return spans;
  }

  double _wordProgress(LyricWord word, Duration pos) {
    if (pos <= word.start) return 0;
    if (pos >= word.end) return 1;
    final total = word.end.inMilliseconds - word.start.inMilliseconds;
    if (total <= 0) return 1;
    return ((pos.inMilliseconds - word.start.inMilliseconds) / total)
        .clamp(0.0, 1.0);
  }
}
