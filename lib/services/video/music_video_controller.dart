import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/constants/clients.dart'
    show getManifestWithFallback, streamPlaybackHeadersForUrl;
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/services/proxy_manager.dart' show ytClient;
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Portions derived from BitChord (kushagrasinghx/BitChord), GPL-3.0.
/// https://github.com/kushagrasinghx/BitChord
///
/// A music video's picture: a second, silent player held to the audio's clock.
/// The audio stays authoritative — it keeps the cache, the EQ and everything
/// else — and the picture follows it: its rate nudged a few percent for small
/// drift, a seek for a large one, exactly as BitChord's ExoPlayer engine does.
enum MusicVideoStatus { idle, loading, ready, unavailable, error, unsupported }

/// What the quality switcher shows: every height the loaded video offers, the
/// height the listener pinned (null is Auto), and the one on screen.
@immutable
class MusicVideoQuality {
  const MusicVideoQuality({
    this.heights = const [],
    this.held,
    this.activeHeight,
  });

  /// Largest first.
  final List<int> heights;
  final int? held;
  final int? activeHeight;

  MusicVideoQuality copyWith({
    List<int>? heights,
    int? held,
    bool clearHeld = false,
    int? activeHeight,
    bool clearActive = false,
  }) => MusicVideoQuality(
    heights: heights ?? this.heights,
    held: clearHeld ? null : (held ?? this.held),
    activeHeight: clearActive ? null : (activeHeight ?? this.activeHeight),
  );
}

class _CachedStream {
  const _CachedStream(this.stream, this.cap, this.at, this.heights);
  final VideoOnlyStreamInfo stream;
  final int cap;
  final DateTime at;

  /// Every height the video offers, largest first — what the switcher lists.
  final List<int> heights;
}

class MusicVideoController extends ChangeNotifier {
  MusicVideoController() {
    _audio = audioHandler.audioPlayer;
    _stateSub = _audio.playerStateStream.listen((state) {
      _playing = state.playing;
      _sync();
      _notify();
    });
    _speedSub = _audio.speedStream.listen((_) => _sync());
    _syncTimer = Timer.periodic(_syncEvery, (_) => _sync());
  }

  /// Past this the picture jumps to the audio; under it, its rate is nudged.
  static const Duration _seekDrift = Duration(milliseconds: 450);
  static const int _ignoreDriftMs = 25;
  static const Duration _syncEvery = Duration(milliseconds: 250);

  /// No second seek inside this, while the first is still landing.
  static const Duration _seekCooldown = Duration(milliseconds: 1500);

  /// A paused decoder follows a scrub almost immediately.
  static const Duration _pausedDrift = Duration(milliseconds: 40);
  static const Duration _pausedCooldown = Duration(milliseconds: 120);

  /// Where Auto opens: the top of YouTube's H.264 ladder, as on the web player.
  static const int _autoHeight = 1080;
  static const int _meteredHeight = 480;

  /// Narrower than this is a cover held still, not a picture worth showing.
  static const double _minVideoAspect = 1.2;

  /// A googlevideo URL lives about six hours; reuse it well inside that.
  static const Duration _streamTtl = Duration(hours: 1);
  static const int _maxCachedStreams = 8;

  static const String _qualityKey = 'musicVideoQuality';

  late final AudioPlayer _audio;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<double>? _speedSub;
  Timer? _syncTimer;

  MusicVideoStatus _status = MusicVideoStatus.idle;
  MusicVideoStatus get status => _status;

  String? _videoId;
  String? get videoId => _videoId;

  /// The video whose frames are on screen now, once its first one has landed.
  String? _shownVideoId;
  String? get shownVideoId => _shownVideoId;

  bool get isRendered => _shownVideoId != null && _shownVideoId == _videoId;

  double _aspect = 16 / 9;
  double get aspect => _aspect;

  MusicVideoQuality _quality = const MusicVideoQuality();
  MusicVideoQuality get quality => _quality;

  bool _playing = false;
  bool get isPlaying => _playing;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  VideoPlayerController? _video;
  VideoPlayerController? get videoPlayerController => _video;

  bool get isReady =>
      _status == MusicVideoStatus.ready &&
      (_video?.value.isInitialized ?? false);

  bool _disposed = false;
  bool _syncInProgress = false;
  int _generation = 0;
  int _loadedCap = 0;
  DateTime _lastSeekAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _seekLeadMs = 250;

  /// How far ahead of the audio a seek is aimed: what the last one took.
  final Map<String, _CachedStream> _streams = {};

  /// Tracks with no picture, so a change back to one doesn't ask again.
  final Set<String> _noPicture = {};

  /// Videos whose held height wouldn't decode here, played at Auto instead.
  final Set<String> _stepDown = {};

  bool _qualityLoaded = false;

  /// Holds the picture at [height] from now on, or lets Auto choose with null.
  /// The playing video reloads at once, at the moment the audio is at.
  Future<void> setQuality(int? height) async {
    _ensureQualityLoaded();
    _quality = _quality.copyWith(held: height, clearHeld: height == null);
    _persistQuality(height);
    _notify();
    final id = _videoId;
    if (id == null) return;
    _streams.remove(id);
    _stepDown.remove(id);
    await load(id);
  }

  /// Resolves and loads a muted video-only stream for [videoId].
  ///
  /// H.264 in MP4 is preferred, at the connection's cap. Returns `true` when
  /// the video controller initialized successfully.
  Future<bool> load(String videoId) async {
    if (_disposed) return false;
    final generation = ++_generation;
    _videoId = videoId;
    _errorMessage = null;
    _shownVideoId = null;
    _quality = _quality.copyWith(heights: const [], clearActive: true);
    _setStatus(MusicVideoStatus.loading);
    await _disposeVideoController();
    if (!_isCurrent(generation)) return false;

    if (!_isSupported) {
      _setStatus(MusicVideoStatus.unsupported);
      return false;
    }
    if (_noPicture.contains(videoId)) {
      _setStatus(MusicVideoStatus.unavailable);
      return false;
    }

    try {
      _ensureQualityLoaded();
      final cap = await _capFor(videoId);
      final stream = await _resolve(videoId, cap);
      if (!_isCurrent(generation)) return false;
      if (stream == null) {
        _noPicture.add(videoId);
        _setStatus(MusicVideoStatus.unavailable);
        return false;
      }

      final width = stream.videoResolution.width;
      final height = stream.videoResolution.height;
      if (height <= 0 || width / height < _minVideoAspect) {
        // A catalogue track's "video" is its cover held still.
        _noPicture.add(videoId);
        _setStatus(MusicVideoStatus.unavailable);
        return false;
      }

      final headers = streamPlaybackHeadersForUrl(
        videoId,
        stream.url.toString(),
      );
      final controller = VideoPlayerController.networkUrl(
        stream.url,
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _video = controller;
      _loadedCap = cap;
      _aspect = width / height;
      _quality = _quality.copyWith(
        heights: _streams[videoId]?.heights ?? [height],
        activeHeight: height,
      );

      await controller.initialize().timeout(const Duration(seconds: 35));
      if (!_isCurrent(generation) || !identical(_video, controller)) {
        await _disposeSpecific(controller);
        return false;
      }

      await controller.setVolume(0);
      await controller.setLooping(false);
      await controller.setPlaybackSpeed(_audio.speed);
      controller.addListener(_onVideoChanged);
      _setStatus(MusicVideoStatus.ready);

      // Start where the audio is, aimed a little ahead for the seek's landing.
      final start = _audio.position;
      _lastSeekAt = DateTime.now();
      await controller.seekTo(
        _clampDuration(
          start + Duration(milliseconds: _seekLeadMs),
          controller.value.duration,
        ),
      );
      if (!_isCurrent(generation)) return false;
      if (_audio.playing) {
        await controller.play();
      }
      return true;
    } catch (error) {
      if (!_isCurrent(generation)) return false;
      _errorMessage = error.toString();
      developer.log(
        'music video: failed to load $videoId: $error',
        name: 'MusicVideo',
      );
      // Above 1080p YouTube serves VP9/AV1, which not every phone decodes:
      // one more try on the H.264 ladder before giving up.
      if (_loadedCap > _autoHeight && _stepDown.add(videoId)) {
        return load(videoId);
      }
      _setStatus(MusicVideoStatus.error);
      await _disposeVideoController();
      return false;
    }
  }

  /// Clears the current video and invalidates any in-flight load.
  Future<void> stop() async {
    if (_disposed) return;
    ++_generation;
    _videoId = null;
    _shownVideoId = null;
    _errorMessage = null;
    await _disposeVideoController();
    if (!_disposed) _setStatus(MusicVideoStatus.idle);
  }

  /// Toggle the audio playback; the picture follows it automatically.
  Future<void> togglePlayback() async {
    if (_audio.playing) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
  }

  bool get _isSupported => !kIsWeb && Platform.isAndroid;

  Future<int> _capFor(String videoId) async {
    _ensureQualityLoaded();
    final held = _quality.held;
    if (held != null) {
      return _stepDown.contains(videoId)
          ? (held < _autoHeight ? held : _autoHeight)
          : held;
    }
    var metered = false;
    try {
      final results = await Connectivity().checkConnectivity();
      metered =
          results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.wifi) &&
          !results.contains(ConnectivityResult.ethernet);
    } catch (_) {}
    return metered ? _meteredHeight : _autoHeight;
  }

  Future<VideoOnlyStreamInfo?> _resolve(String videoId, int cap) async {
    final cached = _cachedStream(videoId, cap);
    if (cached != null) return cached;

    final manifest = await getManifestWithFallback(
      ytClient,
      videoId,
      timeout: const Duration(seconds: 30),
    );
    final stream = _selectStream(manifest.videoOnly, cap);
    if (stream != null) {
      _streams[videoId] = _CachedStream(
        stream,
        cap,
        DateTime.now(),
        _heightsIn(manifest.videoOnly),
      );
      while (_streams.length > _maxCachedStreams) {
        _streams.remove(_streams.keys.first);
      }
    }
    return stream;
  }

  VideoOnlyStreamInfo? _cachedStream(String videoId, int cap) {
    final cached = _streams[videoId];
    if (cached == null) return null;
    if (cached.cap != cap ||
        DateTime.now().difference(cached.at) > _streamTtl) {
      _streams.remove(videoId);
      return null;
    }
    return cached.stream;
  }

  VideoOnlyStreamInfo? _selectStream(
    Iterable<VideoOnlyStreamInfo> streams,
    int cap,
  ) {
    final usable = streams
        .where((stream) => stream.url.host.isNotEmpty)
        .toList(growable: false);
    if (usable.isEmpty) return null;

    final underCap = usable
        .where((stream) => stream.videoResolution.height <= cap)
        .toList(growable: false);
    final candidates = underCap.isNotEmpty
        ? underCap
        : [
            usable.reduce(
              (a, b) =>
                  a.videoResolution.height <= b.videoResolution.height ? a : b,
            ),
          ];
    final preferred = candidates.where(_isPreferredFormat).toList();
    final pool = (preferred.isNotEmpty ? preferred : candidates)
      ..sort((a, b) {
        final height = b.videoResolution.height.compareTo(
          a.videoResolution.height,
        );
        if (height != 0) return height;
        final format = _formatRank(a).compareTo(_formatRank(b));
        if (format != 0) return format;
        return b.bitrate.compareTo(a.bitrate);
      });
    return pool.first;
  }

  bool _isPreferredFormat(VideoOnlyStreamInfo stream) =>
      stream.container.name.toLowerCase() == 'mp4' &&
      RegExp('^(avc1|avc3)', caseSensitive: false).hasMatch(stream.videoCodec);

  int _formatRank(VideoOnlyStreamInfo stream) => _isPreferredFormat(stream)
      ? 0
      : stream.container.name.toLowerCase() == 'mp4'
      ? 1
      : 2;

  /// Every height this one video offers, largest first — what the switcher
  /// lists. Scoped to the manifest, never to whatever else is cached.
  List<int> _heightsIn(Iterable<VideoOnlyStreamInfo> streams) {
    final heights = <int>{
      for (final stream in streams)
        if (stream.videoResolution.height > 0) stream.videoResolution.height,
    }.toList()..sort((a, b) => b.compareTo(a));
    return List.unmodifiable(heights);
  }

  Future<void> _sync({bool forceSeek = false}) async {
    final video = _video;
    if (_disposed ||
        _syncInProgress ||
        video == null ||
        !video.value.isInitialized ||
        _status != MusicVideoStatus.ready) {
      return;
    }
    _syncInProgress = true;
    try {
      final speed = _audio.speed;
      final audioPos = _audio.position;
      final now = DateTime.now();
      final value = video.value;

      if (!_audio.playing) {
        if (value.isPlaying) await video.pause();
        await _setVideoSpeed(video, speed);
        if ((value.position - audioPos).abs() > _pausedDrift &&
            now.difference(_lastSeekAt) > _pausedCooldown) {
          await _seek(video, audioPos);
        }
        return;
      }

      if (!value.isPlaying) await video.play();
      if (value.isBuffering) return;

      final drift = value.position - audioPos;
      if (forceSeek || drift.abs() > _seekDrift) {
        if (forceSeek || now.difference(_lastSeekAt) > _seekCooldown) {
          await _seek(video, audioPos + Duration(milliseconds: _seekLeadMs));
        }
        return;
      }

      // Catch up (or wait) over about a second, rather than jumping.
      final nudge = drift.inMilliseconds.abs() > _ignoreDriftMs
          ? (-drift.inMilliseconds / 1000).clamp(-0.1, 0.1)
          : 0.0;
      await _setVideoSpeed(video, speed * (1 + nudge));
    } catch (_) {
      // Sync is best-effort; a failed seek or speed update must not touch audio.
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _seek(VideoPlayerController video, Duration position) async {
    _lastSeekAt = DateTime.now();
    final started = _lastSeekAt;
    try {
      await video.seekTo(_clampDuration(position, video.value.duration));
    } finally {
      final took = DateTime.now().difference(started).inMilliseconds;
      _seekLeadMs = ((_seekLeadMs + took) ~/ 2).clamp(0, 1500);
    }
  }

  Future<void> _setVideoSpeed(VideoPlayerController video, double speed) async {
    if ((video.value.playbackSpeed - speed).abs() > 0.005) {
      await video.setPlaybackSpeed(speed.clamp(0.25, 2.0));
    }
  }

  Duration _clampDuration(Duration value, Duration duration) {
    if (value < Duration.zero) return Duration.zero;
    if (duration > Duration.zero && value > duration) return duration;
    return value;
  }

  void _onVideoChanged() {
    final video = _video;
    if (_disposed || video == null) return;
    if (video.value.hasError) {
      _errorMessage = video.value.errorDescription;
      _setStatus(MusicVideoStatus.error);
      return;
    }
    if (_shownVideoId == null &&
        video.value.isInitialized &&
        video.value.position > Duration.zero) {
      _shownVideoId = _videoId;
      _notify();
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _setStatus(MusicVideoStatus status) {
    if (_disposed || _status == status) return;
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _ensureQualityLoaded() {
    if (_qualityLoaded) return;
    _qualityLoaded = true;
    try {
      final box = Hive.box('settings');
      final stored = box.get(_qualityKey);
      if (stored is int && stored > 0) {
        _quality = _quality.copyWith(held: stored);
      }
    } catch (_) {
      // No box yet (very early start): Auto until a pick is persisted.
    }
  }

  void _persistQuality(int? height) {
    try {
      final box = Hive.box('settings');
      if (height == null) {
        box.delete(_qualityKey);
      } else {
        box.put(_qualityKey, height);
      }
    } catch (_) {}
  }

  Future<void> _disposeVideoController() async {
    final controller = _video;
    _video = null;
    if (controller != null) await _disposeSpecific(controller);
  }

  Future<void> _disposeSpecific(VideoPlayerController controller) async {
    controller.removeListener(_onVideoChanged);
    try {
      await controller.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _syncTimer?.cancel();
    unawaited(_stateSub?.cancel());
    unawaited(_speedSub?.cancel());
    final controller = _video;
    _video = null;
    if (controller != null) unawaited(_disposeSpecific(controller));
    super.dispose();
  }
}
