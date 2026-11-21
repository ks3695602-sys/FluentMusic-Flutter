import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/mornye_player/controllers/player_metadata_controller.dart';
import 'package:musify/mornye_player/l10n/l10n.dart';
import 'package:musify/mornye_player/providers/music_player_provider.dart';
import 'package:musify/mornye_player/theme/mornye_theme.dart';
import 'package:musify/mornye_player/utils/playback_seek_preview.dart';
import 'package:musify/mornye_player/widgets/app_icon.dart';
import 'package:musify/mornye_player/widgets/audio_output_button.dart';
import 'package:musify/mornye_player/widgets/mornye_player_background.dart';
import 'package:musify/mornye_player/widgets/mornye_player_layout.dart';
import 'package:musify/mornye_player/widgets/player_artwork.dart';
import 'package:musify/mornye_player/widgets/player_gesture_regions.dart';
import 'package:musify/mornye_player/widgets/player_lyrics_section.dart';
import 'package:musify/screens/artist_page.dart';

/// The full player, hosting Mornye's copied surface on FluentMusic's playback.
///
/// The layout, lyrics, queue, controls and gestures are Mornye's own widgets;
/// this screen only supplies the song, its lyrics/credits and the handful of
/// menu entries FluentMusic can answer.
class MornyePlayerScreen extends ConsumerStatefulWidget {
  const MornyePlayerScreen({super.key, this.initialPage = 0});

  /// 0 is the player, 1 the lyrics and 2 Up Next.
  final int initialPage;

  @override
  ConsumerState<MornyePlayerScreen> createState() => _MornyePlayerScreenState();
}

class _MornyePlayerScreenState extends ConsumerState<MornyePlayerScreen> {
  ProviderSubscription<AsyncValue<MediaItem?>>? _mediaItemSub;
  late final PlayerMetadataController _metadata = PlayerMetadataController();
  final _seekPreview = PlaybackSeekPreview();
  late int _page = widget.initialPage;

  final _artworkHeaderKey = GlobalKey();
  final _artworkControlsKey = GlobalKey();
  final _artworkVolumeKey = GlobalKey();
  final _expandedArtworkKey = GlobalKey();
  final _compactArtworkKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _mediaItemSub = ref.listenManual<AsyncValue<MediaItem?>>(
      currentMediaItemProvider,
      (previous, next) {
        if (previous?.value?.id != next.value?.id) _seekPreview.reset();
        unawaited(_metadata.load(next.value));
      },
    );
    // The provider may already hold the song before this screen mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_metadata.load(ref.read(currentMediaItemProvider).value));
    });
  }

  @override
  void dispose() {
    _mediaItemSub?.close();
    _metadata.dispose();
    _seekPreview.dispose();
    super.dispose();
  }

  void _setPage(int page) {
    if (page == _page) return;
    setState(() => _page = page);
  }

  void _minimize() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final mediaItem = ref.watch(currentMediaItemProvider).value;
    if (mediaItem == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final base = Theme.of(context);
    final colorScheme = base.colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: _mornyeEnvelope(base),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              MornyePlayerBackground(
                artUri: mediaItem.artUri,
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _dragHandle(context),
                    Expanded(
                      child: MornyePlayerLayout(
                        mediaItem: mediaItem,
                        metadata: _metadata,
                        seekPreview: _seekPreview,
                        colorScheme: colorScheme,
                        page: _page,
                        motionArtwork: PlayerArtwork(
                          artUri: mediaItem.artUri?.toString(),
                          colorScheme: colorScheme,
                        ),
                        insetArtwork: true,
                        artworkTopInset: topInset + 36,
                        artworkKeys: (
                          header: _artworkHeaderKey,
                          controls: _artworkControlsKey,
                          volume: _artworkVolumeKey,
                          expanded: _expandedArtworkKey,
                          compact: _compactArtworkKey,
                        ),
                        lyricsControlsHidden: false,
                        lyricsOptionsOpen: false,
                        lyricsBuilder: (showOptions) => PlayerLyricsSection(
                          metadata: _metadata,
                          seekPreview: _seekPreview,
                          colorScheme: colorScheme,
                          isActive: _page == 1,
                        ),
                        lyricsOptions: null,
                        onPageChanged: _setPage,
                        onTrackNavigation: _openArtist,
                      ),
                    ),
                    _footer(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mornye's slim toolbar: the grabber that closes the player.
  Widget _dragHandle(BuildContext context) => SizedBox(
    height: 36,
    child: Center(
      child: Semantics(
        button: true,
        label: context.l10n.nowPlayingMinimize,
        child: Tooltip(
          message: context.l10n.nowPlayingMinimize,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _minimize,
            child: SizedBox(
              width: 64,
              height: 36,
              child: Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// Lyrics, output and the queue, exactly as the Mornye player lays them out.
  Widget _footer(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: PlayerQueueSwipeRegion(
      onOpenQueue: () => _setPage(2),
      child: FractionallySizedBox(
        widthFactor: 0.72,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: _page == 1
                  ? context.l10n.nowPlayingTabPlayer
                  : context.l10n.nowPlayingTabLyrics,
              isSelected: _page == 1,
              color: Colors.white,
              style: IconButton.styleFrom(
                backgroundColor: _page == 1
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.transparent,
              ),
              icon: const AppIcon(CupertinoIcons.quote_bubble),
              onPressed: () => _setPage(_page == 1 ? 0 : 1),
            ),
            const AudioOutputButton(color: Colors.white),
            IconButton(
              tooltip: context.l10n.nowPlayingUpNext,
              color: Colors.white,
              isSelected: _page == 2,
              style: IconButton.styleFrom(
                backgroundColor: _page == 2
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.transparent,
              ),
              icon: const AppIcon(CupertinoIcons.list_bullet),
              onPressed: () => _setPage(_page == 2 ? 0 : 2),
            ),
          ],
        ),
      ),
    ),
  );

  /// Tapping the title opens the artist, the one catalogue page FluentMusic
  /// can resolve from a queue item.
  Future<void> _openArtist(BuildContext context, MediaItem item) async {
    final extras = item.extras;
    final artistId = extras?['artistId']?.toString().trim() ?? '';
    final artist = (item.artist ?? '').trim();
    final lookup = artistId.isNotEmpty ? artistId : artist;
    if (lookup.isEmpty) return;
    final sourceSongId = extras?['ytid']?.toString().trim() ?? '';
    final videoAuthor = extras?['videoAuthor']?.toString().trim() ?? '';
    final artistData = <String, dynamic>{
      'ytid': artistId.isNotEmpty ? artistId : lookup,
      if (artist.isNotEmpty) 'title': artist,
      if (sourceSongId.isNotEmpty) 'sourceSongId': sourceSongId,
      if (videoAuthor.isNotEmpty) 'videoAuthor': videoAuthor,
      'source': 'youtube-artist',
      'isArtist': true,
      'list': [],
    };
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArtistPage(artistId: lookup, artistData: artistData),
      ),
    );
  }
}

/// Keeps FluentMusic's colours and typography while marking the subtree as
/// Mornye's, so the copied widgets take their liquid-glass and spacing paths.
ThemeData _mornyeEnvelope(ThemeData base) => base.copyWith(
  extensions: [
    for (final extension in base.extensions.values)
      if (extension is! MornyeTheme) extension,
    const MornyeTheme(),
  ],
);