/*
 *     Copyright (C) 2026 Valeri Gokadze
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
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/screens/settings/settings_subpages.dart'
    show buildGlassBackButton, buildSubpageBackground;
import 'package:musify/services/youtube/stream_diagnostics.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

/// Shows what the streaming ladder actually did.
///
/// Every rung records its client, verdict, latency, whether a BotGuard token
/// was carried, and where the byte probe read from — so "it did not play" can
/// be read off a screen instead of guessed from a logcat.
class StreamDiagnosticsPage extends StatelessWidget {
  const StreamDiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF636366);

    return GlassScaffold(
      extendBody: false,
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: Text(
          'Stream Diagnostics',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
        actions: [
          GlassIconButton(
            size: 40,
            iconSize: 19,
            semanticLabel: 'Clear',
            icon: Icon(
              CupertinoIcons.trash,
              color: isDark ? Colors.white : Colors.black87,
              size: 19,
            ),
            onPressed: clearStreamDiagnostics,
          ),
        ],
      ),
      body: ValueListenableBuilder<List<StreamAttempt>>(
        valueListenable: streamDiagnostics,
        builder: (context, attempts, _) {
          if (attempts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.waveform_path_ecg,
                    size: 44,
                    color: subtitleColor,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No attempts yet',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Play a track and every client it asked will show up here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subtitleColor, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            itemCount: attempts.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == attempts.length) {
                return const MiniPlayerBottomSpace();
              }
              return _AttemptRow(
                attempt: attempts[index],
                isDark: isDark,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              );
            },
          );
        },
      ),
    );
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({
    required this.attempt,
    required this.isDark,
    required this.titleColor,
    required this.subtitleColor,
  });

  final StreamAttempt attempt;
  final bool isDark;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final accent = attempt.ok
        ? const Color(0xFF34C759)
        : const Color(0xFFFF453A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  attempt.client,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${attempt.latencyMs} ms',
                style: TextStyle(color: subtitleColor, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (attempt.usedTokens) 'PO token',
              if (attempt.probeBytes > 0)
                'probe @ ${(attempt.probeBytes / 1024).round()} KiB',
              if (!attempt.ok && attempt.reason != null) attempt.reason!,
            ].join(' · '),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: subtitleColor, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}