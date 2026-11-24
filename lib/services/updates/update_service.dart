/*
 *     Copyright (C) 2026 jaypakash sahu
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/updates/update_models.dart';

const String updateRepoOwner = 'ks3695602-sys';
const String updateRepoName = 'FluentMusic-Flutter';
const String updateLatestReleaseApi =
    'https://api.github.com/repos/$updateRepoOwner/$updateRepoName/releases/latest';
const String updateReleasesApi =
    'https://api.github.com/repos/$updateRepoOwner/$updateRepoName/releases?per_page=10';
const String updateReleasesPage =
    'https://github.com/$updateRepoOwner/$updateRepoName/releases';
const String updateHeroAsset =
    'assets/images/updates/fluentmusic-update-hero.webp';

const Duration _cacheTtl = Duration(hours: 24);
const Duration _promptCooldown = Duration(hours: 24);

const String _keyCachedRelease = 'update_cached_release';
const String _keyCachedAt = 'update_cached_at';
const String _keySkippedVersion = 'update_skipped_version';
const String _keyRemindAfter = 'update_remind_after';
const String _keyPromptedVersion = 'update_prompted_version';
const String _keyPromptedAt = 'update_prompted_at';
const String _keyAutoChecks = 'autoUpdateChecks';

/// GitHub Releases backed update service. One source of truth, a 24 hour
/// cache, and no dependency on the legacy `check.json` release fields.
class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  String? _cachedCurrentVersion;

  Box<dynamic>? get _box =>
      Hive.isBoxOpen('settings') ? Hive.box('settings') : null;

  Future<String> currentVersion() async {
    final cached = _cachedCurrentVersion;
    if (cached != null) return cached;
    try {
      final info = await PackageInfo.fromPlatform();
      final value = info.version.isEmpty ? '0.0.0' : info.version;
      _cachedCurrentVersion = value;
      return value;
    } catch (error) {
      debugPrint('[Updates] Could not read package info: $error');
      return '0.0.0';
    }
  }

  bool get autoChecksEnabled {
    final value = _box?.get(_keyAutoChecks);
    return value is bool ? value : true;
  }

  Future<void> setAutoChecksEnabled(bool enabled) async {
    await _box?.put(_keyAutoChecks, enabled);
  }

  DateTime? get lastCheckedAt {
    final raw = _box?.get(_keyCachedAt)?.toString();
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  String? get skippedVersion => _box?.get(_keySkippedVersion)?.toString();

  DateTime? get remindAfter {
    final raw = _box?.get(_keyRemindAfter)?.toString();
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> skipVersion(String version) async {
    await _box?.put(_keySkippedVersion, cleanVersion(version));
  }

  Future<void> remindLater([Duration delay = const Duration(days: 1)]) async {
    await _box?.put(
      _keyRemindAfter,
      DateTime.now().add(delay).toIso8601String(),
    );
  }

  /// Whether a release should interrupt the user right now.
  bool shouldPrompt(UpdateCheckResult result) {
    if (!result.updateAvailable) return false;
    final skipped = skippedVersion;
    if (skipped != null && skipped == result.release.version) return false;
    final remind = remindAfter;
    if (remind != null && DateTime.now().isBefore(remind)) return false;
    final promptedVersion = _box?.get(_keyPromptedVersion)?.toString();
    final promptedAt = DateTime.tryParse(
      _box?.get(_keyPromptedAt)?.toString() ?? '',
    );
    if (promptedVersion == result.release.version &&
        promptedAt != null &&
        DateTime.now().difference(promptedAt) < _promptCooldown) {
      return false;
    }
    return true;
  }

  Future<void> markPrompted(String version) async {
    await _box?.put(_keyPromptedVersion, cleanVersion(version));
    await _box?.put(_keyPromptedAt, DateTime.now().toIso8601String());
  }

  /// Checks GitHub for a newer release. Set [force] for a manual check.
  /// Throws [UpdateCheckException] with a readable message on failure.
  Future<UpdateCheckResult> checkForUpdates({bool force = false}) async {
    final current = await currentVersion();
    final cached = _readCache(current);
    if (!force && cached != null) {
      final age = DateTime.now().difference(cached.checkedAt);
      if (age < _cacheTtl) {
        return _withCurrentVersion(cached, current, fromCache: true);
      }
    }

    if (offlineMode.value) {
      if (cached != null) {
        return _withCurrentVersion(cached, current, fromCache: true);
      }
      throw const UpdateCheckException(
        'You are offline. Connect to the internet to check for updates.',
      );
    }

    late final http.Response response;
    try {
      response = await http
          .get(
            Uri.parse(updateLatestReleaseApi),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'FluentMusic-Updater',
            },
          )
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      if (cached != null) {
        return _withCurrentVersion(cached, current, fromCache: true);
      }
      throw const UpdateCheckException(
        'Could not reach GitHub. Check your connection and try again.',
      );
    }

    if (response.statusCode == 404) {
      throw const UpdateCheckException(
        'No published release was found for this build.',
      );
    }
    if (response.statusCode == 403) {
      throw const UpdateCheckException(
        'GitHub is rate-limiting update checks. Try again in a few minutes.',
      );
    }
    if (response.statusCode != 200) {
      throw UpdateCheckException(
        'GitHub returned HTTP ${response.statusCode}. Try again later.',
      );
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const UpdateCheckException('GitHub returned an unexpected reply.');
    }

    final release = UpdateRelease.fromJson(json);
    final checkedAt = DateTime.now();
    final result = UpdateCheckResult(
      currentVersion: current,
      release: release,
      checkedAt: checkedAt,
      updateAvailable: compareVersions(release.version, current) > 0,
    );

    await _writeCache(result);
    return result;
  }

  UpdateCheckResult? _readCache(String current) {
    final raw = _box?.get(_keyCachedRelease);
    final checkedRaw = _box?.get(_keyCachedAt)?.toString();
    if (raw is! Map || checkedRaw == null) return null;
    final checkedAt = DateTime.tryParse(checkedRaw);
    if (checkedAt == null) return null;
    try {
      final release = UpdateRelease.fromJson(Map<String, dynamic>.from(raw));
      return UpdateCheckResult(
        currentVersion: current,
        release: release,
        checkedAt: checkedAt,
        updateAvailable: compareVersions(release.version, current) > 0,
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(UpdateCheckResult result) async {
    await _box?.put(_keyCachedRelease, result.release.toJson());
    await _box?.put(_keyCachedAt, result.checkedAt.toIso8601String());
  }

  UpdateCheckResult _withCurrentVersion(
    UpdateCheckResult cached,
    String current, {
    required bool fromCache,
  }) {
    return UpdateCheckResult(
      currentVersion: current,
      release: cached.release,
      checkedAt: cached.checkedAt,
      updateAvailable: compareVersions(cached.release.version, current) > 0,
      fromCache: fromCache,
    );
  }
}
