/*
 *     Copyright (C) 2026 jaypakash sahu
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     FluentMusic is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     FluentMusic by jaypakash sahu
 *     https://github.com/ks3695602-sys/FluentMusic-Flutter
 */

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/widgets/playlist_artwork.dart';

/// Opens the glass "Add songs" sheet for a user-created playlist.
///
/// Resolves to the number of songs added during this session, so the caller can
/// refresh its local copy exactly once when the sheet closes.
Future<int> showAddSongsSheet(
  BuildContext context, {
  required String playlistId,
  required String playlistTitle,
  required Set<String> existingSongIds,
}) async {
  final added = await GlassModalSheet.show<int>(
    context: context,
    useRootNavigator: true,
    halfSize: 0.82,
    initialState: GlassSheetState.half,
    detents: const {GlassSheetDetent.medium, GlassSheetDetent.large},
    showDragIndicator: true,
    builder: (_) => AddSongsSheet(
      playlistId: playlistId,
      playlistTitle: playlistTitle,
      existingSongIds: existingSongIds,
    ),
  );
  return added ?? 0;
}

/// Search-and-add UI for custom playlists.
///
/// The sheet never nests glass: it lives inside the sheet's own glass surface
/// and deliberately uses flat rows so text stays crisp over the blur.
class AddSongsSheet extends StatefulWidget {
  const AddSongsSheet({
    super.key,
    required this.playlistId,
    required this.playlistTitle,
    required this.existingSongIds,
  });

  final String playlistId;
  final String playlistTitle;
  final Set<String> existingSongIds;

  @override
  State<AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends State<AddSongsSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  Timer? _debounce;
  int _requestId = 0;
  bool _loading = false;
  String _query = '';
  List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];
  late final Set<String> _knownIds = <String>{...widget.existingSongIds};
  final Set<String> _justAdded = <String>{};
  int _addedCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    final query = value.trim();
    _debounce?.cancel();
    if (query == _query) return;
    setState(() => _query = query);

    if (query.isEmpty) {
      _requestId++;
      setState(() {
        _results = <Map<String, dynamic>>[];
        _loading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 380), () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final raw = await fetchSongsList(query);
      if (!mounted || requestId != _requestId) return;
      final songs = raw
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .where((song) => (song['ytid']?.toString() ?? '').isNotEmpty)
          .toList();
      setState(() {
        _results = songs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = <Map<String, dynamic>>[];
        _loading = false;
      });
    }
  }

  void _addSong(Map<String, dynamic> song) {
    final id = song['ytid']?.toString() ?? '';
    if (id.isEmpty || _knownIds.contains(id)) return;

    final result = addSongInCustomPlaylist(context, widget.playlistId, song);
    if (!mounted) return;

    if (result == context.l10n!.songAdded ||
        result.toLowerCase().contains('added')) {
      HapticFeedback.selectionClick();
      setState(() {
        _knownIds.add(id);
        _justAdded.add(id);
        _addedCount++;
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF8E8E93);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: <Widget>[
          _buildHeader(context, titleColor, subtitleColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: CupertinoSearchTextField(
              controller: _searchController,
              focusNode: _searchFocus,
              placeholder: 'Search songs to add',
              style: TextStyle(color: titleColor, fontSize: 15),
              placeholderStyle: TextStyle(color: subtitleColor, fontSize: 15),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(13),
              onChanged: _onQueryChanged,
              onSubmitted: (value) {
                _debounce?.cancel();
                final query = value.trim();
                if (query.isNotEmpty) _search(query);
              },
            ),
          ),
          Expanded(child: _buildBody(titleColor, subtitleColor)),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color titleColor,
    Color subtitleColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Add songs',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.playlistTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            onPressed: () => Navigator.of(context).pop(_addedCount),
            child: Text(
              _addedCount > 0 ? 'Done · $_addedCount' : 'Done',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Color titleColor, Color subtitleColor) {
    if (_query.isEmpty) {
      return _buildHint(
        icon: CupertinoIcons.search,
        title: 'Find something new',
        subtitle:
            'Search YouTube Music and tap + to drop songs straight into '
            '“${widget.playlistTitle}”.',
        titleColor: titleColor,
        subtitleColor: subtitleColor,
      );
    }

    if (_loading && _results.isEmpty) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 13),
      );
    }

    if (_results.isEmpty) {
      return _buildHint(
        icon: CupertinoIcons.music_note,
        title: 'No songs found',
        subtitle: 'Try a different spelling, artist name or album.',
        titleColor: titleColor,
        subtitleColor: subtitleColor,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final song = _results[index];
        final id = song['ytid']?.toString() ?? '';
        final alreadyThere = _knownIds.contains(id);
        final title = song['title']?.toString() ?? 'Unknown song';
        final artist = song['artist']?.toString() ?? '';
        final image =
            song['highResImage'] ?? song['image'] ?? song['lowResImage'];

        return _SongRow(
          title: title,
          artist: artist,
          imageUrl: image?.toString(),
          added: alreadyThere,
          justAdded: _justAdded.contains(id),
          titleColor: titleColor,
          subtitleColor: subtitleColor,
          onTap: alreadyThere ? null : () => _addSong(song),
        );
      },
    );
  }

  Widget _buildHint({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 46, color: subtitleColor.withValues(alpha: 0.8)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: titleColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({
    required this.title,
    required this.artist,
    required this.imageUrl,
    required this.added,
    required this.justAdded,
    required this.titleColor,
    required this.subtitleColor,
    this.onTap,
  });

  final String title;
  final String artist;
  final String? imageUrl;
  final bool added;
  final bool justAdded;
  final Color titleColor;
  final Color subtitleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowColor = justAdded
        ? const Color(0xFF30D158).withValues(alpha: isDark ? 0.16 : 0.12)
        : isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.035);

    return Container(
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: PlaylistArtwork(
                  playlistArtwork: imageUrl,
                  playlistTitle: title,
                  size: 46,
                  cubeIcon: CupertinoIcons.music_note,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (artist.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: added
                      ? const Color(0xFF30D158).withValues(alpha: 0.18)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.06)),
                  border: Border.all(
                    color: added
                        ? const Color(0xFF30D158).withValues(alpha: 0.5)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.16)
                              : Colors.black.withValues(alpha: 0.10)),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  added
                      ? CupertinoIcons.checkmark_alt
                      : CupertinoIcons.plus,
                  size: 16,
                  color: added ? const Color(0xFF30D158) : titleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
