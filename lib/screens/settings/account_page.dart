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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/screens/settings/settings_subpages.dart';
import 'package:musify/services/account_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/sync_service.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

/// Optional account screen.
///
/// Four promises, visible in the UI:
/// 1. No feature is ever gated behind sign-in.
/// 2. A local profile works forever, offline.
/// 3. Cloud sync only touches playlists + the song library.
/// 4. Export/import works even with no account at all.
class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _obscure = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final session = accountService.session;
    _name.text = session?.name ?? '';
    _email.text = session?.email ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<AccountResult> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.success) _password.clear();
    });
    if (result.message.isNotEmpty) {
      showToast(
        context,
        result.message,
        icon: result.success
            ? CupertinoIcons.checkmark_circle_fill
            : CupertinoIcons.exclamationmark_circle,
      );
    }
  }

  Future<void> _runSync(Future<SyncResult> Function() action) async {
    await _run(() async {
      final result = await action();
      return AccountResult(result.success, result.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final session = accountService.session;

    return GlassScaffold(
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: Text(
          'Account',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: <Widget>[
          _buildHero(context, session),
          const SizedBox(height: 18),
          if (session == null) ..._buildSignedOut(isDark),
          if (session != null) ..._buildSignedIn(context, session, isDark),
          const SizedBox(height: 8),
          _buildPrivacyNote(context),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, AccountSession? session) {
    final initial = session?.initial ?? 'F';
    final title = session?.name.trim().isNotEmpty == true
        ? session!.name.trim()
        : session == null
            ? 'Your library, your rules'
            : 'Listener';
    final subtitle = session?.isLocal == true
        ? 'Local profile · private mode'
        : session?.email.isNotEmpty == true
            ? session!.email
            : 'No account needed · everything works offline';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF7C3AED), Color(0xFFDB2777)],
        ),
        border: Border.all(
          color: CupertinoColors.white.withValues(alpha: 0.20),
          width: 0.8,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoColors.white.withValues(alpha: 0.22),
              border: Border.all(
                color: CupertinoColors.white.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CupertinoColors.white.withValues(alpha: 0.78),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    session == null
                        ? 'OPTIONAL ACCOUNT'
                        : session.isLocal
                            ? 'LOCAL PROFILE'
                            : 'CLOUD SYNC',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSignedOut(bool isDark) {
    return <Widget>[
      _section(
        'STAY OPTIONAL',
        isDark,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'FluentMusic works fully without an account. Sign in only if '
              'you want your playlists and liked songs on another device.',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF636366),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _section(
        'LOCAL PROFILE',
        isDark,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: <Widget>[
                _buildField(
                  controller: _name,
                  placeholder: 'Display name',
                  icon: CupertinoIcons.person,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () => accountService.signInLocal(_name.text),
                            ),
                    child: _busy
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          )
                        : const Text(
                            'Continue locally',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      ..._buildAuthSection(isDark),
      const SizedBox(height: 18),
      Center(
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Skip for now',
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildAuthSection(bool isDark) {
    if (!CloudSyncConfig.isConfigured) {
      return <Widget>[
        _section(
          'CLOUD SYNC',
          isDark,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    CupertinoIcons.cloud_off,
                    size: 20,
                    color: isDark ? Colors.white54 : const Color(0xFF8E8E93),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cloud sync is not configured in this build. Export and '
                      'import still work, and no key is ever stored on device.',
                      style: TextStyle(
                        color:
                            isDark ? Colors.white70 : const Color(0xFF636366),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ];
    }

    return <Widget>[
      _section(
        'CLOUD ACCOUNT (OPTIONAL)',
        isDark,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: <Widget>[
                _buildField(
                  controller: _email,
                  placeholder: 'Email',
                  icon: CupertinoIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                _buildField(
                  controller: _password,
                  placeholder: 'Password',
                  icon: CupertinoIcons.lock,
                  obscure: _obscure,
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(36, 36),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure
                          ? CupertinoIcons.eye
                          : CupertinoIcons.eye_slash,
                      size: 18,
                      color: isDark ? Colors.white54 : const Color(0xFF8E8E93),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () => accountService.signIn(
                                email: _email.text,
                                password: _password.text,
                              ),
                            ),
                    child: _busy
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          )
                        : const Text(
                            'Sign in',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => accountService.signUp(
                              name: _name.text,
                              email: _email.text,
                              password: _password.text,
                            ),
                          ),
                  child: Text(
                    'New here? Create an account',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF5856D6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildSignedIn(
    BuildContext context,
    AccountSession session,
    bool isDark,
  ) {
    return <Widget>[
      _section(
        'SYNC',
        isDark,
        children: <Widget>[
          GlassListTile(
            leading: const Icon(
              CupertinoIcons.arrow_2_circlepath,
              color: Color(0xFF0A84FF),
            ),
            title: Text(
              'Sync now',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
              ),
            ),
            subtitle: Text(
              _lastSyncLabel(),
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
                fontSize: 12,
              ),
            ),
            trailing: GlassListTile.chevron,
            onTap: _busy ? null : () => _runSync(() => syncService.syncNow()),
          ),
          GlassListTile(
            leading: const Icon(
              CupertinoIcons.clock,
              color: Color(0xFF30D158),
            ),
            title: Text(
              'Auto-sync',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
              ),
            ),
            subtitle: Text(
              'Merge quietly when the app opens',
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
                fontSize: 12,
              ),
            ),
            trailing: CupertinoSwitch(
              value: syncService.autoSyncEnabled,
              onChanged: (value) async {
                await syncService.setAutoSyncEnabled(value);
                if (mounted) setState(() {});
              },
            ),
          ),
        ],
      ),
      if (session.isLocal) ...<Widget>[
        const SizedBox(height: 14),
        _section(
          'CLOUD SYNC',
          isDark,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                CloudSyncConfig.isConfigured
                    ? 'You are on a local profile. Sign in below to sync the '
                        'same library across devices.'
                    : 'This build has no cloud keys, so the local profile stays '
                        'local. Export a JSON backup to move devices.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF636366),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        if (CloudSyncConfig.isConfigured) ...<Widget>[
          const SizedBox(height: 14),
          ..._buildAuthSection(isDark),
        ],
      ],
      const SizedBox(height: 14),
      _buildBackupSection(context, isDark),
      const SizedBox(height: 14),
      _section(
        'SESSION',
        isDark,
        children: <Widget>[
          GlassListTile(
            leading: const Icon(
              CupertinoIcons.square_arrow_right,
              color: Color(0xFFFF453A),
            ),
            title: const Text(
              'Sign out',
              style: TextStyle(
                color: Color(0xFFFF453A),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Downloads and offline songs stay on this device',
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
                fontSize: 12,
              ),
            ),
            onTap: () async {
              await accountService.signOut();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    ];
  }

  Widget _buildBackupSection(BuildContext context, bool isDark) {
    return _section(
      'DATA & BACKUP',
      isDark,
      children: <Widget>[
        GlassListTile(
          leading: const Icon(
            CupertinoIcons.cloud_upload,
            color: Color(0xFF0A84FF),
          ),
          title: Text(
            'Export library JSON',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            ),
          ),
          subtitle: Text(
            'Portable snapshot · playlists + liked songs',
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
          trailing: GlassListTile.chevron,
          onTap: _busy ? null : () => _runSync(syncService.exportSnapshot),
        ),
        GlassListTile(
          leading: const Icon(
            CupertinoIcons.cloud_download,
            color: Color(0xFF30D158),
          ),
          title: Text(
            'Import library JSON',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            ),
          ),
          subtitle: Text(
            'Merge a snapshot from another device',
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
          trailing: GlassListTile.chevron,
          onTap: _busy ? null : () => _runSync(syncService.importSnapshot),
        ),
        GlassListTile(
          leading: const Icon(
            CupertinoIcons.arrow_clockwise,
            color: Color(0xFFFF9500),
          ),
          title: Text(
            'Full app backup',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            ),
          ),
          subtitle: Text(
            'Hive files for user data + settings',
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
          trailing: GlassListTile.chevron,
          onTap: _busy
              ? null
              : () async {
                  final result = await backupData(context);
                  if (!mounted) return;
                  showToast(
                    context,
                    result.message,
                    icon: result.success
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.exclamationmark_circle,
                  );
                },
        ),
        GlassListTile(
          leading: const Icon(
            CupertinoIcons.arrow_counterclockwise,
            color: Color(0xFFFF2D55),
          ),
          title: Text(
            'Restore full backup',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            ),
          ),
          subtitle: Text(
            'Restart the app afterwards',
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
          trailing: GlassListTile.chevron,
          onTap: _busy
              ? null
              : () async {
                  final result = await restoreData(context);
                  if (!mounted) return;
                  reloadSongLibraryStateFromStorage();
                  reloadPlaylistLibraryStateFromStorage();
                  accountService.restoreFromStorage();
                  showToast(
                    context,
                    result.message,
                    icon: result.success
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.exclamationmark_circle,
                  );
                  setState(() {});
                },
        ),
      ],
    );
  }

  Widget _buildPrivacyNote(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        'Only playlists and the song library are synced. Audio files, '
        'downloads and settings never leave this device.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white38
              : const Color(0xFF8E8E93),
          fontSize: 11.5,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _section(String title, bool isDark, {required List<Widget> children}) {
    return GlassGroupedSection(
      surfaceStyle: GlassSurfaceStyle.solid,
      header: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
      children: children,
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CupertinoTextField(
      controller: controller,
      obscureText: obscure,
      placeholder: placeholder,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
        fontSize: 15,
      ),
      placeholderStyle: TextStyle(
        color: isDark ? Colors.white38 : const Color(0xFF8E8E93),
        fontSize: 15,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      prefix: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? Colors.white54 : const Color(0xFF8E8E93),
        ),
      ),
      suffix: trailing,
    );
  }

  String _lastSyncLabel() {
    final last = syncService.lastSyncedAt;
    if (last == null) {
      return syncService.isPending
          ? 'Pending · will retry on next launch'
          : 'Not synced yet';
    }
    final local = last.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'Synced just now';
    if (diff.inHours < 1) return 'Synced ${diff.inMinutes} min ago';
    if (diff.inDays < 1) return 'Synced ${diff.inHours} h ago';
    return 'Synced ${diff.inDays} d ago';
  }
}
