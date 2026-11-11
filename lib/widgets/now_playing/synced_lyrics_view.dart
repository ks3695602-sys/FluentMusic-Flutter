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
import 'package:flutter_lyric/flutter_lyric.dart' hide LyricLine;
import 'package:musify/main.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/services/lyrics/lyrics_models.dart';
import 'package:musify/services/settings_manager.dart';

/// Studio-grade Apple Music (01 / Float) Synced Karaoke Lyrics View powered by flutter_lyric.
class SyncedLyricsView extends StatefulWidget {
  const SyncedLyricsView({super.key, required this.lyrics});

  final Lyrics lyrics;

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  late final LyricController _controller;
  StreamSubscription<PositionData>? _positionSubscription;
  Duration _offset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _offset = Duration(milliseconds: lyricsOffsetMs.value);
    lyricsOffsetMs.addListener(_onOffsetChanged);
    _controller = LyricController();
    _loadLyrics();

    _positionSubscription = audioHandler.positionDataStream.listen((data) {
      if (!mounted) return;
      final effectivePos = data.position + _offset;
      try {
        _controller.setPosition(
          effectivePos.isNegative ? Duration.zero : effectivePos,
        );
      } catch (_) {}
    });
  }

  void _loadLyrics() {
    final lrc = widget.lyrics.toLrc();
    if (lrc.isNotEmpty) {
      try {
        _controller.load(lrc);
      } catch (e) {
        debugPrint('Lyric load error: $e');
      }
    }
  }

  void _onOffsetChanged() {
    if (!mounted) return;
    setState(() {
      _offset = Duration(milliseconds: lyricsOffsetMs.value);
    });
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      _loadLyrics();
    }
  }

  @override
  void dispose() {
    lyricsOffsetMs.removeListener(_onOffsetChanged);
    _positionSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.lyrics.isSynced &&
        (widget.lyrics.plain == null || widget.lyrics.plain!.isEmpty)) {
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

    if (!widget.lyrics.isSynced) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Center(
          child: Text(
            widget.lyrics.plain ?? '',
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LyricView(
        controller: _controller,
        preset: LyricPresets.appleMusic,
        onLineTap: (line) {
          final target = line.seekPosition - _offset;
          audioHandler.seek(target.isNegative ? Duration.zero : target);
        },
      ),
    );
  }
}
