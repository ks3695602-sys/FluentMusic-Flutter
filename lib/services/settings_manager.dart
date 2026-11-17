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
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'package:audio_service/audio_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/screens/playlist_page.dart';
import 'package:musify/screens/user_songs_page.dart';
import 'package:musify/theme/glass_config_controller.dart';
import 'package:musify/theme/player_style.dart';
import 'package:musify/utilities/language_utils.dart';

// Preferences

final shouldWeCheckUpdates = ValueNotifier<bool?>(
  Hive.box('settings').get('shouldWeCheckUpdates', defaultValue: null),
);

final playNextSongAutomatically = ValueNotifier<bool>(
  Hive.box('settings').get('playNextSongAutomatically', defaultValue: false),
);

final useSystemColor = ValueNotifier<bool>(
  Hive.box('settings').get('useSystemColor', defaultValue: false),
);

final usePureBlackColor = ValueNotifier<bool>(
  Hive.box('settings').get('usePureBlackColor', defaultValue: true),
);

final offlineMode = ValueNotifier<bool>(
  Hive.box('settings').get('offlineMode', defaultValue: false),
);

final wrappedEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('wrappedEnabled', defaultValue: true),
);

final sponsorBlockSupport = ValueNotifier<bool>(
  Hive.box('settings').get('sponsorBlockSupport', defaultValue: false),
);

final externalRecommendations = ValueNotifier<bool>(
  Hive.box('settings').get('externalRecommendations', defaultValue: false),
);

final useProxy = ValueNotifier<bool>(
  Hive.box('settings').get('useProxy', defaultValue: false),
);

final audioQualitySetting = ValueNotifier<String>(
  Hive.box('settings').get('audioQuality', defaultValue: 'high'),
);

final showAudioQualityBadge = ValueNotifier<bool>(
  Hive.box('settings').get('showAudioQualityBadge', defaultValue: false),
);

final syncedLyricsEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('syncedLyricsEnabled', defaultValue: true),
);

final lyricsOffsetMs = ValueNotifier<int>(
  Hive.box('settings').get('lyricsOffsetMs', defaultValue: 0) as int,
);

List<double> _readEqualizerGains() {
  final raw = Hive.box('settings')
      .get('equalizerBandGains', defaultValue: const <dynamic>[]);

  if (raw is List) {
    return raw.map((value) => value is num ? value.toDouble() : 0.0).toList();
  }

  return <double>[];
}

final equalizerEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('equalizerEnabled', defaultValue: false),
);

final equalizerBandGains = ValueNotifier<List<double>>(_readEqualizerGains());

Locale languageSetting = getLocaleFromLanguageCode(
  Hive.box('settings').get('languageCode', defaultValue: 'en') as String,
);

int themeModeSetting =
    Hive.box('settings').get('themeIndex', defaultValue: 0) as int;

String playlistSortSetting = Hive.box('settings')
    .get('playlistSortType', defaultValue: PlaylistSortType.default_.name);

String offlineSortSetting = Hive.box('settings')
    .get('offlineSortType', defaultValue: OfflineSortType.default_.name);

Color primaryColorSetting = Color(
  Hive.box('settings').get('accentColor', defaultValue: 0xFFFA2D48),
);

final appleMusicLyricsEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('appleMusicLyricsEnabled', defaultValue: true),
);

final liquidGlassQualitySetting = ValueNotifier<String>(
  Hive.box('settings').get('liquidGlassQuality', defaultValue: 'premium'),
);

/// How Now Playing stages the artwork. Defaults to the original full-bleed
/// immersive look, so existing installs see no change after upgrading.
final playerStyleSetting = ValueNotifier<PlayerStyle>(
  PlayerStyle.fromStorage(Hive.box('settings').get('playerStyle')),
);

/// Persists and broadcasts a new Now Playing presentation.
void setPlayerStyle(PlayerStyle style) {
  if (playerStyleSetting.value == style) return;
  playerStyleSetting.value = style;
  if (Hive.isBoxOpen('settings')) {
    Hive.box('settings').put('playerStyle', style.storageValue).ignore();
  }
}

final liquidGlassBlurSetting = ValueNotifier<double>(
  (Hive.box('settings').get('liquidGlassBlur', defaultValue: 4.0) as num).toDouble(),
);

final liquidGlassThicknessSetting = ValueNotifier<double>(
  (Hive.box('settings').get('liquidGlassThickness', defaultValue: 40.0) as num).toDouble(),
);

final wordByWordLyricsEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('wordByWordLyricsEnabled', defaultValue: true),
);

final crossfadeDurationSetting = ValueNotifier<double>(
  (Hive.box('settings').get('crossfadeDuration', defaultValue: 0.0) as num).toDouble(),
);

final gaplessPlaybackEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('gaplessPlaybackEnabled', defaultValue: true),
);

final autoResumePlaybackEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('autoResumePlaybackEnabled', defaultValue: false),
);

final pauseOnHeadphoneDisconnect = ValueNotifier<bool>(
  Hive.box('settings').get('pauseOnHeadphoneDisconnect', defaultValue: true),
);

/// Pause when the in-app volume slider reaches zero, and optionally resume
/// when it is raised again. Playback itself never depends on these.
final pauseOnVolumeZero = ValueNotifier<bool>(
  Hive.box('settings').get('pauseOnVolumeZero', defaultValue: true),
);

final resumeOnVolumeRaise = ValueNotifier<bool>(
  Hive.box('settings').get('resumeOnVolumeRaise', defaultValue: true),
);

/// Experimental D2 switch: try the signed-in YouTube Music session first when
/// resolving a stream. Off by default; the anonymous path is always the
/// fallback and is never modified.
final ytMusicSignedInPlayback = ValueNotifier<bool>(
  Hive.box('settings').get('ytMusicSignedInPlayback', defaultValue: false),
);

final saveSearchHistoryEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('saveSearchHistoryEnabled', defaultValue: true),
);

final androidAutoEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('androidAutoEnabled', defaultValue: true),
);

final keepPlayingAfterDismiss = ValueNotifier<bool>(
  Hive.box('settings').get('keepPlayingAfterDismiss', defaultValue: true),
);

final searchQueueMode = ValueNotifier<String>(
  Hive.box('settings').get('searchQueueMode', defaultValue: 'search_results') as String,
);

void updateKeepPlayingAfterDismiss(bool value) {
  keepPlayingAfterDismiss.value = value;
  Hive.box('settings').put('keepPlayingAfterDismiss', value);
}

void updateSearchQueueMode(String value) {
  searchQueueMode.value = value;
  Hive.box('settings').put('searchQueueMode', value);
}

final streamingSourceSetting = ValueNotifier<String>(
  Hive.box('settings').get('streamingSource', defaultValue: 'YouTube Music'),
);

final cacheLimitMbSetting = ValueNotifier<double>(
  (Hive.box('settings').get('cacheLimitMb', defaultValue: 2048.0) as num).toDouble(),
);

final smartCacheEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('smartCacheEnabled', defaultValue: true),
);

GlassQuality parseGlassQuality(String q) {
  switch (q) {
    case 'premium':
      return GlassQuality.premium;
    case 'minimal':
      return GlassQuality.minimal;
    default:
      return GlassQuality.standard;
  }
}

/// Persists the explicit glass quality tier and refreshes the global theme.
///
/// The Glass Lab quality selector owns this value; the adaptive scope no
/// longer overrides it, so what the user picks is what every surface renders.
void setLiquidGlassQuality(String quality) {
  final normalized = switch (quality) {
    'standard' => 'standard',
    'minimal' => 'minimal',
    _ => 'premium',
  };
  if (liquidGlassQualitySetting.value == normalized) return;
  liquidGlassQualitySetting.value = normalized;
  if (Hive.isBoxOpen('settings')) {
    Hive.box('settings').put('liquidGlassQuality', normalized).ignore();
  }
  updateLiquidGlassTheme();
}

/// Resolves the shared glass theme from the Glass Lab config.
///
/// The tint colour is stored as `0xAARRGGBB`; its alpha is the separate
/// transparency value, so one colour works in both appearances.
GlassThemeData getEffectiveGlassTheme() {
  final config = glassConfigController.config;
  final tintColor = Color(config.tintColor).withValues(alpha: config.tint);
  final saturation = config.dynamicTint ? config.saturation : 1.0;
  final base = GlassThemeData.simple(
    blur: config.blur,
    thickness: config.thickness,
    quality: parseGlassQuality(liquidGlassQualitySetting.value),
    chromaticAberration: config.chromaticAberration,
    refractiveIndex: config.refraction,
    saturation: saturation,
  );

  GlassThemeVariant tune(GlassThemeVariant variant) {
    final settings = variant.settings ?? const GlassThemeSettings();
    return variant.copyWith(
      settings: settings.copyWith(
        glassColor: tintColor,
        frost: config.frost,
        blur: config.blur,
        thickness: config.thickness,
        chromaticAberration: config.chromaticAberration,
        refractiveIndex: config.refraction,
        saturation: saturation,
      ),
    );
  }

  return GlassThemeData(
    style: base.style,
    light: tune(base.light),
    dark: tune(base.dark),
    interaction: base.interaction,
    brightness: base.brightness,
  );
}

/// Dock-specific glass settings, so the tab bar can be tuned independently
/// from the rest of the app while staying inside the same glass group.
LiquidGlassSettings getEffectiveDockGlassSettings({required bool isDark}) {
  final config = glassConfigController.config;
  final theme = liquidGlassThemeNotifier.value;
  final variant = isDark ? theme.dark : theme.light;
  final base = (variant.settings ?? const GlassThemeSettings())
      .applyTo(const LiquidGlassSettings());
  final color = Color(config.dockTintColor ?? config.tintColor);
  final alpha = config.dockTint ?? config.tint;
  return base.copyWith(
    blur: config.blur,
    frost: config.frost,
    thickness: config.thickness,
    chromaticAberration: config.chromaticAberration,
    refractiveIndex: config.refraction,
    saturation: config.dynamicTint ? config.saturation : 1.0,
    glassColor: color.withValues(alpha: alpha),
  );
}

final liquidGlassThemeNotifier = ValueNotifier<GlassThemeData>(getEffectiveGlassTheme());

void updateLiquidGlassTheme() {
  liquidGlassThemeNotifier.value = getEffectiveGlassTheme();
}

final shuffleNotifier = ValueNotifier<bool>(
  Hive.box('settings').get('shuffleEnabled', defaultValue: false),
);

final repeatNotifier = ValueNotifier<AudioServiceRepeatMode>(
  AudioServiceRepeatMode.values[Hive.box('settings')
      .get('repeatMode', defaultValue: 0)],
);

// Non-storage notifiers

var sleepTimerNotifier = ValueNotifier<Duration?>(null);

// Server-Notifiers

final announcementURL = ValueNotifier<String?>(null);

void reloadSettingsFromStorage() {
  final settings = Hive.box('settings');

  shouldWeCheckUpdates.value = settings.get(
    'shouldWeCheckUpdates',
    defaultValue: null,
  );
  playNextSongAutomatically.value = settings.get(
    'playNextSongAutomatically',
    defaultValue: false,
  );
  useSystemColor.value = settings.get('useSystemColor', defaultValue: true);
  usePureBlackColor.value = settings.get(
    'usePureBlackColor',
    defaultValue: false,
  );
  offlineMode.value = settings.get('offlineMode', defaultValue: false);
  wrappedEnabled.value = settings.get('wrappedEnabled', defaultValue: true);
  sponsorBlockSupport.value = settings.get(
    'sponsorBlockSupport',
    defaultValue: false,
  );
  externalRecommendations.value = settings.get(
    'externalRecommendations',
    defaultValue: false,
  );
  useProxy.value = settings.get('useProxy', defaultValue: false);
  audioQualitySetting.value = settings.get(
    'audioQuality',
    defaultValue: 'high',
  );
  showAudioQualityBadge.value = settings.get(
    'showAudioQualityBadge',
    defaultValue: false,
  );
  ytMusicSignedInPlayback.value = settings.get(
    'ytMusicSignedInPlayback',
    defaultValue: false,
  );
  syncedLyricsEnabled.value = settings.get(
    'syncedLyricsEnabled',
    defaultValue: true,
  );
  equalizerEnabled.value = settings.get(
    'equalizerEnabled',
    defaultValue: false,
  );
  equalizerBandGains.value = _readEqualizerGains();

  final restoredThemeIndex = settings.get('themeIndex', defaultValue: 0);
  if (restoredThemeIndex is int) themeModeSetting = restoredThemeIndex;

  final restoredLanguageCode = settings.get('languageCode', defaultValue: 'en');
  if (restoredLanguageCode is String) {
    languageSetting = getLocaleFromLanguageCode(restoredLanguageCode);
  }

  final restoredPlaylistSort = settings.get(
    'playlistSortType',
    defaultValue: PlaylistSortType.default_.name,
  );
  if (restoredPlaylistSort is String) {
    playlistSortSetting = restoredPlaylistSort;
  }

  final restoredOfflineSort = settings.get(
    'offlineSortType',
    defaultValue: OfflineSortType.default_.name,
  );
  if (restoredOfflineSort is String) {
    offlineSortSetting = restoredOfflineSort;
  }

  final restoredAccentColor = settings.get(
    'accentColor',
    defaultValue: 0xff91cef4,
  );
  if (restoredAccentColor is int) {
    primaryColorSetting = Color(restoredAccentColor);
  }

  shuffleNotifier.value = settings.get('shuffleEnabled', defaultValue: false);
  appleMusicLyricsEnabled.value = settings.get(
    'appleMusicLyricsEnabled',
    defaultValue: true,
  );
  liquidGlassQualitySetting.value = settings.get(
    'liquidGlassQuality',
    defaultValue: 'premium',
  );
  liquidGlassBlurSetting.value = (settings.get(
    'liquidGlassBlur',
    defaultValue: 4.0,
  ) as num).toDouble();
  liquidGlassThicknessSetting.value = (settings.get(
    'liquidGlassThickness',
    defaultValue: 40.0,
  ) as num).toDouble();
  final restoredRepeatIndex = settings.get('repeatMode', defaultValue: 0);
  if (restoredRepeatIndex is int &&
      restoredRepeatIndex >= 0 &&
      restoredRepeatIndex < AudioServiceRepeatMode.values.length) {
    repeatNotifier.value = AudioServiceRepeatMode.values[restoredRepeatIndex];
  }
  glassConfigController.reloadFromStorage();
  updateLiquidGlassTheme();
}
