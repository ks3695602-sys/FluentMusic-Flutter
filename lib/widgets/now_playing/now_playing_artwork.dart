/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/lyrics/lyrics_models.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/player_style.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/widgets/flip_card.dart';
import 'package:musify/widgets/now_playing/synced_lyrics_view.dart';
import 'package:musify/widgets/song_artwork.dart';

class NowPlayingArtwork extends StatelessWidget {
  const NowPlayingArtwork({
    super.key,
    required this.size,
    required this.metadata,
    required this.lyricsController,
    required this.playerStyle,
  });
  final Size size;
  final MediaItem metadata;
  final FlipCardController lyricsController;
  final PlayerStyle playerStyle;

  @override
  Widget build(BuildContext context) {
    final screenWidth = size.width;
    final screenHeight = size.height;
    final isLandscape = screenWidth > screenHeight;
    final isDesktop = screenWidth > 800;
    final imageSize = isDesktop
        ? screenHeight * 0.38
        : isLandscape
        ? screenHeight * 0.45
        : screenWidth < 360
        ? screenWidth * 0.75
        : screenWidth < 600
        ? (screenWidth * 0.84).clamp(300.0, 340.0).toDouble()
        : screenWidth * 0.65;

    const borderRadius = 28.0;
    final isVinyl = playerStyle == PlayerStyle.vinyl;
    final artworkRadius = isVinyl ? imageSize / 2 : borderRadius;

    return FlipCard(
      rotateSide: RotateSide.right,
      onTapFlipping:
          !offlineMode.value && !(metadata.extras?['isLive'] ?? false),
      controller: lyricsController,
      frontWidget: _ArtworkHero(
        borderRadius: artworkRadius,
        child: isVinyl
            ? Stack(
                children: [
                  _VinylRecord(size: imageSize, metadata: metadata),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: _AudioQualityBadge(metadata: metadata),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: SongArtworkWidget(
                      metadata: metadata,
                      size: imageSize,
                      errorWidgetIconSize: size.width / 8,
                      borderRadius: borderRadius,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: _AudioQualityBadge(metadata: metadata),
                  ),
                ],
              ),
      ),
      backWidget: GlassContainer.card(
        surfaceStyle: GlassSurfaceStyle.solid,
        child: SizedBox(
          width: imageSize,
          height: imageSize,
          child: LyricsViewWidget(metadata: metadata),
        ),
      ),
    );
  }
}

/// Artwork presented as the label of a vinyl record.
///
/// The disc itself is painted with a radial gradient and concentric grooves,
/// with the song artwork in the centre label. It is deliberately static: the
/// Now Playing screen already owns enough animation, and a static record keeps
/// the stage free of per-frame repaints.
class _VinylRecord extends StatelessWidget {
  const _VinylRecord({required this.size, required this.metadata});

  final double size;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final labelSize = size * 0.42;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Color(0xFF1D1D20),
              Color(0xFF0C0C0D),
              Color(0xFF000000),
            ],
            stops: [0.0, 0.68, 1.0],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: const _VinylGroovePainter()),
            ),
            ClipOval(
              child: SizedBox(
                width: labelSize,
                height: labelSize,
                child: SongArtworkWidget(
                  metadata: metadata,
                  size: labelSize,
                  borderRadius: labelSize / 2,
                ),
              ),
            ),
            // Spindle hole.
            Container(
              width: size * 0.036,
              height: size * 0.036,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF050505),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.24),
                  width: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VinylGroovePainter extends CustomPainter {
  const _VinylGroovePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    final minRadius = maxRadius * 0.46;
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var radius = minRadius; radius < maxRadius; radius += maxRadius * 0.018) {
      final t = (radius - minRadius) / (maxRadius - minRadius);
      groove.color = Colors.white.withValues(alpha: 0.025 + (t * 0.07));
      canvas.drawCircle(center, radius, groove);
    }

    // A single soft sheen band reads as light catching the vinyl without
    // forcing a blur pass.
    final sheen = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, maxRadius, sheen);
  }

  @override
  bool shouldRepaint(covariant _VinylGroovePainter oldDelegate) => false;
}

/// Shared transition + entrance motion for the player artwork.
///
/// The mini player already exposes a `now_playing_artwork` hero, so opening the
/// player grows the same picture instead of cross-fading two different frames.
/// A short scale/fade entrance keeps the hero flight feeling continuous on
/// routes where no source hero exists (deep links, queue taps).
class _ArtworkHero extends StatefulWidget {
  const _ArtworkHero({required this.child, required this.borderRadius});

  final Widget child;
  final double borderRadius;

  @override
  State<_ArtworkHero> createState() => _ArtworkHeroState();
}

class _ArtworkHeroState extends State<_ArtworkHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.isDismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _shell(BuildContext context, Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.40),
            blurRadius: 36,
            offset: const Offset(0, 16),
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = Hero(
      tag: 'now_playing_artwork',
      transitionOnUserGestures: true,
      // Keep the artwork corners rounded for the whole flight, otherwise the
      // hero snaps from a square image into a rounded one mid-animation.
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            direction,
            fromHeroContext,
            toHeroContext,
          ) {
            final fromChild = (fromHeroContext.widget as Hero).child;
            final toChild = (toHeroContext.widget as Hero).child;
            return AnimatedBuilder(
              animation: animation,
              child: direction == HeroFlightDirection.push
                  ? toChild
                  : fromChild,
              builder: (context, shuttleChild) {
                final radius =
                    widget.borderRadius * (animation.value.clamp(0.0, 1.0));
                return ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: shuttleChild,
                );
              },
            );
          },
      child: _shell(context, RepaintBoundary(child: widget.child)),
    );

    return AnimatedBuilder(
      animation: _curve,
      child: child,
      builder: (context, animatedChild) {
        final t = _curve.value;
        // Drop the opacity/transform wrappers once the entrance settles. At
        // rest they would otherwise keep a transformed layer alive for the
        // whole session.
        if (t >= 1.0) return animatedChild!;
        return Opacity(
          opacity: t,
          child: Transform.scale(
            // Slight overshoot-free settle, reads as a gentle dolly-in.
            scale: 0.94 + (0.06 * t),
            child: animatedChild,
          ),
        );
      },
    );
  }
}

/// Fetches and caches lyrics lazily per song.
class LyricsViewWidget extends StatefulWidget {
  const LyricsViewWidget({
    super.key,
    required this.metadata,
    this.showProvider = false,
  });
  final MediaItem metadata;
  final bool showProvider;

  @override
  State<LyricsViewWidget> createState() => _LyricsViewWidgetState();
}

class _LyricsViewWidgetState extends State<LyricsViewWidget> {
  String? _resolvedKey;
  late Future<Lyrics?> _lyricsFuture;

  @override
  void initState() {
    super.initState();
    _resolveIfNeeded();
  }

  @override
  void didUpdateWidget(LyricsViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveIfNeeded();
  }

  void _resolveIfNeeded() {
    final key = '${widget.metadata.artist} - ${widget.metadata.title}';
    if (key == _resolvedKey) return;
    _resolvedKey = key;
    _lyricsFuture = getSongLyricsResult(
      widget.metadata.artist,
      widget.metadata.title,
      duration: widget.metadata.duration,
      album: widget.metadata.album,
      videoId: widget.metadata.extras?['ytid']?.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget unavailable() => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.text_quote_24_regular,
            size: 48,
            color: colorScheme.onSecondaryContainer.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n!.lyricsNotAvailable,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSecondaryContainer,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    return AsyncLoader<Lyrics?>(
      future: _lyricsFuture,
      emptyWidget: unavailable(),
      errorBuilder: (ctx, error, stack) => unavailable(),
      builder: (context, lyrics) {
        if (lyrics == null || lyrics.isEmpty) return unavailable();

        // Re-evaluated when the setting changes, so toggling it takes effect
        // without reloading the lyrics.
        return ValueListenableBuilder<bool>(
          valueListenable: syncedLyricsEnabled,
          builder: (context, syncedEnabled, _) {
            if (lyrics.isSynced && syncedEnabled) {
              return SyncedLyricsView(
                lyrics: lyrics,
                showProvider: widget.showProvider,
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              child: Text(
                formatPlainLyrics(lyrics),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSecondaryContainer,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        );
      },
    );
  }
}

typedef _AudioQualityInfo = ({int bitrateKbps, String codec});

String _normalizeCodec(String codec) => switch (codec) {
  final c when c.startsWith('opus') => 'Opus',
  final c when c.startsWith('mp4a') => 'AAC',
  final c => c,
};

/// Resolves a song's stored or playback audio quality, or null if unavailable.
Future<_AudioQualityInfo?> _resolveAudioQuality(String ytid) async {
  final offlineSong = getOfflineSongByYtid(ytid);
  final offlineBitrate = offlineSong['audioBitrateKbps'] as int?;
  final offlineCodec = offlineSong['audioCodec'] as String?;
  if (offlineBitrate != null && offlineCodec != null) {
    return (bitrateKbps: offlineBitrate, codec: _normalizeCodec(offlineCodec));
  }
  if (offlineSong.isNotEmpty || offlineMode.value) return null;

  // Free for a song that is playing: the stream it picked is already resolved
  // and cached, so this reads it back instead of asking YouTube again.
  final stream = await fetchBestAudioStream(ytid);
  if (stream == null) return null;

  return (
    bitrateKbps: stream.bitrate.kiloBitsPerSecond.round(),
    codec: _normalizeCodec(stream.audioCodec),
  );
}

/// Shows the current song's resolved audio bitrate and codec.
class _AudioQualityBadge extends StatefulWidget {
  const _AudioQualityBadge({required this.metadata});
  final MediaItem metadata;

  @override
  State<_AudioQualityBadge> createState() => _AudioQualityBadgeState();
}

class _AudioQualityBadgeState extends State<_AudioQualityBadge> {
  String? _resolvedYtid;
  Future<_AudioQualityInfo?>? _infoFuture;

  @override
  void initState() {
    super.initState();
    _resolveIfNeeded();
  }

  @override
  void didUpdateWidget(_AudioQualityBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveIfNeeded();
  }

  void _resolveIfNeeded() {
    final ytid = widget.metadata.extras?['ytid']?.toString();
    if (ytid == _resolvedYtid) return;
    _resolvedYtid = ytid;

    final shouldResolve =
        showAudioQualityBadge.value && ytid != null && ytid.isNotEmpty;
    _infoFuture = shouldResolve ? _resolveAudioQuality(ytid) : null;
  }

  @override
  Widget build(BuildContext context) {
    final infoFuture = _infoFuture;
    if (infoFuture == null) return const SizedBox.shrink();

    return FutureBuilder<_AudioQualityInfo?>(
      future: infoFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${info.bitrateKbps} kbps • ${info.codec}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}
