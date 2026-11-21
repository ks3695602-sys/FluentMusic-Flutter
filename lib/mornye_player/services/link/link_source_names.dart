import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Mornye Link devices behind network sources, by source id.
/// FluentMusic has no Link devices, so the map is always empty and the
/// source's host is shown instead.
final linkSourceNamesProvider = Provider<Map<String, String>>((ref) => const {});

/// The Mornye Link device that serves the `network://` [source], if any.
String? linkSourceName(Map<String, String> names, String? source) {
  if (source == null || !source.startsWith('network://')) return null;
  return names[Uri.tryParse(source)?.host];
}