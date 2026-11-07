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
 *     FluentMusic by jaypakash sahu
 *     https://github.com/ks3695602-sys/FluentMusic-Flutter
 */

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:musify/main.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/services/lyrics/lyrics_models.dart';
import 'package:musify/services/settings_manager.dart';

/// Apple Music iOS 26 Word-to-Word Synced Karaoke Lyrics View.
class SyncedLyricsView extends StatefulWidget {
  const SyncedLyricsView({super.key, required this.lyrics});

  final Lyrics lyrics;

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  static const Duration _manualScrollPause = Duration(seconds: 4);
  static const Duration _scrollDuration = Duration(milliseconds: 400);

  final ScrollController _scrollController = ScrollController();
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
    _rebuildKeys();
    _positionSubscription = audioHandler.positionDataStream.listen((data) {
      if (!mounted) return;
      final currentPos = data.position;
      final effectivePos = currentPos + _offset;
      final newIndex = widget.lyrics.lineIndexAt(effectivePos);

      setState(() {
        _position = currentPos;
      });

      if (newIndex != _activeIndex) {
        setState(() {
          _activeIndex = newIndex;
        });
        if (DateTime.now().isAfter(_autoScrollResumesAt)) {
          _scrollToActive();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      _rebuildKeys();
      _activeIndex = -1;
      _autoScrollResumesAt = DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _rebuildKeys() {
    _lineKeys = List.generate(_lines.length, (_) => GlobalKey());
  }

  void _scrollToActive() {
    if (_activeIndex < 0 || _activeIndex >= _lineKeys.length) return;
    final key = _lineKeys[_activeIndex];
    final context = key.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      alignment: 0.35,
      duration: _scrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _seekToLine(LyricLine line) {
    final target = line.start - _offset;
    audioHandler.seek(target.isNegative ? Duration.zero : target);
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;

    if (lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            widget.lyrics.plain ?? 'No Synced Lyrics Available',
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        if (notification.dragDetails != null) {
          _autoScrollResumesAt = DateTime.now().add(_manualScrollPause);
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = constraints.maxHeight * 0.35;
          final bottomPadding = constraints.maxHeight * 0.45;

          return ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(28, topPadding, 28, bottomPadding),
            itemCount: lines.length + 1,
            itemBuilder: (context, index) {
              if (index == lines.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 40, bottom: 20),
                  child: Text(
                    'Lyrics provided by ${widget.lyrics.source}',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.white.withValues(alpha: 0.35),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }

              final line = lines[index];
              final isActive = index == _activeIndex;

              return _AppleKaraokeLine(
                key: _lineKeys[index],
                line: line,
                isActive: isActive,
                currentPosition: _position + _offset,
                onTap: () => _seekToLine(line),
              );
            },
          );
        },
      ),
    );
  }
}

class _AppleKaraokeLine extends StatelessWidget {
  const _AppleKaraokeLine({
    super.key,
    required this.line,
    required this.isActive,
    required this.currentPosition,
    required this.onTap,
  });

  final LyricLine line;
  final bool isActive;
  final Duration currentPosition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            line.text,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white.withValues(alpha: 0.35),
              height: 1.45,
              letterSpacing: -0.3,
            ),
          ),
        ),
      );
    }

    // Active line with word-level synchronization
    if (line.hasWordSync && wordByWordLyricsEnabled.value) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: line.words.map((word) {
              final isPassed = currentPosition >= word.end;
              final isCurrent =
                  currentPosition >= word.start && currentPosition < word.end;

              final opacity = isPassed
                  ? 1.0
                  : isCurrent
                      ? 1.0
                      : 0.35;
              final scale = isCurrent ? 1.05 : 1.0;

              return AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 100),
                child: Text(
                  word.text,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.white.withValues(alpha: opacity),
                    letterSpacing: -0.4,
                    shadows: isCurrent
                        ? [
                            BoxShadow(
                              color: CupertinoColors.white.withValues(alpha: 0.6),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    // Fallback active line without syllable timestamps
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          line.text,
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: CupertinoColors.white,
            letterSpacing: -0.4,
            shadows: [
              BoxShadow(
                color: CupertinoColors.white.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
