/*
 *     Copyright (C) 2026 jaypakash sahu
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:musify/services/updates/update_models.dart';
import 'package:musify/services/updates/update_service.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/url_launcher.dart';

/// The single update prompt used by both the automatic and manual checks.
/// It is built on [GlassDialog] so it inherits the active glass theme, and it
/// shows the FluentMusic update artwork instead of a generic icon.
class UpdatePrompt {
  UpdatePrompt._();

  static bool _visible = false;

  static Future<void> show(
    BuildContext context,
    UpdateCheckResult result,
  ) async {
    if (_visible || !result.updateAvailable) return;
    _visible = true;
    await UpdateService.instance.markPrompted(result.release.version);

    final action = await GlassDialog.show<String>(
      context: context,
      title: 'Update available',
      message:
          'FluentMusic ${result.release.version} is ready. You are on ${result.currentVersion}.',
      maxWidth: 400,
      barrierDismissible: true,
      content: _UpdateDialogContent(result: result),
      actions: [
        GlassDialogAction(
          label: 'Later',
          onPressed: () => Navigator.of(context).pop('later'),
        ),
        GlassDialogAction(
          label: 'Skip',
          onPressed: () => Navigator.of(context).pop('skip'),
        ),
        GlassDialogAction(
          label: 'Download',
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop('download'),
        ),
      ],
    );

    _visible = false;

    switch (action) {
      case 'download':
        final url = result.downloadUrl;
        try {
          await launchURL(Uri.parse(url));
        } catch (_) {
          if (context.mounted) {
            showToast(context, 'Could not open the download link.');
          }
        }
        break;
      case 'skip':
        await UpdateService.instance.skipVersion(result.release.version);
        break;
      case 'later':
        await UpdateService.instance.remindLater();
        break;
    }
  }
}

class _UpdateDialogContent extends StatelessWidget {
  const _UpdateDialogContent({required this.result});

  final UpdateCheckResult result;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final subtleColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.62)
        : const Color(0xFF6C6C70);
    final notes = _cleanNotes(result.release.notes);
    final asset = result.preferredAsset;

    return SizedBox(
      width: 330,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              updateHeroAsset,
              height: 148,
              width: double.infinity,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.35),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v${result.release.version}',
                  style: const TextStyle(
                    color: Color(0xFFFF2D55),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (asset != null && asset.sizeLabel.isNotEmpty)
                Text(
                  asset.sizeLabel,
                  style: TextStyle(fontSize: 12, color: subtleColor),
                ),
              const Spacer(),
              Text(
                'GPL-3.0',
                style: TextStyle(fontSize: 11, color: subtleColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'What’s new',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                notes.isEmpty ? 'Bug fixes and polish.' : notes,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: subtleColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanNotes(String raw) {
    var value = raw
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll('`', '')
        .trim();
    if (value.length > 2600) {
      value = '${value.substring(0, 2600).trimRight()}…';
    }
    return value;
  }
}
