/*
 *     Copyright (C) 2026 jaypakash sahu
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Divider, Theme;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:musify/screens/settings/settings_subpages.dart'
    show buildGlassBackButton, buildSubpageBackground;
import 'package:musify/services/updates/update_models.dart';
import 'package:musify/services/updates/update_service.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/url_launcher.dart';
import 'package:musify/widgets/updates/update_prompt.dart';

class UpdatesSettingsPage extends StatefulWidget {
  const UpdatesSettingsPage({super.key});

  @override
  State<UpdatesSettingsPage> createState() => _UpdatesSettingsPageState();
}

class _UpdatesSettingsPageState extends State<UpdatesSettingsPage> {
  bool _checking = false;
  bool _autoChecks = true;
  String _currentVersion = '—';
  DateTime? _lastChecked;

  @override
  void initState() {
    super.initState();
    _autoChecks = UpdateService.instance.autoChecksEnabled;
    _lastChecked = UpdateService.instance.lastCheckedAt;
    UpdateService.instance.currentVersion().then((version) {
      if (mounted) setState(() => _currentVersion = version);
    });
  }

  Future<void> _checkNow() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final result = await UpdateService.instance.checkForUpdates(force: true);
      if (!mounted) return;
      setState(() => _lastChecked = result.checkedAt);
      if (result.updateAvailable) {
        await UpdatePrompt.show(context, result);
      } else {
        showToast(context, 'You are on the latest version.');
      }
    } on UpdateCheckException catch (error) {
      if (mounted) showToast(context, error.message);
    } catch (error) {
      if (mounted) showToast(context, 'Update check failed. Try again later.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _toggleAutoChecks(bool value) async {
    setState(() => _autoChecks = value);
    await UpdateService.instance.setAutoChecksEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF636366);

    return GlassScaffold(
      extendBody: false,
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: Text(
          'Updates',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Image.asset(
              updateHeroAsset,
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.3),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'FluentMusic $_currentVersion',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _lastChecked == null
                ? 'Updates come directly from GitHub Releases.'
                : 'Last checked ${_relativeTime(_lastChecked!)}.',
            style: TextStyle(fontSize: 13, color: subtitleColor),
          ),
          const SizedBox(height: 20),
          _UpdateCard(
            children: [
              _UpdateRow(
                icon: CupertinoIcons.arrow_down_circle_fill,
                tint: const Color(0xFFFF2D55),
                title: 'Automatic checks',
                subtitle: 'Once a day, only when you are online',
                trailing: CupertinoSwitch(
                  value: _autoChecks,
                  activeTrackColor: const Color(0xFFFF2D55),
                  onChanged: _toggleAutoChecks,
                ),
              ),
              _divider(isDark),
              _UpdateRow(
                icon: CupertinoIcons.arrow_clockwise,
                tint: const Color(0xFF0A84FF),
                title: 'Check for updates',
                subtitle: 'Fetch the latest release from GitHub',
                onTap: _checking ? null : _checkNow,
                trailing: _checking
                    ? const CupertinoActivityIndicator(radius: 9)
                    : Icon(
                        CupertinoIcons.chevron_forward,
                        size: 15,
                        color: subtitleColor.withValues(alpha: 0.7),
                      ),
              ),
              _divider(isDark),
              _UpdateRow(
                icon: CupertinoIcons.tag_fill,
                tint: const Color(0xFFFF3B30),
                title: 'Current version',
                subtitle: 'Build ${_currentVersion}+19',
                trailing: Text(
                  'v$_currentVersion',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _UpdateCard(
            children: [
              _UpdateRow(
                icon: CupertinoIcons.square_arrow_up,
                tint: const Color(0xFF32D74B),
                title: 'All releases',
                subtitle: 'Notes, older versions and Windows builds',
                onTap: () => launchURL(Uri.parse(updateReleasesPage)),
                trailing: Icon(
                  CupertinoIcons.chevron_forward,
                  size: 15,
                  color: subtitleColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'FluentMusic checks the public GitHub Releases API. No account, '
            'device id or listening data is sent with an update check.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: subtitleColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} h ago';
    }
    return '${difference.inDays} d ago';
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 58,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C1E).withValues(alpha: 0.86)
            : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _UpdateRow extends StatelessWidget {
  const _UpdateRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF8E8E93);

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: subtitleColor),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );

    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}
