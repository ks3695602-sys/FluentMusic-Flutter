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

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/widgets/glass/glass_toast.dart';

/// The single like control used by the player.
///
/// One heart everywhere, one source of truth (`userLikedSongsList`), optimistic
/// state on tap and a short debounce so a double tap cannot write twice.
class SongLikeButton extends StatefulWidget {
  const SongLikeButton({
    super.key,
    required this.songId,
    required this.songData,
    this.iconSize = 24,
    this.minSize = 38,
    this.color = CupertinoColors.white,
    this.activeColor = const Color(0xFFFF2D55),
  });

  final String? songId;

  /// Stored when the song is liked, so a liked song is never an empty entry.
  final Map? songData;

  final double iconSize;
  final double minSize;
  final Color color;
  final Color activeColor;

  @override
  State<SongLikeButton> createState() => _SongLikeButtonState();
}

class _SongLikeButtonState extends State<SongLikeButton> {
  /// Set while a write is in flight so the heart reacts immediately.
  bool? _optimistic;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _storedLiked {
    final id = widget.songId;
    return id != null && id.isNotEmpty && isSongAlreadyLiked(id);
  }

  bool get _isLiked => _optimistic ?? _storedLiked;

  @override
  void initState() {
    super.initState();
    userLikedSongsList.addListener(_onLikedSongsChanged);
  }

  @override
  void didUpdateWidget(covariant SongLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) _optimistic = null;
  }

  @override
  void dispose() {
    userLikedSongsList.removeListener(_onLikedSongsChanged);
    super.dispose();
  }

  void _onLikedSongsChanged() {
    if (!mounted || _optimistic == null) return;
    setState(() => _optimistic = null);
  }

  Future<void> _toggle() async {
    final songId = widget.songId;
    if (songId == null || songId.isEmpty) return;

    final now = DateTime.now();
    if (now.difference(_lastTap).inMilliseconds < 450) return;
    _lastTap = now;

    HapticFeedback.lightImpact();
    final nextLiked = !_isLiked;
    setState(() => _optimistic = nextLiked);

    try {
      await updateSongLikeStatus(songId, nextLiked, songData: widget.songData);
      if (!mounted) return;
      setState(() => _optimistic = null);
      showGlassToast(
        context,
        nextLiked
            ? context.l10n!.addedToLikedSongs
            : context.l10n!.removedFromLikedSongs,
        icon: nextLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _optimistic = null);
      showGlassToast(
        context,
        context.l10n!.error,
        icon: CupertinoIcons.exclamationmark_circle,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: widget.minSize,
      onPressed: _toggle,
      child: Icon(
        _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
        color: _isLiked ? widget.activeColor : widget.color,
        size: widget.iconSize,
      ),
    );
  }
}
