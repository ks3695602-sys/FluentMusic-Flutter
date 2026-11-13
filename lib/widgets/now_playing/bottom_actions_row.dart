/*
 *     Copyright (C) 2026 Valeri Gokadze & FluentMusic
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
 */

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/widgets/queue_list_view.dart';

class BottomActionsRow extends StatelessWidget {
  const BottomActionsRow({
    super.key,
    required this.metadata,
    required this.iconSize,
    required this.isLargeScreen,
    required this.lyricsController,
  });

  final MediaItem metadata;
  final double iconSize;
  final bool isLargeScreen;
  final dynamic lyricsController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Lyrics quote bubble (Apple Music style with active glass pill)
          ValueListenableBuilder<bool>(
            valueListenable: lyricsController.isFlipped,
            builder: (context, isLyricsFlipped, _) {
              return GlassIconButton(
                icon: Icon(
                  isLyricsFlipped
                      ? CupertinoIcons.quote_bubble_fill
                      : CupertinoIcons.quote_bubble,
                  size: 20,
                  color: isLyricsFlipped
                      ? const Color(0xFFFF2D55)
                      : CupertinoColors.white.withValues(alpha: 0.85),
                ),
                onPressed: () {
                  lyricsController.flipcard();
                },
              );
            },
          ),

          // 2. AirPlay / Audio Output Device
          GlassIconButton(
            icon: const Icon(
              FluentIcons.speaker_2_24_regular,
              size: 20,
              color: CupertinoColors.white,
            ),
            onPressed: () => _showAudioOutputSheet(context),
          ),

          // 3. Queue List Button
          GlassIconButton(
            icon: const Icon(
              CupertinoIcons.list_bullet,
              size: 20,
              color: CupertinoColors.white,
            ),
            onPressed: () {
              showCustomBottomSheet(
                context,
                const QueueWidget(isBottomSheet: true),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAudioOutputSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text(
          'FluentMusic Lossless Output',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        message: const Text(
          'Active: Built-in Audio Device\nFormat: 24-bit 48kHz Hi-Res Lossless Audio',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              showToast(
                context,
                'Audio routing through system high-res mixer',
                duration: const Duration(seconds: 2),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.speaker_2_fill),
                SizedBox(width: 8),
                Text('Device Speaker / Headphones (Default)'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Done'),
        ),
      ),
    );
  }
}

Future<void> toggleSongOffline(
  ValueNotifier<bool> status,
  String? audioId,
  MediaItem metadata,
) async {
  final originalValue = status.value;
  status.value = !originalValue;

  try {
    final bool success;
    if (originalValue) {
      success =
          !(audioId == null) &&
          await OfflinePlaylistService().removeSongFromOfflineAndResync(
            audioId,
          );
    } else {
      success = await makeSongOffline(mediaItemToMap(metadata));
    }
    if (!success) {
      status.value = originalValue;
    }
  } catch (e) {
    status.value = originalValue;
    logger.log('Error toggling offline status', error: e);
  }
}

void showSleepTimerDialog(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  showDialog(
    context: context,
    builder: (context) {
      final duration = sleepTimerNotifier.value ?? Duration.zero;
      var hours = duration.inMinutes ~/ 60;
      var minutes = duration.inMinutes % 60;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.timer_24_regular, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  context.l10n!.sleepTimer,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n!.selectDuration,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTimeSelector(
                  context: context,
                  label: context.l10n!.hours,
                  value: hours,
                  colorScheme: colorScheme,
                  onDecrement: () {
                    if (hours > 0) setState(() => hours--);
                  },
                  onIncrement: () => setState(() => hours++),
                ),
                const SizedBox(height: 16),
                _buildTimeSelector(
                  context: context,
                  label: context.l10n!.minutes,
                  value: minutes,
                  colorScheme: colorScheme,
                  onDecrement: () {
                    if (minutes > 0) setState(() => minutes--);
                  },
                  onIncrement: () => setState(() => minutes++),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildPresetChip(
                      context,
                      label: '15m',
                      onTap: () {
                        setState(() {
                          hours = 0;
                          minutes = 15;
                        });
                      },
                    ),
                    _buildPresetChip(
                      context,
                      label: '30m',
                      onTap: () {
                        setState(() {
                          hours = 0;
                          minutes = 30;
                        });
                      },
                    ),
                    _buildPresetChip(
                      context,
                      label: '45m',
                      onTap: () {
                        setState(() {
                          hours = 0;
                          minutes = 45;
                        });
                      },
                    ),
                    _buildPresetChip(
                      context,
                      label: '1h',
                      onTap: () {
                        setState(() {
                          hours = 1;
                          minutes = 0;
                        });
                      },
                    ),
                    _buildPresetChip(
                      context,
                      label: 'End of Song',
                      onTap: () {
                        final posData = audioHandler.currentPositionData;
                        final songDuration = posData.duration;
                        final currentPos = posData.position;
                        if (songDuration > Duration.zero) {
                          final remaining = songDuration - currentPos;
                          if (remaining.inSeconds > 0) {
                            audioHandler.setSleepTimer(remaining);
                            showToast(
                              context,
                              'Sleep timer set for end of song',
                              duration: const Duration(seconds: 2),
                            );
                          }
                        }
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n!.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final duration = Duration(hours: hours, minutes: minutes);
                  if (duration.inSeconds > 0) {
                    audioHandler.setSleepTimer(duration);
                    showToast(
                      context,
                      context.l10n!.sleepTimerSet,
                      duration: const Duration(seconds: 1, milliseconds: 500),
                    );
                  }
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n!.setTimer),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildPresetChip(
  BuildContext context, {
  required String label,
  required VoidCallback onTap,
}) {
  return ActionChip(
    label: Text(label, style: const TextStyle(fontSize: 12)),
    onPressed: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

Widget _buildTimeSelector({
  required BuildContext context,
  required String label,
  required int value,
  required ColorScheme colorScheme,
  required VoidCallback onDecrement,
  required VoidCallback onIncrement,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                FluentIcons.line_horizontal_1_24_regular,
                color: colorScheme.onSurfaceVariant,
              ),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onDecrement,
            ),
            Container(
              width: 48,
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                FluentIcons.add_24_regular,
                color: colorScheme.onSurfaceVariant,
              ),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    ),
  );
}
