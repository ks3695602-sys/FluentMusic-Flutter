import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:musify/mornye_player/utils/int_utils.dart';
import 'package:musify/mornye_player/utils/lyrics_parser.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/lyrics/lyrics_models.dart' as fm;

/// Where edited lyrics would be written in Mornye. FluentMusic cannot rewrite
/// a song's tags, so this only exists so the copied editor keeps compiling.
enum LyricsSaveTarget {
  /// Tags in the song's own LRC lyrics, or in its `.lrc` file.
  songFile,

  /// The `.mlrc` file next to the song.
  sidecar,
}

/// FluentMusic ships no tag writer, so no lyrics can be saved back.
class LyricsSaveUnsupported implements Exception {
  const LyricsSaveUnsupported();

  @override
  String toString() => 'These lyrics cannot be saved for this song';
}

/// One editor's original track, writable source and draft input.
@immutable
class PlayerLyricsEdit {
  const PlayerLyricsEdit._(
    this.item,
    this.source,
    this.rawLyrics, {
    required this.inLrcFile,
  });

  final MediaItem item;
  final String source;
  final String rawLyrics;
  final bool inLrcFile;
}

/// The playing track's file facts and lyrics for the copied player UI.
///
/// FluentMusic keeps no writable per-song source and writes tags through its
/// own pipeline, so the controller only reads: it resolves the offline file
/// when there is one and fetches lyrics with FluentMusic's own manager.
class PlayerMetadataController extends ChangeNotifier {
  MediaItem? _item;
  String? _filePath;
  Map<String, dynamic>? _metadata;
  ParsedLyrics _lyrics = ParsedLyrics.empty;
  String _rawLyrics = '';
  bool _loading = false;
  bool _searchingOnline = false;
  bool _onlineSearchMissed = false;
  bool _onlineLyricsSaveFailed = false;
  int _generation = 0;
  bool _disposed = false;

  /// FluentMusic never edits a song's own tags, so this stays null and the
  /// "write lyrics" affordance stays hidden.
  String? get source => null;

  MediaItem? get item => _item;

  /// The lyrics as stored, empty when none.
  String get rawLyrics => _rawLyrics;

  String? get filePath => _filePath;
  Map<String, dynamic>? get metadata => _metadata;
  ParsedLyrics get lyrics => _lyrics;
  bool get loading => _loading;
  bool get searchingOnline => _searchingOnline;
  bool get onlineSearchMissed => _onlineSearchMissed;
  bool get onlineLyricsSaveFailed => _onlineLyricsSaveFailed;

  bool get canSearchOnline =>
      (_item?.title.trim().isNotEmpty ?? false) &&
      (_item?.artist?.trim().isNotEmpty ?? false);

  ({String? writers, String? provider}) get credits {
    String? field(String key) {
      final value = _metadata?[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return (
      writers: _lyrics.writers ?? field('lyricist') ?? field('composer'),
      provider: _lyrics.provider ?? field('lyrics_provider'),
    );
  }

  String? get qualityLabel {
    final meta = _metadata;
    if (meta == null) return null;
    final parts = <String>[];
    final format = (meta['format'] ?? meta['audio_codec'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    if (format.isNotEmpty) parts.add(format);
    final bitDepth = readPositiveInt(meta['bit_depth']) ?? 0;
    if (bitDepth > 0) parts.add('$bitDepth-bit');
    final sampleRate = readPositiveInt(meta['sample_rate']) ?? 0;
    if (sampleRate > 0) {
      final khz = sampleRate / 1000;
      parts.add(
        '${khz.toStringAsFixed(khz == khz.roundToDouble() ? 0 : 1)} kHz',
      );
    }
    final bitrate = readPositiveInt(meta['bitrate']) ?? 0;
    if (bitDepth == 0 && bitrate > 0) parts.add('$bitrate kbps');
    return parts.isEmpty ? null : parts.join('  ·  ');
  }

  /// Reads the file facts and lyrics of [item], publishing each stage as it
  /// arrives. A late reply for an item the player has left is dropped.
  Future<void> load(MediaItem? item) async {
    if (_disposed) return;
    final generation = ++_generation;
    _item = item;
    _searchingOnline = false;
    _onlineSearchMissed = false;
    _onlineLyricsSaveFailed = false;

    if (item == null) {
      _filePath = null;
      _metadata = null;
      _lyrics = ParsedLyrics.empty;
      _rawLyrics = '';
      _loading = false;
      notifyListeners();
      return;
    }

    final ytid = item.extras?['ytid']?.toString();
    final offline = ytid != null && ytid.isNotEmpty
        ? getOfflineSongByYtid(ytid)
        : <String, dynamic>{};
    final audioPath = offline['audioPath']?.toString();
    _filePath = audioPath == null || audioPath.isEmpty ? null : audioPath;
    _metadata = Map.unmodifiable({
      if (item.duration != null) 'duration': item.duration!.inSeconds,
    });
    _lyrics = ParsedLyrics.empty;
    _rawLyrics = '';
    _loading = true;
    notifyListeners();

    fm.Lyrics? fetched;
    try {
      fetched = await _fetchLyrics(item);
    } catch (_) {
      fetched = null;
    }
    if (_disposed || generation != _generation) return;

    _loading = false;
    if (fetched == null || fetched.isEmpty) {
      _lyrics = ParsedLyrics.empty;
      _rawLyrics = '';
    } else {
      _lyrics = _toParsedLyrics(fetched);
      _rawLyrics = fetched.text;
    }
    notifyListeners();
  }

  /// File facts are read with the queue item, so there is nothing deferred.
  Future<void> ensureFileMetadata() async {}

  /// Fetches lyrics again for the playing item.
  Future<void> searchOnline() async {
    final item = _item;
    if (_disposed || item == null || _searchingOnline || !canSearchOnline) {
      return;
    }
    final generation = _generation;
    _searchingOnline = true;
    _onlineSearchMissed = false;
    _onlineLyricsSaveFailed = false;
    notifyListeners();

    fm.Lyrics? fetched;
    try {
      fetched = await _fetchLyrics(item);
    } catch (_) {
      fetched = null;
    }
    if (_disposed || generation != _generation) return;

    _searchingOnline = false;
    if (fetched == null || fetched.isEmpty) {
      _onlineSearchMissed = true;
    } else {
      _lyrics = _toParsedLyrics(fetched);
      _rawLyrics = fetched.text;
    }
    notifyListeners();
  }

  /// FluentMusic cannot write a song's tags, so no edit can begin.
  PlayerLyricsEdit? beginLyricsEdit() => null;

  bool isCurrentLyricsEdit(PlayerLyricsEdit edit) =>
      !_disposed && _item?.id == edit.item.id && source == edit.source;

  Future<void> saveEditedLyrics(
    String raw, {
    required PlayerLyricsEdit edit,
  }) async {
    if (_disposed) throw StateError('The lyrics editor is closed');
    throw const LyricsSaveUnsupported();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<fm.Lyrics?> _fetchLyrics(MediaItem item) => getSongLyricsResult(
    item.artist,
    item.title,
    duration: item.duration,
    videoId: item.extras?['ytid']?.toString(),
  );

  ParsedLyrics _toParsedLyrics(fm.Lyrics lyrics) {
    final provider = _providerText(lyrics);
    final synced = lyrics.synced;
    if (synced == null || synced.isEmpty) {
      return ParsedLyrics(
        synced: false,
        wordSynced: false,
        lines: const [],
        plainText: lyrics.text,
        provider: provider,
      );
    }
    return ParsedLyrics(
      synced: true,
      wordSynced: lyrics.hasWordSync,
      lines: [for (final line in synced) _toLyricLine(line)],
      plainText: lyrics.text,
      provider: provider,
    );
  }

  LyricLine _toLyricLine(fm.LyricLine line) => LyricLine(
    time: line.start,
    end: line.end,
    text: line.text,
    words: [
      for (final word in line.words)
        LyricWord(time: word.start, end: word.end, text: word.text),
    ],
  );

  /// The provider line without its "Lyrics from "/"Lyrics by " lead-in, which
  /// the player draws itself. The submitter credit is kept intact.
  static String? _providerText(fm.Lyrics lyrics) {
    final attribution = lyrics.attribution.trim();
    if (attribution.isEmpty) return null;
    for (final prefix in const ['Lyrics from ', 'Lyrics by ']) {
      if (attribution.startsWith(prefix)) {
        final remainder = attribution.substring(prefix.length).trim();
        return remainder.isEmpty ? null : remainder;
      }
    }
    return attribution;
  }
}
