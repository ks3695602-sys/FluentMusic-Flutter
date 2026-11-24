/// The subset of Mornye's settings the copied player UI reads.
///
/// FluentMusic keeps its real preferences in its own settings service; this
/// bridge is a plain snapshot so the player widgets can be copied nearly
/// unchanged. Values the player never touches are deliberately absent.
library;

/// Volume levels, in percent, above which the volume bar can ask first.
const loudVolumeLevels = [60, 70, 80, 90];

int loudVolumeLevelFromJson(Object? value) =>
    value is int && loudVolumeLevels.contains(value) ? value : 80;

/// Slowest and fastest playback speed, as a factor of the normal speed.
const double minPlaybackSpeed = 0.5;
const double maxPlaybackSpeed = 2;

double playbackSpeedFromJson(Object? value) => value is num && value.isFinite
    ? value.toDouble().clamp(minPlaybackSpeed, maxPlaybackSpeed)
    : 1;

/// Largest pitch shift either way, in semitones.
const double maxPlaybackPitch = 12;

/// The pitch shift in whole semitones, the steps a key changes by.
double playbackPitchFromJson(Object? value) => value is num && value.isFinite
    ? value.toDouble().roundToDouble().clamp(-maxPlaybackPitch, maxPlaybackPitch)
    : 0;

class AppSettings {
  const AppSettings({
    this.autoHideLyricsControls = true,
    this.autoHideLyricsControlsWithAccessibility = false,
    this.autoMix = false,
    this.autoplay = false,
    this.confirmLoudVolume = true,
    this.locale = 'system',
    this.loudVolumeLevel = 80,
    this.lyricsAiBaseUrl = '',
    this.lyricsAiModel = '',
    this.lyricsAiProvider = 'openai',
    this.lyricsAiWordSync = false,
    this.lyricsAutoTranslate = false,
    this.lyricsRomanize = true,
    this.lyricsRomanizedMainLine = false,
    this.lyricsTranslationLanguage = '',
    this.playbackKeepPitch = true,
    this.playbackNormalization = false,
    this.playbackPitch = 0,
    this.playbackSpeed = 1,
    this.playerShowLyricSnippet = false,
    this.playerShowPronunciation = true,
    this.playerShowTranslation = true,
    this.playerShowVolume = true,
    this.queueLocked = false,
    this.swipeToQueue = true,
    this.usbBitPerfect = false,
    this.forceBackdropBlur = false,
  });

  final bool autoHideLyricsControls;

  /// An explicit auto-hide choice also applies if accessibility changes later.
  final bool autoHideLyricsControlsWithAccessibility;

  final bool autoMix;
  final bool autoplay;

  /// Ask before the app's volume bar goes above [loudVolumeLevel] percent.
  final bool confirmLoudVolume;

  /// The app language, as Mornye stores it; FluentMusic always runs its own.
  final String locale;

  /// One of [loudVolumeLevels].
  final int loudVolumeLevel;

  final String lyricsAiBaseUrl;
  final String lyricsAiModel;
  final String lyricsAiProvider;
  final bool lyricsAiWordSync;
  final bool lyricsAutoTranslate;
  final bool lyricsRomanize;
  final bool lyricsRomanizedMainLine;
  final String lyricsTranslationLanguage;

  final bool playbackKeepPitch;
  final bool playbackNormalization;
  final double playbackPitch;
  final double playbackSpeed;

  final bool playerShowLyricSnippet;
  final bool playerShowPronunciation;
  final bool playerShowTranslation;
  final bool playerShowVolume;
  final bool queueLocked;
  final bool swipeToQueue;
  final bool usbBitPerfect;
  final bool forceBackdropBlur;

  bool shouldAutoHideLyricsControls({required bool accessibleNavigation}) =>
      autoHideLyricsControls &&
      (!accessibleNavigation || autoHideLyricsControlsWithAccessibility);

  AppSettings copyWith({
    bool? autoHideLyricsControls,
    bool? autoHideLyricsControlsWithAccessibility,
    bool? autoMix,
    bool? autoplay,
    bool? confirmLoudVolume,
    String? locale,
    int? loudVolumeLevel,
    String? lyricsAiBaseUrl,
    String? lyricsAiModel,
    String? lyricsAiProvider,
    bool? lyricsAiWordSync,
    bool? lyricsAutoTranslate,
    bool? lyricsRomanize,
    bool? lyricsRomanizedMainLine,
    String? lyricsTranslationLanguage,
    bool? playbackKeepPitch,
    bool? playbackNormalization,
    double? playbackPitch,
    double? playbackSpeed,
    bool? playerShowLyricSnippet,
    bool? playerShowPronunciation,
    bool? playerShowTranslation,
    bool? playerShowVolume,
    bool? queueLocked,
    bool? swipeToQueue,
    bool? usbBitPerfect,
    bool? forceBackdropBlur,
  }) => AppSettings(
    autoHideLyricsControls:
        autoHideLyricsControls ?? this.autoHideLyricsControls,
    autoHideLyricsControlsWithAccessibility:
        autoHideLyricsControlsWithAccessibility ??
        this.autoHideLyricsControlsWithAccessibility,
    autoMix: autoMix ?? this.autoMix,
    autoplay: autoplay ?? this.autoplay,
    confirmLoudVolume: confirmLoudVolume ?? this.confirmLoudVolume,
    locale: locale ?? this.locale,
    loudVolumeLevel: loudVolumeLevel ?? this.loudVolumeLevel,
    lyricsAiBaseUrl: lyricsAiBaseUrl ?? this.lyricsAiBaseUrl,
    lyricsAiModel: lyricsAiModel ?? this.lyricsAiModel,
    lyricsAiProvider: lyricsAiProvider ?? this.lyricsAiProvider,
    lyricsAiWordSync: lyricsAiWordSync ?? this.lyricsAiWordSync,
    lyricsAutoTranslate: lyricsAutoTranslate ?? this.lyricsAutoTranslate,
    lyricsRomanize: lyricsRomanize ?? this.lyricsRomanize,
    lyricsRomanizedMainLine:
        lyricsRomanizedMainLine ?? this.lyricsRomanizedMainLine,
    lyricsTranslationLanguage:
        lyricsTranslationLanguage ?? this.lyricsTranslationLanguage,
    playbackKeepPitch: playbackKeepPitch ?? this.playbackKeepPitch,
    playbackNormalization:
        playbackNormalization ?? this.playbackNormalization,
    playbackPitch: playbackPitchFromJson(playbackPitch ?? this.playbackPitch),
    playbackSpeed: playbackSpeedFromJson(playbackSpeed ?? this.playbackSpeed),
    playerShowLyricSnippet:
        playerShowLyricSnippet ?? this.playerShowLyricSnippet,
    playerShowPronunciation:
        playerShowPronunciation ?? this.playerShowPronunciation,
    playerShowTranslation:
        playerShowTranslation ?? this.playerShowTranslation,
    playerShowVolume: playerShowVolume ?? this.playerShowVolume,
    queueLocked: queueLocked ?? this.queueLocked,
    swipeToQueue: swipeToQueue ?? this.swipeToQueue,
    usbBitPerfect: usbBitPerfect ?? this.usbBitPerfect,
    forceBackdropBlur: forceBackdropBlur ?? this.forceBackdropBlur,
  );

  Map<String, dynamic> toJson() => {
    'autoHideLyricsControls': autoHideLyricsControls,
    'autoHideLyricsControlsWithAccessibility':
        autoHideLyricsControlsWithAccessibility,
    'autoMix': autoMix,
    'autoplay': autoplay,
    'confirmLoudVolume': confirmLoudVolume,
    'locale': locale,
    'loudVolumeLevel': loudVolumeLevel,
    'lyricsAiBaseUrl': lyricsAiBaseUrl,
    'lyricsAiModel': lyricsAiModel,
    'lyricsAiProvider': lyricsAiProvider,
    'lyricsAiWordSync': lyricsAiWordSync,
    'lyricsAutoTranslate': lyricsAutoTranslate,
    'lyricsRomanize': lyricsRomanize,
    'lyricsRomanizedMainLine': lyricsRomanizedMainLine,
    'lyricsTranslationLanguage': lyricsTranslationLanguage,
    'playbackKeepPitch': playbackKeepPitch,
    'playbackNormalization': playbackNormalization,
    'playbackPitch': playbackPitch,
    'playbackSpeed': playbackSpeed,
    'playerShowLyricSnippet': playerShowLyricSnippet,
    'playerShowPronunciation': playerShowPronunciation,
    'playerShowTranslation': playerShowTranslation,
    'playerShowVolume': playerShowVolume,
    'queueLocked': queueLocked,
    'swipeToQueue': swipeToQueue,
    'usbBitPerfect': usbBitPerfect,
    'forceBackdropBlur': forceBackdropBlur,
  };
}