import 'package:material_ui/material_ui.dart';
import 'package:musify/services/video/music_video_controller.dart';
import 'package:video_player/video_player.dart';

/// How a height is named on screen, as BitChord's switcher does: the marketing
/// name where there is one, the height otherwise.
String musicVideoQualityLabel(int height) {
  if (height >= 4320) return '8K';
  if (height >= 2160) return '4K';
  if (height >= 1440) return '2K';
  if (height >= 1080) return 'FullHD';
  if (height >= 720) return 'HD';
  return '${height}p';
}

/// The playing music video's picture, faded in over the still artwork the
/// caller keeps underneath. While nothing has rendered yet it draws nothing,
/// so the cover stays visible instead of a black rectangle.
///
/// A tap toggles playback; the quality chip opens the heights the video
/// offers, and the fullscreen button shows the picture on a black stage.
class MusicVideoSurface extends StatefulWidget {
  const MusicVideoSurface({
    required this.controller,
    this.fit = BoxFit.cover,
    this.showControls = true,
    this.fullscreen = false,
    super.key,
  });

  final MusicVideoController controller;
  final BoxFit fit;
  final bool showControls;

  /// The fullscreen stage draws its own loading and error states, since there
  /// is no still artwork underneath it to fall back to.
  final bool fullscreen;

  @override
  State<MusicVideoSurface> createState() => _MusicVideoSurfaceState();
}

class _MusicVideoSurfaceState extends State<MusicVideoSurface> {
  bool _coveredByFullscreen = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isReady) {
          if (!widget.fullscreen) return const SizedBox.shrink();
          return _VideoBackdrop(
            status: controller.status,
            error: controller.errorMessage,
          );
        }
        final video = controller.videoPlayerController!;
        final size = video.value.size;
        if (size.width <= 0 || size.height <= 0) {
          return widget.fullscreen
              ? const _VideoBackdrop(status: MusicVideoStatus.loading)
              : const SizedBox.shrink();
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // One decoder, one picture: while the fullscreen stage shows the
            // frames, the inline surface keeps the still cover instead of
            // mounting a second texture for the same controller.
            if (!_coveredByFullscreen)
              AnimatedOpacity(
                opacity: controller.isRendered ? 1 : 0,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                child: FittedBox(
                  fit: widget.fit,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: VideoPlayer(video),
                  ),
                ),
              ),
            if (widget.showControls && controller.isRendered) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45),
                        ],
                        stops: const [0, 0.28, 0.62, 1],
                      ),
                    ),
                  ),
                ),
              ),
              // Under the chip and the buttons: a tap on bare picture toggles
              // playback, while the controls keep their own taps.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: controller.togglePlayback,
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _QualityChip(controller: controller),
              ),
              if (!widget.fullscreen)
                Positioned(
                  right: 8,
                  top: 8,
                  child: _GlassIconButton(
                    tooltip: 'Fullscreen',
                    icon: Icons.fullscreen,
                    onPressed: _openFullscreen,
                  ),
                ),
              if (!controller.isPlaying)
                const Center(child: IgnorePointer(child: _PlayBadge())),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openFullscreen() async {
    setState(() => _coveredByFullscreen = true);
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MusicVideoFullscreen(controller: widget.controller),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
    if (mounted) setState(() => _coveredByFullscreen = false);
  }
}

/// The picture alone on a black stage, with the quality chip and the way out.
class MusicVideoFullscreen extends StatelessWidget {
  const MusicVideoFullscreen({required this.controller, super.key});

  final MusicVideoController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.aspect,
              child: MusicVideoSurface(
                controller: controller,
                fit: BoxFit.contain,
                fullscreen: true,
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _GlassIconButton(
                  tooltip: 'Exit fullscreen',
                  icon: Icons.fullscreen_exit,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  const _QualityChip({required this.controller});

  final MusicVideoController controller;

  @override
  Widget build(BuildContext context) {
    final quality = controller.quality;
    // Nothing to switch between until the renditions are known.
    if (quality.heights.length < 2) return const SizedBox.shrink();
    final selected =
        quality.held != null && quality.heights.contains(quality.held)
        ? quality.held
        : quality.activeHeight;
    final label = selected == null
        ? 'Auto'
        : quality.held == null
        ? 'Auto · ${musicVideoQualityLabel(selected)}'
        : musicVideoQualityLabel(selected);

    return GestureDetector(
      onTap: () => _showQualitySheet(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showQualitySheet(BuildContext context) async {
    final quality = controller.quality;
    final selected = quality.held;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Video quality',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _QualityRow(
              label: 'Auto',
              trailing: quality.activeHeight == null
                  ? null
                  : musicVideoQualityLabel(quality.activeHeight!),
              checked: selected == null,
              onTap: () {
                Navigator.of(context).pop();
                controller.setQuality(null);
              },
            ),
            for (final height in quality.heights)
              _QualityRow(
                label: musicVideoQualityLabel(height),
                trailing: '${height}p',
                checked: selected == height,
                onTap: () {
                  Navigator.of(context).pop();
                  controller.setQuality(height);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({
    required this.label,
    required this.checked,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final String? trailing;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(label, style: const TextStyle(color: Colors.white)),
      subtitle: trailing == null
          ? null
          : Text(
              trailing!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
      trailing: checked
          ? const Icon(Icons.check, color: Colors.white, size: 20)
          : null,
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(Icons.play_arrow, color: Colors.white, size: 36),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      color: Colors.white,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.32),
      ),
      icon: Icon(icon),
    );
  }
}

class _VideoBackdrop extends StatelessWidget {
  const _VideoBackdrop({required this.status, this.error});

  final MusicVideoStatus status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      MusicVideoStatus.unsupported => 'Music video is available on Android',
      MusicVideoStatus.unavailable => 'No music video for this track',
      MusicVideoStatus.error => 'Unable to load the music video',
      MusicVideoStatus.idle => 'No music video selected',
      MusicVideoStatus.loading => '',
      MusicVideoStatus.ready => '',
    };
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: status == MusicVideoStatus.loading
            ? const CircularProgressIndicator(color: Colors.white70)
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
      ),
    );
  }
}
