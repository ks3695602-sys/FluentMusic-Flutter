import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/audio/audio_handler.dart';
import '../../core/audio/audio_models.dart';
import '../widgets/liquid_glass_container.dart';

class LibraryScreen extends StatefulWidget {
  final FluentAudioHandler audioHandler;

  const LibraryScreen({super.key, required this.audioHandler});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> _localSongs = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndScan();
  }

  Future<void> _checkPermissionAndScan() async {
    setState(() => _isLoading = true);

    bool permissionStatus = await _audioQuery.permissionsStatus();
    if (!permissionStatus) {
      permissionStatus = await _audioQuery.permissionsRequest();
    }

    if (!permissionStatus) {
      final status = await Permission.audio.request();
      permissionStatus = status.isGranted;
    }

    _hasPermission = permissionStatus;

    if (_hasPermission) {
      try {
        final songs = await _audioQuery.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );
        _localSongs = songs;
      } catch (e) {
        debugPrint('[LibraryScreen] Scan error: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        // Title & Scan Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Library',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              onPressed: _checkPermissionAndScan,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Quick Categories
        Row(
          children: [
            Expanded(
              child: LiquidGlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.all(14),
                tintColor: const Color(0xFFFA2D48).withOpacity(0.2),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.phone_android_rounded, color: Colors.white, size: 24),
                    SizedBox(height: 8),
                    Text(
                      'Local Music',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'On Device',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LiquidGlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.all(14),
                tintColor: Colors.white.withOpacity(0.08),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.favorite_rounded, color: Color(0xFFFA2D48), size: 24),
                    SizedBox(height: 8),
                    Text(
                      'Favorites',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Liked Songs',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Section Title
        Text(
          'Device Tracks (${_localSongs.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Color(0xFFFA2D48)),
            ),
          )
        else if (!_hasPermission)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Icon(Icons.lock_rounded, size: 48, color: Colors.white38),
                  const SizedBox(height: 12),
                  const Text(
                    'Storage Permission Required',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Grant permission to scan and play music from your device storage.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _checkPermissionAndScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA2D48),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Grant Permission'),
                  ),
                ],
              ),
            ),
          )
        else if (_localSongs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No local audio tracks found on this device.',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
          )
        else
          for (final song in _localSongs)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                nullArtworkWidget: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white54),
                ),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                song.artist ?? 'Unknown Artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.play_arrow_rounded, color: Colors.white70),
              onTap: () {
                final track = MediaTrack(
                  id: song.id.toString(),
                  title: song.title,
                  artist: song.artist ?? 'Unknown Artist',
                  album: song.album ?? '',
                  duration: Duration(milliseconds: song.duration ?? 0),
                  isLocal: true,
                  localFilePath: song.data,
                );
                widget.audioHandler.playTrack(track);
              },
            ),
      ],
    );
  }
}
