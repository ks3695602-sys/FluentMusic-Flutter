import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/mornye_player/services/music_playback_deck.dart';

final usbVolumeProvider = StreamProvider.autoDispose<UsbVolumeState?>((ref) {
  final events = StreamController<UsbVolumeState?>();
  void changed() => events.add(usbHardwareVolume.value);
  usbHardwareVolume.addListener(changed);
  changed();
  ref.onDispose(() {
    usbHardwareVolume.removeListener(changed);
    unawaited(events.close());
  });
  return events.stream;
});

/// A single shared subscription for the visible player, including hardware
/// volume-button changes. This controls the player's own output volume.
final systemVolumeProvider = StreamProvider.autoDispose<double>(
  (ref) => audioHandler.volumeStream,
);

final systemVolumeWriterProvider = Provider<Future<void> Function(double)>((
  ref,
) {
  return (value) => audioHandler.setVolume(value.clamp(0.0, 1.0));
});