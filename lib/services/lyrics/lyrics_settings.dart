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

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Every lyrics source FluentMusic can ask, in BitChord's registry order.
///
/// The storage value is stable and independent of the Dart enum name, so a
/// rename cannot silently reset a user's provider selection. Providers are
/// gated by [lyricsEnabledProviders]; the plain `lyrics.ovh`, `paroles.net`
/// and `lyricsmania.com` scrapers stay as a final, non-configurable fallback
/// because they carry no API key or quota.
enum LyricsProvider {
  betterLyrics(
    'better_lyrics',
    'BetterLyrics',
    'Apple Music word-synced TTML from lyrics-api.boidu.dev',
    enabledByDefault: true,
  ),
  betterLyricsPortato(
    'better_lyrics_portato',
    'BetterLyrics Portato',
    'QQ Music portato/word sync through the same API',
    enabledByDefault: true,
  ),
  youLyPlus(
    'youlyplus',
    'YouLy+',
    'Word and syllable sync across five public mirrors',
    enabledByDefault: true,
  ),
  binimum(
    'binimum',
    'Binimum',
    'Word-timed TTML from the open Binimum API',
    enabledByDefault: true,
  ),
  lrclib(
    'lrclib',
    'LRCLIB',
    'Open community synced and plain LRC',
    enabledByDefault: true,
  ),
  kuGou('kugou', 'KuGou', 'Chinese catalogue LRC via the public web API'),
  megalobiz('megalobiz', 'Megalobiz', 'LRC archive scraped from Megalobiz'),
  simpMusic(
    'simpmusic',
    'SimpMusic',
    'Video-id matched synced or plain lyrics',
    enabledByDefault: true,
  ),
  unison(
    'unison',
    'Unison',
    'Crowdsourced, video-id exact lyrics with submitter credit',
    enabledByDefault: true,
  ),
  paxsenixAppleMusic(
    'paxsenix_apple_music',
    'Paxsenix · Apple Music',
    'Apple Music lyrics; requires a Paxsenix API key',
    requiresApiKey: true,
  ),
  paxsenixSpotify(
    'paxsenix_spotify',
    'Paxsenix · Spotify',
    'Spotify lyrics; requires a Paxsenix API key',
    requiresApiKey: true,
  ),
  paxsenixMusixmatch(
    'paxsenix_musixmatch',
    'Paxsenix · Musixmatch',
    'Musixmatch lyrics; requires a Paxsenix API key',
    requiresApiKey: true,
  ),
  youtubeSubtitle(
    'youtube_subtitle',
    'YouTube Subtitle',
    'Caption track of the exact upload; needs a video id',
  ),
  youtubeMusic(
    'youtube_music',
    'YouTube Music',
    'Timed lyrics from YouTube Music (Android Music client)',
    enabledByDefault: true,
  );

  const LyricsProvider(
    this.storageValue,
    this.displayName,
    this.description, {
    this.enabledByDefault = false,
    this.requiresApiKey = false,
  });

  final String storageValue;
  final String displayName;
  final String description;
  final bool enabledByDefault;
  final bool requiresApiKey;

  static LyricsProvider? fromStorage(Object? value) {
    if (value is! String) return null;
    for (final provider in LyricsProvider.values) {
      if (provider.storageValue == value) return provider;
    }
    return null;
  }
}

const _orderKey = 'lyricsProviderOrder';
const _paxsenixKeyKey = 'paxsenixApiKey';
const _secureStorage = FlutterSecureStorage();
String _securePaxsenixKey = '';
String _enabledKey(LyricsProvider provider) =>
    'lyricsProviderEnabled_${provider.storageValue}';

Box<dynamic>? get _settingsBox =>
    Hive.isBoxOpen('settings') ? Hive.box('settings') : null;

List<LyricsProvider> _loadOrder() {
  final raw = _settingsBox?.get(_orderKey);
  final ordered = <LyricsProvider>[];
  if (raw is List) {
    for (final value in raw) {
      final provider = LyricsProvider.fromStorage(value);
      if (provider != null && !ordered.contains(provider))
        ordered.add(provider);
    }
  } else if (raw is String) {
    for (final value in raw.split(',')) {
      final provider = LyricsProvider.fromStorage(value.trim());
      if (provider != null && !ordered.contains(provider))
        ordered.add(provider);
    }
  }
  // New releases append instead of resetting the user's existing order.
  for (final provider in LyricsProvider.values) {
    if (!ordered.contains(provider)) ordered.add(provider);
  }
  return List.unmodifiable(ordered);
}

Set<LyricsProvider> _loadEnabled() {
  final enabled = <LyricsProvider>{};
  for (final provider in LyricsProvider.values) {
    final stored = _settingsBox?.get(_enabledKey(provider));
    if (stored is bool ? stored : provider.enabledByDefault) {
      enabled.add(provider);
    }
  }
  return Set.unmodifiable(enabled);
}

String _loadPaxsenixKey() {
  final raw = _settingsBox?.get(_paxsenixKeyKey);
  return raw is String ? raw.trim() : _securePaxsenixKey;
}

/// Load the user-supplied token from encrypted platform storage after startup.
Future<void> initializeLyricsSettings() async {
  try {
    _securePaxsenixKey =
        (await _secureStorage.read(key: _paxsenixKeyKey))?.trim() ?? '';
    final legacyValue = _settingsBox?.get(_paxsenixKeyKey);
    if (_securePaxsenixKey.isEmpty && legacyValue is String) {
      // Migrate older installs from the plain Hive settings box.
      _securePaxsenixKey = legacyValue.trim();
      await _secureStorage.write(
        key: _paxsenixKeyKey,
        value: _securePaxsenixKey,
      );
      await _settingsBox?.delete(_paxsenixKeyKey);
    }
    if (paxsenixApiKey.value != _securePaxsenixKey) {
      paxsenixApiKey.value = _securePaxsenixKey;
    }
  } catch (_) {
    // Keep the in-memory Hive value if the platform has no secure storage.
  }
}

/// Display/priority order for the lyrics settings screen and the fetch chain.
final ValueNotifier<List<LyricsProvider>> lyricsProviderOrder = ValueNotifier(
  _loadOrder(),
);

/// Providers the user allows the manager to contact.
final ValueNotifier<Set<LyricsProvider>> lyricsEnabledProviders = ValueNotifier(
  _loadEnabled(),
);

/// Paxsenix bearer token. Empty means the three Paxsenix providers are skipped.
final ValueNotifier<String> paxsenixApiKey = ValueNotifier(_loadPaxsenixKey());

/// Providers in the configured order, with disabled entries removed.
List<LyricsProvider> enabledLyricsProviders() {
  final enabled = lyricsEnabledProviders.value;
  return [
    for (final provider in lyricsProviderOrder.value)
      if (enabled.contains(provider)) provider,
  ];
}

void setLyricsProviderEnabled(LyricsProvider provider, bool enabled) {
  final next = Set<LyricsProvider>.from(lyricsEnabledProviders.value);
  if (enabled) {
    next.add(provider);
  } else {
    next.remove(provider);
  }
  lyricsEnabledProviders.value = Set.unmodifiable(next);
  _settingsBox?.put(_enabledKey(provider), enabled).ignore();
}

/// Moves [provider] by [delta] places. No-op at the ends.
void moveLyricsProvider(LyricsProvider provider, int delta) {
  final next = List<LyricsProvider>.from(lyricsProviderOrder.value);
  final from = next.indexOf(provider);
  if (from < 0) return;
  final to = (from + delta).clamp(0, next.length - 1);
  if (from == to) return;
  next.removeAt(from);
  next.insert(to, provider);
  lyricsProviderOrder.value = List.unmodifiable(next);
  _settingsBox
      ?.put(
        _orderKey,
        next.map((provider) => provider.storageValue).toList(growable: false),
      )
      .ignore();
}

void setPaxsenixApiKey(String key) {
  final trimmed = key.trim();
  paxsenixApiKey.value = trimmed;
  _securePaxsenixKey = trimmed;
  _secureStorage.write(key: _paxsenixKeyKey, value: trimmed).ignore();
}

/// Cache-key component: a settings change must not return the previous
/// provider's saved result.
String lyricsProviderConfigSignature() {
  final enabled = lyricsEnabledProviders.value;
  final order = lyricsProviderOrder.value
      .map(
        (provider) =>
            '${provider.storageValue}:${enabled.contains(provider) ? 1 : 0}',
      )
      .join(',');
  return '$order|key:${paxsenixApiKey.value}';
}
