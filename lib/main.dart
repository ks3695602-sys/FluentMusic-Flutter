import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inspire_blur/inspire_blur.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'core/audio/audio_handler.dart';
import 'core/storage/preferences_service.dart';
import 'core/theme/liquid_glass_theme.dart';
import 'ui/screens/main_scaffold.dart';

late final FluentAudioHandler globalAudioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge to Edge Transparent System Bars (OLED Full Immersive)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize Glass & Shader Pipeline (Non-blocking async disk-to-RAM pre-warm)
  try {
    await LiquidGlassWidgets.initialize();
  } catch (e) {
    debugPrint('[Main] LiquidGlassWidgets init: $e');
  }

  try {
    Inspire.warmUp();
  } catch (e) {
    debugPrint('[Main] Inspire warmUp: $e');
  }

  // Initialize Local Preferences
  await PreferencesService().init();

  // Initialize Background Audio Service
  globalAudioHandler = await AudioService.init(
    builder: () => FluentAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.fluentmusic.app.audio',
      androidNotificationChannelName: 'FluentMusic Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
      notificationColor: Color(0xFFFA2D48), // Apple Red
    ),
  );

  runApp(
    LiquidGlassWidgets.wrap(
      adaptiveQuality: true,
      respectSystemAccessibility: true,
      brightnessResolver: Theme.maybeBrightnessOf,
      theme: GlassThemeData.simple(
        blur: 16,
        thickness: 28,
        quality: GlassQuality.standard,
      ),
      child: const ProviderScope(child: FluentMusicApp()),
    ),
  );
}

class FluentMusicApp extends StatelessWidget {
  const FluentMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FluentMusic',
      debugShowCheckedModeBanner: false,
      theme: LiquidGlassTheme.darkTheme,
      home: MainScaffold(audioHandler: globalAudioHandler),
    );
  }
}
