import 'package:material_ui/material_ui.dart';

import 'package:musify/mornye_player/utils/user_facing_error.dart';

/// The strings the copied Mornye player reads through `context.l10n`.
///
/// Only the keys that player code uses are present. FluentMusic keeps its own
/// generated `AppLocalizations` for the rest of the app; this class carries
/// the same name in its own library so copied files keep compiling. Register
/// both delegates with the app's `MaterialApp`.
class AppLocalizations {
  const AppLocalizations(this.localeName);

  final String localeName;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static AppLocalizations? maybeOf(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[delegate];

  String get actionPause => 'Pause';

  String get audioInfoAlbumGain => 'Album gain';

  String get audioInfoAlbumPeak => 'Album peak';

  String get audioInfoAndroidNotReported => 'Not reported by Android';

  String get audioInfoAndroidPcmFormats => 'Android PCM formats';

  String get audioInfoAndroidPcmRates => 'Android PCM sample rates';

  String get audioInfoAnyRate => 'Any';

  String audioInfoApplied(Object gain) => 'Applied ${gain}';

  String audioInfoBands(Object count) => '${count} bands';

  String get audioInfoBitDepth => 'Bit depth';

  String get audioInfoBitPerfect => 'Bit-perfect';

  String get audioInfoBitPerfectActive => 'Yes, unaltered samples';

  String get audioInfoBitPerfectLossy => 'No, decoded from a lossy source';

  String get audioInfoBitPerfectNo => 'No, mixed by the system';

  String get audioInfoBitPerfectNoIos => 'No, iOS mixes all app audio';

  String get audioInfoBitPerfectProcessed => 'No, audio processing is active';

  String get audioInfoBitPerfectResampled => 'No, resampled to a rate the DAC accepts';

  String get audioInfoBitPerfectUnverified => 'Not verified';

  String get audioInfoBitrate => 'Bitrate';

  String get audioInfoBluetoothFormat => 'Bluetooth codec format';

  String get audioInfoBluetoothUnavailable => 'Unavailable to this app';

  String get audioInfoBluetoothUnavailableHint => 'Android may show the active codec in Bluetooth settings without making it available to Mornye. This is separate from the song\'s file format.';

  String get audioInfoBuffer => 'Mixer buffer';

  String get audioInfoBypassed => 'Bypassed by direct output';

  String get audioInfoChannels => 'Channels';

  String get audioInfoCodec => 'Codec';

  String get audioInfoCompression => 'Compression';

  String audioInfoCompressionValue(Object percent) => '${percent}% of uncompressed size';

  String get audioInfoCopied => 'Audio info copied';

  String get audioInfoCopy => 'Copy report';

  String get audioInfoDecoder => 'Decoder';

  String get audioInfoDevice => 'Device';

  String get audioInfoDeviceFormats => 'Device formats';

  String get audioInfoDeviceRates => 'Device sample rates';

  String get audioInfoDuration => 'Duration';

  String get audioInfoDynamicRange => 'Theoretical dynamic range';

  String get audioInfoFileSize => 'File size';

  String get audioInfoFixedVolume => 'Controlled by the device';

  String get audioInfoFormat => 'Format';

  String get audioInfoFrequencyRange => 'Frequency range';

  String audioInfoFrequencyRangeValue(Object frequency) => 'Up to ${frequency} (Nyquist)';

  String get audioInfoHardware => 'Hardware';

  String get audioInfoHeadTracking => 'Head tracking';

  String get audioInfoHiResLossless => 'Hi-Res Lossless';

  String get audioInfoLatency => 'Output latency';

  String get audioInfoLocation => 'Location';

  String audioInfoLocationLink(Object device) => '${device} via Mornye Link';

  String get audioInfoLocationLocal => 'Device storage';

  String get audioInfoLocationNetwork => 'Network storage';

  String get audioInfoLocationShared => 'Shared folder';

  String get audioInfoLossless => 'Lossless';

  String get audioInfoLossy => 'Lossy';

  String get audioInfoLoudness => 'Loudness';

  String get audioInfoLowLatency => 'Low-latency audio';

  String get audioInfoNoGainTags => 'No ReplayGain tags';

  String get audioInfoNotSupported => 'Not supported';

  String get audioInfoOff => 'Off';

  String get audioInfoOn => 'On';

  String get audioInfoOutput => 'Output';

  String get audioInfoOutputFormat => 'Output format';

  String get audioInfoOutputRate => 'Output sample rate';

  String get audioInfoPathDirect => 'Direct USB, bypasses the system mixer';

  String get audioInfoPathExclusive => 'Exclusive output, bypasses the system mixer';

  String get audioInfoPathSystem => 'System mixer';

  String get audioInfoPcmRate => 'Uncompressed data rate';

  String get audioInfoPlayer => 'Player';

  String get audioInfoPlayerValue => 'Mornye built-in player';

  String get audioInfoProAudio => 'Pro audio';

  String get audioInfoProcessing => 'Processing';

  String get audioInfoQuality => 'Quality';

  String get audioInfoResampling => 'Resampling';

  String get audioInfoResamplingNone => 'None, rates match';

  String get audioInfoSampleRate => 'Sample rate';

  String get audioInfoSignal => 'Signal';

  String get audioInfoSignalPath => 'Signal path';

  String get audioInfoSoftware => 'Software';

  String get audioInfoSource => 'Source file';

  String get audioInfoSpatial => 'Spatial audio';

  String get audioInfoSupported => 'Supported';

  String get audioInfoSystemDefaultBuffer => 'System default buffer';

  String get audioInfoSystemDefaultRate => 'System default sample rate';

  String get audioInfoTempo => 'Tempo';

  String get audioInfoTitle => 'Audio info';

  String get audioInfoTrackGain => 'Track gain';

  String get audioInfoTrackPeak => 'Track peak';

  String get audioInfoUnavailable => 'Unavailable';

  String get audioOutputAirPlay => 'AirPlay and Bluetooth';

  String get audioOutputCast => 'Cast to TV';

  String audioOutputCastConnectFailed(Object device) => 'Could not connect to ${device}';

  String get audioOutputCastDescription => 'Google Cast devices on the same Wi-Fi network';

  String get audioOutputCastSearching => 'Looking for Google Cast devices…';

  String get audioOutputCastUnavailable => 'Unable to open Google Cast. Check Google Play services and local network access.';

  String get audioOutputStopCasting => 'Stop casting';

  String get audioOutputSystem => 'This device and Bluetooth';

  String get autoMixCrossfading => 'Crossfade';

  String get autoMixMixing => 'Mixing';

  String get autoMixOff => 'AutoMix off';

  String get autoMixOn => 'AutoMix on';

  String get autoplayFromLibrary => 'Autoplay from your Library';

  String get autoplayOff => 'Autoplay off';

  String get autoplayOn => 'Autoplay on';

  String get confirmLoudVolumeContinue => 'Continue';

  String confirmLoudVolumeMessage(Object level) => 'Volume above ${level} may hurt your hearing. Do you want to continue?';

  String get confirmLoudVolumeTitle => 'Turn the volume up?';

  String get dapExclusiveUnavailable => 'AAudio exclusive access is unavailable for this track and current output. Using normal playback. For a USB DAC, try the direct USB driver.';

  String get dialogCancel => 'Cancel';

  String get dialogDiscard => 'Discard';

  String get dialogDiscardChanges => 'Discard Changes?';

  String get dialogRemove => 'Remove';

  String get dialogSave => 'Save';

  String get dialogUnsavedChanges => 'You have unsaved changes. Do you want to discard them?';

  String get equalizerCompressor => 'Compressor';

  String get equalizerPreamp => 'Preamp';

  String get equalizerTitle => 'Equalizer';

  String get libraryPlaybackNormalization => 'Volume normalization';

  String get linkFileReading => 'Reading tags...';

  String get lyricsEditAddLine => 'Add line';

  String get lyricsEditDeleteLine => 'Delete line';

  String get lyricsEditEarlier => '−0.1';

  String get lyricsEditEarlierTooltip => 'Move 0.1 s earlier';

  String get lyricsEditInsertBelow => 'Insert line below';

  String get lyricsEditLater => '+0.1';

  String get lyricsEditLaterTooltip => 'Move 0.1 s later';

  String get lyricsEditLineActions => 'Line actions';

  String get lyricsEditLineHint => 'Lyric line';

  String get lyricsEditNoTime => 'No time';

  String get lyricsEditOutOfOrder => 'Earlier than the line before it';

  String lyricsEditPlayFrom(Object time) => 'Play from ${time}';

  String get lyricsEditReadOnly => 'Lyrics can\'t be saved to this song\'s file';

  String get lyricsEditRemoveTime => 'Remove time';

  String get lyricsEditSaveFailed => 'Couldn\'t save the lyrics to this file';

  String get lyricsEditSaved => 'Lyrics saved';

  String get lyricsEditSetTime => 'Set time';

  String get lyricsEditSetTimeTooltip => 'Give the selected line the current position';

  String get lyricsEditTitle => 'Edit lyrics';

  String get lyricsEditWrite => 'Write lyrics';

  String get metadataExplicitValue => 'Explicit';

  String get mornyeContinuePlaying => 'Continue Playing';

  String get nowPlayingAudioOutput => 'Audio Output';

  String get nowPlayingAudioOutputUnavailable => 'Unable to open audio output settings.';

  String get nowPlayingInstrumental => 'Instrumental';

  String nowPlayingLyricsProvider(Object provider) => 'Lyrics: ${provider}';

  String get nowPlayingMinimize => 'Minimize';

  String get nowPlayingNextTrack => 'Next track';

  String get nowPlayingNoLyrics => 'No lyrics in this file';

  String get nowPlayingNoLyricsOnline => 'No lyrics found online';

  String get nowPlayingPlayInOrder => 'Play in order';

  String get nowPlayingPreviousTrack => 'Previous track';

  String get nowPlayingQueueEmpty => 'Queue is empty';

  String get nowPlayingRepeatAll => 'Repeat all';

  String get nowPlayingRepeatOff => 'Repeat off';

  String get nowPlayingRepeatOne => 'Repeat one';

  String get nowPlayingSearchLyricsOnline => 'Search online';

  String get nowPlayingShuffleOn => 'Shuffle on';

  String get nowPlayingTabLyrics => 'Lyrics';

  String get nowPlayingTabPlayer => 'Player';

  String get nowPlayingUpNext => 'Up next';

  String get nowPlayingVolume => 'Volume';

  String nowPlayingWrittenBy(Object writers) => 'Written by: ${writers}';

  String get offlinePlayingLocal => 'Playing from this device';

  String offlineStreaming(Object server) => 'Streaming from ${server}';

  String get playbackTempoKeepPitch => 'Keep pitch';

  String get playbackTempoKeepPitchDescription => 'Off lets the pitch follow the speed, like a record played faster or slower';

  String get playbackTempoPitch => 'Pitch';

  String get playbackTempoPitchFollows => 'Pitch follows speed';

  String get playbackTempoReset => 'Reset';

  String get playbackTempoSpeed => 'Speed';

  String get playbackTempoSpeedOnly => 'Only the speed can change on this output; the pitch stays as recorded.';

  String playbackTempoSpeedValue(Object speed) => '${speed}x';

  String get playbackTempoTitle => 'Speed and pitch';

  String get playbackTempoUnavailable => 'The audio doesn\'t pass through the app on this output, for example while casting or with direct USB output, so speed and pitch can\'t change.';

  String get queueAutoMix => 'AutoMix';

  String get queueAutoplay => 'Autoplay';

  String get queueLock => 'Lock queue';

  String get queueUnlock => 'Unlock queue';

  String get snackbarAddedToQueueGeneric => 'Added to queue';

  String snackbarCannotOpenFile(Object error) => 'Cannot open file: ${error}';

  String snackbarError(Object error) => 'Error: ${error}';

  String get snackbarFailedToEmbedLyrics => 'Failed to embed lyrics';

  String get snackbarPlayingNext => 'Playing next';

  String get tooltipPlay => 'Play';

  String get trackAddToQueue => 'Add to queue';

  String get trackLyrics => 'Lyrics';

  String get trackOptionAddToLoved => 'Add to Loved';

  String get trackOptionRemoveFromLoved => 'Remove from Loved';

  String get trackPlayNext => 'Play next';

  String get usbAndroidVersion => 'Bit-perfect USB output needs Android 14 or later. Try the direct USB driver. Using normal playback.';

  String get usbBitPerfect => 'Hi-res and bit-perfect audio';

  String get usbBitPerfectFallback => 'This device or audio format does not support bit-perfect output. Using normal playback.';

  String get usbBitPerfectNoDevice => 'No USB DAC connected. Using normal audio output.';

  String get usbBitPerfectPending => 'Waiting for the next track and a compatible USB output.';

  String get usbBitPerfectRouteChanged => 'The USB audio route changed. Playback paused; select a track to reconnect.';

  String usbChannelsUnsupported(Object channels) => 'This song has ${channels} channels. Direct DAC output plays mono and stereo only. Using normal playback.';

  String usbDacFormatRejected(Object format) => 'The DAC refused ${format}. Using normal playback.';

  String get usbDacFormatRejectedGeneric => 'The DAC refused this song\'s format. Using normal playback.';

  String get usbDacOpenFailed => 'Could not open the DAC. Another app may be using it. Using normal playback.';

  String get usbDacUnsupported => 'This DAC does not work with the direct USB driver yet. Using normal playback.';

  String get usbDecodeFailed => 'This song stopped decoding during direct playback. Playback paused; select a track to continue.';

  String usbDecoderUnavailable(Object codec) => 'This phone has no ${codec} decoder for direct DAC output. Using normal playback.';

  String get usbDsdUnsupported => 'This DSD format or connected DAC is not supported. Playback stopped.';

  String usbFormatMono(Object format) => 'mono ${format}';

  String usbFormatUnsupported(Object format) => 'This song\'s format (${format}) cannot be sent directly to the DAC yet. Using normal playback.';

  String get usbFormatUnsupportedGeneric => 'This song\'s format cannot be sent directly to the DAC yet. Using normal playback.';

  String get usbHardwareVolume => 'DAC hardware volume';

  String get usbOutputCancelled => 'USB preparation was cancelled. Select a track to try again.';

  String usbOutputLossySource(Object codec) => '${codec}, lossy source';

  String get usbOutputPreparing => 'Preparing USB audio output...';

  String get usbOutputReady => 'USB output is ready. Start playback to activate it.';

  String usbOutputResampled(Object rate, Object output) => '${rate}, resampled to ${output}';

  String get usbPermissionDeclined => 'USB access was declined. Turn the Direct USB driver off and on, or plug the DAC in again, to be asked again. Using normal playback.';

  String get usbPermissionDenied => 'USB permission was not granted. Using normal playback.';

  String get usbPrepareTimeout => 'The song took too long to start on the DAC. Using normal playback.';

  String get usbVolumeUnavailable => 'Playback is paused because this DAC has no verified hardware volume control. Lower the DAC or amplifier volume, then enable fixed-volume output if needed and select the track again.';

  String audioInfoChannelCount(num count) {
    final n = count.toInt();
    if (n == 1) return 'Mono';
    if (n == 2) return 'Stereo';
    return '$n channels';
  }

  String audioInfoDeviceType(Object type) {
    switch (type.toString()) {
      case 'speaker':
        return 'Phone speaker';
      case 'earpiece':
        return 'Earpiece';
      case 'wired_headphones':
        return 'Wired headphones';
      case 'wired_headset':
        return 'Wired headset';
      case 'line':
        return 'Line out';
      case 'bluetooth':
        return 'Bluetooth';
      case 'bluetooth_le':
        return 'Bluetooth LE Audio';
      case 'usb':
        return 'USB audio';
      case 'usb_headset':
        return 'USB headset';
      case 'hdmi':
        return 'HDMI';
      case 'dock':
        return 'Dock';
      case 'cast':
        return 'Cast';
      case 'hearing_aid':
        return 'Hearing aid';
      case 'airplay':
        return 'AirPlay';
      case 'car':
        return 'Car audio';
      default:
        return 'Other';
    }
  }

  String playbackTempoSemitones(num count, Object value) {
    final n = count.toInt();
    if (n == 1) return '$value semitone';
    return '$value semitones';
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale.toLanguageTag());

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// The player's strings, for a `MaterialApp` that also registers FluentMusic's
/// own delegate.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
];

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String friendlyError(
    Object? error, {
    String fallback = defaultUserFacingErrorMessage,
  }) => userFacingErrorMessage(error, fallback: fallback);
}
