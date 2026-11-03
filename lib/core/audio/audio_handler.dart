import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../innertube/innertube_service.dart';
import 'audio_models.dart';

class FluentAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final InnertubeService _innertubeService = InnertubeService();

  final List<MediaTrack> _playlist = [];
  int _currentIndex = -1;

  AudioPlayer get player => _player;
  List<MediaTrack> get currentPlaylist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;

  FluentAudioHandler() {
    _initAudioServiceEvents();
  }

  void _initAudioServiceEvents() {
    // Broadcast player state changes (playing, buffering, completed)
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex >= 0 ? _currentIndex : null,
      ));
    });

    // Handle track completion -> auto play next
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  Future<void> playTrack(MediaTrack track, {List<MediaTrack>? queue}) async {
    if (queue != null && queue.isNotEmpty) {
      _playlist.clear();
      _playlist.addAll(queue);
      _currentIndex = _playlist.indexWhere((t) => t.id == track.id);
      if (_currentIndex == -1) {
        _playlist.insert(0, track);
        _currentIndex = 0;
      }
    } else {
      _playlist.clear();
      _playlist.add(track);
      _currentIndex = 0;
    }

    _broadcastQueue();
    await _loadAndPlayTrack(track);
  }

  Future<void> _loadAndPlayTrack(MediaTrack track) async {
    try {
      // Update AudioService media item for notification
      mediaItem.add(MediaItem(
        id: track.id,
        album: track.album,
        title: track.title,
        artist: track.artist,
        duration: track.duration,
        artUri: track.artUri.isNotEmpty ? Uri.tryParse(track.artUri) : null,
      ));

      String? audioUri = track.streamUrl;

      // If online track and stream URL not resolved yet, resolve via Innertube
      if (!track.isLocal && (audioUri == null || audioUri.isEmpty)) {
        audioUri = await _innertubeService.getAudioStreamUri(track.id);
      } else if (track.isLocal && track.localFilePath != null) {
        audioUri = track.localFilePath;
      }

      if (audioUri != null && audioUri.isNotEmpty) {
        if (track.isLocal) {
          await _player.setFilePath(audioUri);
        } else {
          await _player.setUrl(audioUri);
        }
        await _player.play();
      }
    } catch (e) {
      debugPrint('[FluentAudioHandler] Error playing track ${track.title}: $e');
    }
  }

  void _broadcastQueue() {
    queue.add(_playlist.map((t) => MediaItem(
      id: t.id,
      album: t.album,
      title: t.title,
      artist: t.artist,
      duration: t.duration,
      artUri: t.artUri.isNotEmpty ? Uri.tryParse(t.artUri) : null,
    )).toList());
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;
    if (_currentIndex + 1 < _playlist.length) {
      _currentIndex++;
      await _loadAndPlayTrack(_playlist[_currentIndex]);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playlist.isEmpty) return;
    if (_currentIndex > 0) {
      _currentIndex--;
      await _loadAndPlayTrack(_playlist[_currentIndex]);
    } else {
      await _player.seek(Duration.zero);
    }
  }
}
