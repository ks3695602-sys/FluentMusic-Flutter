import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/storage/preferences_service.dart';
import '../../core/updater/github_updater.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PreferencesService _prefs = PreferencesService();
  bool _isCheckingUpdate = false;
  String _updateStatus = '';

  // Settings states
  bool _wordByWordKaraoke = true;
  bool _pureOledBlack = true;
  bool _specularHighlights = true;
  double _blurRadius = 16.0;

  void _checkForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
      _updateStatus = 'Checking GitHub releases...';
    });

    final info = await GithubUpdater.checkForUpdate();
    if (mounted) {
      setState(() {
        _isCheckingUpdate = false;
        if (info == null) {
          _updateStatus = 'Failed to check updates.';
        } else if (info.hasUpdate) {
          _updateStatus = 'New version available: ${info.tagName}!';
        } else {
          _updateStatus = 'You are on the latest version (${GithubUpdater.currentVersion}).';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _prefs,
      builder: (context, _) {
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
          children: [
            // iOS 18 Large Title: "Settings"
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                child: const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Section 1: PLAYBACK & AUDIO ENGINE
            GlassGroupedSection(
              surfaceStyle: GlassSurfaceStyle.solid,
              header: const Text(
                'PLAYBACK & AUDIO ENGINE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54),
              ),
              children: [
                GlassListTile(
                  leading: const Icon(CupertinoIcons.play_circle_fill, color: Color(0xFFFA2D48)),
                  title: const Text('Audio Engine Backend'),
                  subtitle: const Text('Hardware C++ libmpv / media_kit'),
                  trailing: const Text('Active', style: TextStyle(color: Color(0xFFFA2D48), fontWeight: FontWeight.bold)),
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.antenna_radiowaves_left_right, color: Color(0xFFFA2D48)),
                  title: const Text('Streaming Fallback Priority'),
                  subtitle: const Text('YouTube Music ➔ Piped ➔ JioSaavn'),
                  trailing: GlassListTile.chevron,
                  onTap: () {},
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.waveform, color: Color(0xFFFA2D48)),
                  title: const Text('Audio Stream Quality'),
                  subtitle: const Text('High (160kbps Opus / 320kbps MP3)'),
                  trailing: GlassListTile.chevron,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 2: LYRICS ENGINE (FLUTTER_LYRIC)
            GlassGroupedSection(
              surfaceStyle: GlassSurfaceStyle.solid,
              header: const Text(
                'LYRICS ENGINE (FLUTTER_LYRIC)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54),
              ),
              children: [
                GlassListTile(
                  leading: const Icon(CupertinoIcons.quote_bubble_fill, color: Color(0xFFFA2D48)),
                  title: const Text('Primary Lyric Engine'),
                  subtitle: const Text('flutter_lyric (LRC/QRC/YRC parser)'),
                  trailing: const Text('Active', style: TextStyle(color: Color(0xFFFA2D48), fontWeight: FontWeight.bold)),
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.search, color: Color(0xFFFA2D48)),
                  title: const Text('Providers & Scrapers'),
                  subtitle: const Text('Better Lyrics API + YoulyPlus + LRCLIB'),
                  trailing: GlassListTile.chevron,
                  onTap: () {},
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.sparkles, color: Color(0xFFFA2D48)),
                  title: const Text('Word-by-Word Karaoke Bloom'),
                  subtitle: const Text('Smooth real-time syllable text glow'),
                  trailing: GlassSwitch(
                    value: _wordByWordKaraoke,
                    onChanged: (val) => setState(() => _wordByWordKaraoke = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 3: LIQUID GLASS & SHADERS (IOS 26/27)
            GlassGroupedSection(
              surfaceStyle: GlassSurfaceStyle.solid,
              header: const Text(
                'LIQUID GLASS & SHADERS (IOS 26/27)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54),
              ),
              children: [
                GlassListTile(
                  leading: const Icon(CupertinoIcons.layers_fill, color: Color(0xFFFA2D48)),
                  title: const Text('Liquid Glass Material'),
                  subtitle: const Text('iOS 27 Refraction & Chromatic Blur'),
                  trailing: const Text('Impeller Shader', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.sun_max_fill, color: Color(0xFFFA2D48)),
                  title: const Text('Specular Rim Glints'),
                  subtitle: const Text('Analytical dual-rim light highlights'),
                  trailing: GlassSwitch(
                    value: _specularHighlights,
                    onChanged: (val) => setState(() => _specularHighlights = val),
                  ),
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.slider_horizontal_3, color: Color(0xFFFA2D48)),
                  title: const Text('Glass Blur Radius'),
                  subtitle: Text('${_blurRadius.toInt()} px sigma'),
                  trailing: SizedBox(
                    width: 130,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        activeTrackColor: const Color(0xFFFA2D48),
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: _blurRadius,
                        min: 8.0,
                        max: 32.0,
                        onChanged: (val) {
                          setState(() => _blurRadius = val);
                          _prefs.setBlurRadius(val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 4: APPEARANCE
            GlassGroupedSection(
              surfaceStyle: GlassSurfaceStyle.solid,
              header: const Text(
                'APPEARANCE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54),
              ),
              children: [
                GlassListTile(
                  leading: const Icon(CupertinoIcons.paintbrush_fill, color: Color(0xFFFA2D48)),
                  title: const Text('Accent Color'),
                  subtitle: const Text('Apple Music Neon Red (#FA2D48)'),
                  trailing: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFA2D48),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.moon_fill, color: Color(0xFFFA2D48)),
                  title: const Text('Pure OLED Black Mode'),
                  subtitle: const Text('#000000 background for infinite contrast'),
                  trailing: GlassSwitch(
                    value: _pureOledBlack,
                    onChanged: (val) => setState(() => _pureOledBlack = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 5: ABOUT FLUENTMUSIC
            GlassGroupedSection(
              surfaceStyle: GlassSurfaceStyle.solid,
              header: const Text(
                'ABOUT FLUENTMUSIC',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54),
              ),
              children: [
                GlassListTile(
                  leading: const Icon(CupertinoIcons.info_circle_fill, color: Color(0xFFFA2D48)),
                  title: const Text('FluentMusic for Android'),
                  subtitle: const Text('Version 1.1.0-fluent (Architecture: libmpv + liquid_glass)'),
                  trailing: const Text('v1.1.0', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.arrow_clockwise_circle_fill, color: Color(0xFFFA2D48)),
                  title: const Text('Check for Updates'),
                  subtitle: Text(_isCheckingUpdate ? 'Checking...' : (_updateStatus.isNotEmpty ? _updateStatus : 'GitHub Releases')),
                  trailing: _isCheckingUpdate
                      ? const CupertinoActivityIndicator(radius: 10, color: Color(0xFFFA2D48))
                      : GlassListTile.chevron,
                  onTap: _isCheckingUpdate ? null : _checkForUpdates,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
