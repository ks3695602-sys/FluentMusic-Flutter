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
 */

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/screens/settings/ytmusic_login_page.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/ytmusic_auth_service.dart';
import 'package:musify/widgets/glass/glass_toast.dart';

/// Self-contained YouTube Music account card for the Account page.
///
/// Shows the connected profile, offers sign-in with a short scope explanation,
/// and surfaces an expired session instead of silently pretending to be online.
class YtMusicAccountCard extends StatelessWidget {
  const YtMusicAccountCard({super.key});

  Future<void> _openLogin(BuildContext context) async {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => GlassModalSheet(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Connect YouTube Music',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign-in happens on Google’s own page. FluentMusic only reads '
                  'the YouTube cookies needed to show your profile, likes and '
                  'playlists. Your password is never stored, and playback keeps '
                  'working exactly as before.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: CupertinoColors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 18),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFFFF2D55),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    final connected = await Navigator.of(context).push<bool>(
                      CupertinoPageRoute(
                        builder: (_) => const YtMusicLoginPage(),
                      ),
                    );
                    if (connected == true && context.mounted) {
                      showGlassToast(
                        context,
                        'YouTube Music connected',
                        icon: CupertinoIcons.checkmark_seal_fill,
                      );
                    }
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(
                    'Not now',
                    style: TextStyle(
                      color: CupertinoColors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    await GlassDialog.show(
      context: context,
      title: 'Sign out of YouTube Music?',
      message:
          'Your local library, downloads and likes stay on this device. '
          'Anonymous playback continues as usual.',
      actions: [
        GlassDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassDialogAction(
          label: 'Sign out',
          isDestructive: true,
          onPressed: () async {
            Navigator.of(context).pop();
            await ytMusicAuthService.signOut();
            if (!context.mounted) return;
            showGlassToast(
              context,
              'Signed out of YouTube Music',
              icon: CupertinoIcons.person_crop_circle,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ytMusicAuthService,
      builder: (context, _) {
        return GlassGroupedSection(
          surfaceStyle: GlassSurfaceStyle.solid,
          header: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'YOUTUBE MUSIC',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white60
                    : const Color(0xFF8E8E93),
              ),
            ),
          ),
          children: _buildChildren(context),
        );
      },
    );
  }

  List<Widget> _buildChildren(BuildContext context) {
    final status = ytMusicAuthService.status;
    final profile = ytMusicAuthService.profile;

    if (status == YtMusicAuthStatus.connecting) {
      return const [
        GlassListTile(
          leading: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          title: Text('Connecting to YouTube Music…'),
          subtitle: Text('Checking the Google session'),
        ),
      ];
    }

    if (status == YtMusicAuthStatus.connected && profile != null) {
      return [
        GlassListTile(
          leading: _Avatar(profile: profile),
          title: Text(
            profile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              if (profile.email != null && profile.email!.isNotEmpty)
                profile.email!,
              if (profile.channelHandle != null &&
                  profile.channelHandle!.isNotEmpty)
                profile.channelHandle!,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => _confirmSignOut(context),
            child: const Text(
              'Sign out',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF453A),
              ),
            ),
          ),
        ),
        const GlassMenuDivider(),
        ValueListenableBuilder<bool>(
          valueListenable: ytMusicSignedInPlayback,
          builder: (context, enabled, _) {
            return GlassListTile(
              leading: const Icon(
                CupertinoIcons.bolt_circle_fill,
                color: Color(0xFFFF9F0A),
              ),
              title: const Text('Use Account for Playback'),
              subtitle: const Text(
                'Experimental. YouTube may refuse signed-in audio; playback '
                'then falls back to the anonymous stream automatically.',
                style: TextStyle(fontSize: 12, height: 1.3),
              ),
              trailing: GlassSwitch(
                value: enabled,
                onChanged: (value) {
                  ytMusicSignedInPlayback.value = value;
                  addOrUpdateData(
                    'settings',
                    'ytMusicSignedInPlayback',
                    value,
                  );
                },
              ),
            );
          },
        ),
      ];
    }

    if (status == YtMusicAuthStatus.expired) {
      return [
        GlassListTile(
          leading: const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Color(0xFFFF9F0A),
          ),
          title: const Text('Reconnect YouTube Music'),
          subtitle: Text(
            ytMusicAuthService.lastError ??
                'The saved session expired. Sign in again to keep your profile.',
          ),
          trailing: GlassListTile.chevron,
          onTap: () => _openLogin(context),
        ),
      ];
    }

    final hasError = status == YtMusicAuthStatus.error;
    return [
      GlassListTile(
        leading: const Icon(
          CupertinoIcons.play_circle_fill,
          color: Color(0xFFFF2D55),
        ),
        title: Text(
          hasError ? 'Retry YouTube Music' : 'Connect YouTube Music',
        ),
        subtitle: Text(
          hasError
              ? (ytMusicAuthService.lastError ??
                    'Could not reach YouTube Music. Try again.')
              : 'Profile, likes and playlists stay in sync',
        ),
        trailing: GlassListTile.chevron,
        onTap: () => _openLogin(context),
      ),
    ];
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final YtMusicProfile profile;

  @override
  Widget build(BuildContext context) {
    final trimmed = profile.name.trim();
    final initial = trimmed.isEmpty
        ? 'Y'
        : trimmed.substring(0, 1).toUpperCase();

    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF2D55), Color(0xFF7C3AED)],
        ),
      ),
      alignment: Alignment.center,
      child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            )
          : Image.network(
              profile.avatarUrl!,
              fit: BoxFit.cover,
              width: 42,
              height: 42,
              errorBuilder: (_, __, ___) => Text(
                initial,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }
}
