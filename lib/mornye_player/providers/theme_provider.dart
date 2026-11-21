import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/mornye_player/models/theme_settings.dart';

/// FluentMusic keeps its own theme. The copied player only reads the lyrics
/// presentation fields, and the defaults (normal text scale, full neighbour
/// blur, no timing offset) match the player's design.
final themeProvider = Provider<ThemeSettings>((ref) => const ThemeSettings());