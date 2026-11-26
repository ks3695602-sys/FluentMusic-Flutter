/*
 * Portions derived from BitChord (kushagrasinghx/BitChord), GPL-3.0.
 * https://github.com/kushagrasinghx/BitChord
 */

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/mornye_player/widgets/player_artwork.dart';
import 'package:musify/services/canvas/canvas_artwork.dart';
import 'package:musify/services/canvas/canvas_cache.dart';
import 'package:musify/services/canvas/canvas_repository.dart';
import 'package:video_player/video_player.dart';

/// Static artwork remains mounted until a canvas has rendered its first frame.
/// A decoder/network failure simply fades back to that still; it never becomes
/// a blank black rectangle.
class CanvasArtworkLayer extends StatefulWidget {
  const CanvasArtworkLayer({
    required this.item,
    required this.colorScheme,
    this.cacheWidth,
    super.key,
  });

  final MediaItem item;
  final ColorScheme colorScheme;
  final int? cacheWidth;

  @override
  State<CanvasArtworkLayer> createState() => _CanvasArtworkLayerState();
}

class _CanvasArtworkLayerState extends State<CanvasArtworkLayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _foreground = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolve();
  }

  @override
  void didUpdateWidget(covariant CanvasArtworkLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.title != widget.item.title ||
        oldWidget.item.artist != widget.item.artist) {
      _releaseController();
      _ready = false;
      _failed = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final request = ++_request;
    final cached = CanvasRepository.instance.cached(widget.item);
    final artwork =
        cached ?? await CanvasRepository.instance.canvasFor(widget.item);
    if (!mounted || request != _request || artwork == null) return;
    await _mount(artwork.url, request, artwork.fallbackUrl);
  }

  Future<void> _mount(String url, int request, [String? fallback]) async {
    VideoPlayerController? controller;
    try {
      final file = await CanvasCache.instance.fileFor(url);
      if (!mounted || request != _request) return;
      controller = file != null
          ? VideoPlayerController.file(file, videoPlayerOptions: _options)
          : VideoPlayerController.networkUrl(
              Uri.parse(url),
              videoPlayerOptions: _options,
            );
      unawaited(controller.setLooping(true));
      unawaited(controller.setVolume(0));
      await controller.initialize().timeout(const Duration(seconds: 8));
      if (!mounted || request != _request) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onVideoChanged);
      _controller = controller;
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (controller != null && !identical(controller, _controller)) {
        await controller.dispose();
      }
      if (!mounted || request != _request) return;
      if (fallback != null && fallback != url) {
        await _mount(fallback, request);
      } else {
        setState(() => _failed = true);
      }
    }
  }

  VideoPlayerOptions get _options => VideoPlayerOptions(mixWithOthers: true);

  void _onVideoChanged() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    if (controller.value.hasError) {
      _releaseController();
      setState(() {
        _ready = false;
        _failed = true;
      });
      return;
    }
    if (controller.value.isInitialized &&
        !_ready &&
        controller.value.position > Duration.zero) {
      setState(() => _ready = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    final controller = _controller;
    if (controller == null) return;
    if (_foreground) {
      unawaited(controller.play());
    } else {
      unawaited(controller.pause());
    }
  }

  void _releaseController() {
    final old = _controller;
    _controller = null;
    if (old != null) {
      old.removeListener(_onVideoChanged);
      unawaited(old.dispose());
    }
  }

  @override
  void dispose() {
    ++_request;
    WidgetsBinding.instance.removeObserver(this);
    _releaseController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final staticArt = PlayerArtwork(
      artUri: widget.item.artUri?.toString(),
      colorScheme: widget.colorScheme,
      cacheWidth: widget.cacheWidth,
    );
    if (_failed || controller == null || !controller.value.isInitialized) {
      return staticArt;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        staticArt,
        AnimatedOpacity(
          opacity: _ready && _foreground ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      ],
    );
  }
}
