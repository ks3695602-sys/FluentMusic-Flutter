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

import 'package:audio_service/audio_service.dart' show PlaybackState;
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart' show Ticker;
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

class _SyncedLyricsViewState extends State<SyncedLyricsView>
    with SingleTickerProviderStateMixin {
  late final LyricController _controller;
  late final Ticker _ticker;
  StreamSubscription<PositionData>? _positionSubscription;
  StreamSubscription<PlaybackState>? _playbackSubscription;
  Duration _offset = Duration.zero;

  Duration _lastPosition = Duration.zero;
  DateTime _lastPositionTime = DateTime.now();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _offset = Duration(milliseconds: lyricsOffsetMs.value);
    lyricsOffsetMs.addListener(_onOffsetChanged);
    _controller = LyricController();
    _loadLyrics();

    _ticker = createTicker(_onTick);

    _positionSubscription = audioHandler.positionDataStream.listen((data) {
      if (!mounted) return;
      _lastPosition = data.position;
      _lastPositionTime = DateTime.now();
      _syncPosition();
    });

    _playbackSubscription = audioHandler.playbackState.listen((state) {
      if (!mounted) return;
      final playing = state.playing;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        if (playing) {
          _lastPositionTime = DateTime.now();
          if (!_ticker.isTicking) _ticker.start();
        } else {
          if (_ticker.isTicking) _ticker.stop();
        }
      }
    });

    // Seed initial position and playback state
    try {
      final currentPos = audioHandler.currentPositionData.position;
      _lastPosition = currentPos;
      _lastPositionTime = DateTime.now();
      _isPlaying = audioHandler.playbackState.value.playing;
      _syncPosition();
      if (_isPlaying) {
        _ticker.start();
      }
    } catch (_) {}
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying) return;
    final now = DateTime.now();
    final elapsedSinceLast = now.difference(_lastPositionTime);
    final estimatedPos = _lastPosition + elapsedSinceLast + _offset;
    try {
      _controller.setPosition(
        estimatedPos.isNegative ? Duration.zero : estimatedPos,
      );
    } catch (_) {}
  }

  void _syncPosition() {
    final effectivePos = _lastPosition + _offset;
    try {
      _controller.setPosition(
        effectivePos.isNegative ? Duration.zero : effectivePos,
      );
    } catch (_) {}
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
    _syncPosition();
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
    _ticker.dispose();
    _positionSubscription?.cancel();
    _playbackSubscription?.cancel();
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
      final cleanPlain = (widget.lyrics.plain ?? '')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\[\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?\]'), '')
          .trim();
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Center(
          child: Text(
            cleanPlain.isEmpty ? 'No Lyrics Available' : cleanPlain,
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
