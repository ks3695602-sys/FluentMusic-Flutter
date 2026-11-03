class MediaTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String artUri;
  final Duration duration;
  final String? streamUrl;
  final bool isLocal;
  final String? localFilePath;

  const MediaTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.artUri = '',
    this.duration = Duration.zero,
    this.streamUrl,
    this.isLocal = false,
    this.localFilePath,
  });

  MediaTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? artUri,
    Duration? duration,
    String? streamUrl,
    bool? isLocal,
    String? localFilePath,
  }) {
    return MediaTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artUri: artUri ?? this.artUri,
      duration: duration ?? this.duration,
      streamUrl: streamUrl ?? this.streamUrl,
      isLocal: isLocal ?? this.isLocal,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'artUri': artUri,
    'durationMs': duration.inMilliseconds,
    'streamUrl': streamUrl,
    'isLocal': isLocal,
    'localFilePath': localFilePath,
  };

  factory MediaTrack.fromJson(Map<String, dynamic> json) => MediaTrack(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Unknown Title',
    artist: json['artist'] as String? ?? 'Unknown Artist',
    album: json['album'] as String? ?? '',
    artUri: json['artUri'] as String? ?? '',
    duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
    streamUrl: json['streamUrl'] as String?,
    isLocal: json['isLocal'] as bool? ?? false,
    localFilePath: json['localFilePath'] as String?,
  );
}
