/*
 *     Copyright (C) 2026 jaypakash sahu
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/foundation.dart';

/// A single downloadable asset attached to a GitHub release.
class UpdateAsset {
  const UpdateAsset({
    required this.name,
    required this.downloadUrl,
    this.sizeBytes = 0,
    this.digest,
  });

  factory UpdateAsset.fromJson(Map<String, dynamic> json) {
    return UpdateAsset(
      name: json['name']?.toString() ?? '',
      downloadUrl: json['browser_download_url']?.toString() ?? '',
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      digest: json['digest']?.toString(),
    );
  }

  final String name;
  final String downloadUrl;
  final int sizeBytes;

  /// GitHub's `sha256:...` digest when the release provides one.
  final String? digest;

  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
  }
}

/// A parsed GitHub release.
class UpdateRelease {
  const UpdateRelease({
    required this.tagName,
    required this.version,
    required this.title,
    required this.notes,
    required this.pageUrl,
    required this.publishedAt,
    required this.assets,
    this.prerelease = false,
  });

  factory UpdateRelease.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name']?.toString() ?? '';
    return UpdateRelease(
      tagName: tag,
      version: cleanVersion(tag),
      title: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString()
          : tag,
      notes: json['body']?.toString() ?? '',
      pageUrl: json['html_url']?.toString() ?? '',
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? '')
          ?.toUtc(),
      prerelease: json['prerelease'] == true,
      assets: (json['assets'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(UpdateAsset.fromJson)
          .where((asset) => asset.downloadUrl.isNotEmpty)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tag_name': tagName,
      'version': version,
      'name': title,
      'body': notes,
      'html_url': pageUrl,
      'published_at': publishedAt?.toIso8601String(),
      'prerelease': prerelease,
      'assets': [
        for (final asset in assets)
          {
            'name': asset.name,
            'browser_download_url': asset.downloadUrl,
            'size': asset.sizeBytes,
            'digest': asset.digest,
          },
      ],
    };
  }

  final String tagName;
  final String version;
  final String title;
  final String notes;
  final String pageUrl;
  final DateTime? publishedAt;
  final List<UpdateAsset> assets;
  final bool prerelease;
}

/// Result of one update check.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.release,
    required this.checkedAt,
    required this.updateAvailable,
    this.fromCache = false,
  });

  final String currentVersion;
  final UpdateRelease release;
  final DateTime checkedAt;
  final bool updateAvailable;
  final bool fromCache;

  UpdateAsset? get preferredAsset => selectAsset(release);

  String get downloadUrl => preferredAsset?.downloadUrl ?? release.pageUrl;
}

/// A user-facing failure from the update service.
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

String cleanVersion(String raw) {
  var value = raw.trim();
  if (value.startsWith('v') || value.startsWith('V')) {
    value = value.substring(1);
  }
  return value;
}

/// Compares semantic-ish versions without pulling in `pub_semver`.
/// Returns a positive number when [a] is newer than [b].
int compareVersions(String a, String b) {
  final left = _ParsedVersion.parse(a);
  final right = _ParsedVersion.parse(b);
  return left.compareTo(right);
}

class _ParsedVersion implements Comparable<_ParsedVersion> {
  _ParsedVersion(this.parts, this.preRelease);

  factory _ParsedVersion.parse(String raw) {
    final cleaned = cleanVersion(raw).split('+').first;
    final pieces = cleaned.split('-');
    final numbers = pieces.first
        .split('.')
        .map(
          (part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        )
        .toList(growable: false);
    final preRelease = pieces.length > 1 ? pieces.sublist(1).join('-') : null;
    return _ParsedVersion(numbers, preRelease);
  }

  final List<int> parts;
  final String? preRelease;

  @override
  int compareTo(_ParsedVersion other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < length; i++) {
      final left = i < parts.length ? parts[i] : 0;
      final right = i < other.parts.length ? other.parts[i] : 0;
      if (left != right) return left.compareTo(right);
    }
    // A release is newer than a pre-release with the same core version.
    if (preRelease == null && other.preRelease != null) return 1;
    if (preRelease != null && other.preRelease == null) return -1;
    if (preRelease != null && other.preRelease != null) {
      return preRelease!.compareTo(other.preRelease!);
    }
    return 0;
  }
}

/// Picks the best asset for the current platform. Kept pure so it can be
/// unit tested without touching platform channels.
UpdateAsset? selectAsset(
  UpdateRelease release, {
  bool? android,
  bool? windows,
}) {
  final isAndroid =
      android ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  final isWindows =
      windows ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

  bool nameHas(UpdateAsset asset, List<String> needles) {
    final name = asset.name.toLowerCase();
    return needles.every(name.contains);
  }

  if (isAndroid) {
    for (final asset in release.assets) {
      if (nameHas(asset, ['universal', '.apk'])) return asset;
    }
    for (final asset in release.assets) {
      if (nameHas(asset, ['arm64', '.apk'])) return asset;
    }
    for (final asset in release.assets) {
      if (nameHas(asset, ['.apk'])) return asset;
    }
  }

  if (isWindows) {
    for (final asset in release.assets) {
      if (nameHas(asset, ['windows', 'x64', '.zip'])) return asset;
    }
    for (final asset in release.assets) {
      if (nameHas(asset, ['windows', '.zip'])) return asset;
    }
  }

  for (final asset in release.assets) {
    if (asset.name.toLowerCase().endsWith('.apk')) return asset;
  }
  return release.assets.isEmpty ? null : release.assets.first;
}
