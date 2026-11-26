import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/mornye_player/widgets/player_artwork.dart';
import 'package:musify/services/settings_manager.dart'
    show canvasEnabled, musicVideoEnabled;
import 'package:musify/services/video/music_video_controller.dart';
import 'package:musify/widgets/player/canvas_artwork_layer.dart';
import 'package:musify/widgets/player/music_video_surface.dart';

/// The still cover with the track's motion on top of it: a music video when
/// one is loading or playing, a looping canvas when the video has none, and
/// the plain artwork otherwise.
///
/// Only one motion decoder is ever mounted: while a music video is on its way
/// the canvas stays off, so a low-end phone isn't decoding two streams for one
/// song. A failed video falls back to the canvas instead of a black rectangle.
class PlayerMotionArtwork extends StatefulWidget {
  const PlayerMotionArtwork({
    required this.item,
    required this.colorScheme,
    required this.videoController,
    this.cacheWidth,
    super.key,
  });

  final MediaItem item;
  final ColorScheme colorScheme;
  final MusicVideoController videoController;
  final int? cacheWidth;

  @override
  State<PlayerMotionArtwork> createState() => _PlayerMotionArtworkState();
}

class _PlayerMotionArtworkState extends State<PlayerMotionArtwork> {
  @override
  void initState() {
    super.initState();
    widget.videoController.addListener(_onVideoChanged);
  }

  @override
  void didUpdateWidget(covariant PlayerMotionArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.videoController, widget.videoController)) {
      oldWidget.videoController.removeListener(_onVideoChanged);
      widget.videoController.addListener(_onVideoChanged);
    }
  }

  @override
  void dispose() {
    widget.videoController.removeListener(_onVideoChanged);
    super.dispose();
  }

  void _onVideoChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final staticArt = PlayerArtwork(
      artUri: widget.item.artUri?.toString(),
      colorScheme: widget.colorScheme,
      cacheWidth: widget.cacheWidth,
    );
    final videoSupported =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return ValueListenableBuilder<bool>(
      valueListenable: musicVideoEnabled,
      builder: (context, videoEnabled, _) {
        final videoWanted = videoEnabled && videoSupported;
        final status = widget.videoController.status;
        final videoInPlay =
            videoWanted &&
            (status == MusicVideoStatus.loading ||
                status == MusicVideoStatus.ready);
        if (videoInPlay) {
          return Stack(
            fit: StackFit.expand,
            children: [
              staticArt,
              MusicVideoSurface(controller: widget.videoController),
            ],
          );
        }
        return ValueListenableBuilder<bool>(
          valueListenable: canvasEnabled,
          builder: (context, canvasOn, _) {
            if (!canvasOn) return staticArt;
            return CanvasArtworkLayer(
              item: widget.item,
              colorScheme: widget.colorScheme,
              cacheWidth: widget.cacheWidth,
            );
          },
        );
      },
    );
  }
}
