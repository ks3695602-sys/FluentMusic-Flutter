import 'package:flutter/foundation.dart';

/// Only verified native playback reports active. File metadata alone never
/// does. FluentMusic plays through its own engine, so the status stays idle
/// and the USB rows in the audio info sheet stay hidden.
final usbAudioStatus = ValueNotifier<UsbAudioStatus>(const UsbAudioStatus());

/// Null outside direct USB; an unavailable control must not change phone
/// volume. FluentMusic has no direct USB output.
final usbHardwareVolume = ValueNotifier<UsbVolumeState?>(null);

class UsbVolumeState {
  const UsbVolumeState({
    this.available = false,
    this.minDb = -90,
    this.maxDb = 0,
    this.currentDb = 0,
    this.token = 0,
  });

  factory UsbVolumeState.fromMap(Map<dynamic, dynamic> data) => UsbVolumeState(
    available: data['available'] == true,
    minDb: (data['minDb'] as num?)?.toDouble() ?? -90,
    maxDb: (data['maxDb'] as num?)?.toDouble() ?? 0,
    currentDb: (data['currentDb'] as num?)?.toDouble() ?? 0,
    token: (data['token'] as num?)?.toInt() ?? 0,
  );

  final bool available;
  final double minDb, maxDb, currentDb;
  final int token;

  double get fraction => available && maxDb > minDb
      ? ((currentDb - minDb) / (maxDb - minDb)).clamp(0, 1)
      : 0;
}

Future<void> setUsbHardwareVolume(double fraction) async {}

class UsbAudioStatus {
  const UsbAudioStatus({
    this.reason = 'idle',
    this.device,
    this.sampleRate,
    this.bitDepth,
    this.transport = 'pcm',
    this.driver = 'android',
    this.codec,
    this.lossy = false,
    this.sourceBitDepth,
    this.channels,
    this.outputSampleRate,
  });

  /// A native reply that did not start the output. Keeps the specific
  /// reason and the source or DAC format the label names.
  factory UsbAudioStatus.failure(Map<String, dynamic>? reply) => UsbAudioStatus(
    reason: reply?['reason'] as String? ?? 'unsupported',
    sampleRate: (reply?['sampleRate'] as num?)?.toInt(),
    bitDepth: (reply?['bitDepth'] as num?)?.toInt(),
    codec: reply?['codec'] as String?,
    lossy: reply?['lossy'] == true,
    sourceBitDepth: (reply?['sourceBitDepth'] as num?)?.toInt(),
    channels: (reply?['channels'] as num?)?.toInt(),
  );

  final String reason;
  final String? device;
  final int? sampleRate;

  /// The depth sent to the DAC; for a refused format, the depth asked for.
  final int? bitDepth;
  final String transport;
  final String driver;

  /// The source codec, such as FLAC, ALAC or AAC, when native reports it.
  final String? codec;

  /// A lossy source decoded by the phone.
  final bool lossy;
  final int? sourceBitDepth;
  final int? channels;

  /// The rate sent to the DAC when it refused the song's own [sampleRate].
  final int? outputSampleRate;
}