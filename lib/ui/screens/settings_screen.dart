import 'package:flutter/material.dart';
import '../../core/storage/preferences_service.dart';
import '../../core/updater/github_updater.dart';
import '../widgets/liquid_glass_container.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PreferencesService _prefs = PreferencesService();
  bool _isCheckingUpdate = false;
  String _updateStatus = '';

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
          _updateStatus = 'Failed to check updates. Check internet.';
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            // Title
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Liquid Glass Studio Header
            const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: Color(0xFF00CEC9), size: 20),
                SizedBox(width: 8),
                Text(
                  'Liquid Glass Studio',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Liquid Glass Studio Sliders Card
            LiquidGlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              tintColor: Colors.white.withValues(alpha: 0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Blur Radius
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Blur Intensity', style: TextStyle(color: Colors.white)),
                      Text('${_prefs.blurRadius.toStringAsFixed(1)} px',
                          style: const TextStyle(color: Color(0xFF00CEC9), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _prefs.blurRadius,
                    min: 5.0,
                    max: 45.0,
                    activeColor: const Color(0xFF00CEC9),
                    onChanged: (val) => _prefs.setBlurRadius(val),
                  ),
                  const Divider(color: Colors.white10),

                  // Refraction Index
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Refraction Index', style: TextStyle(color: Colors.white)),
                      Text('${_prefs.refractionIndex.toStringAsFixed(2)}x',
                          style: const TextStyle(color: Color(0xFF00CEC9), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _prefs.refractionIndex,
                    min: 1.0,
                    max: 1.4,
                    activeColor: const Color(0xFF00CEC9),
                    onChanged: (val) => _prefs.setRefractionIndex(val),
                  ),
                  const Divider(color: Colors.white10),

                  // Tint Opacity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Glass Tint Opacity', style: TextStyle(color: Colors.white)),
                      Text('${(_prefs.tintOpacity * 100).toInt()}%',
                          style: const TextStyle(color: Color(0xFF00CEC9), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _prefs.tintOpacity,
                    min: 0.05,
                    max: 0.60,
                    activeColor: const Color(0xFF00CEC9),
                    onChanged: (val) => _prefs.setTintOpacity(val),
                  ),
                  const Divider(color: Colors.white10),

                  // Chromatic Aberration Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Edge Chromatic Aberration', style: TextStyle(color: Colors.white)),
                    subtitle: Text('Simulate optical glass prism edges',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    value: _prefs.enableChromaticAberration,
                    activeColor: const Color(0xFF00CEC9),
                    onChanged: (val) => _prefs.setChromaticAberration(val),
                  ),

                  // Animated Mesh Background
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dynamic Mesh Canvas', style: TextStyle(color: Colors.white)),
                    subtitle: Text('Fluid animated backdrop responding to music',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    value: _prefs.enableMeshBackground,
                    activeColor: const Color(0xFF00CEC9),
                    onChanged: (val) => _prefs.setMeshBackground(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Audio & Stream Quality
            const Text(
              'Audio Streaming',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            LiquidGlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              tintColor: Colors.white.withValues(alpha: 0.08),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.high_quality_rounded, color: Color(0xFF6C5CE7)),
                    title: const Text('Streaming Bitrate', style: TextStyle(color: Colors.white)),
                    subtitle: Text(_prefs.audioQuality,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                    trailing: DropdownButton<String>(
                      value: _prefs.audioQuality,
                      dropdownColor: const Color(0xFF1E2130),
                      style: const TextStyle(color: Colors.white),
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'High (160k Opus)', child: Text('160k Opus')),
                        DropdownMenuItem(value: 'Very High (256k AAC)', child: Text('256k AAC')),
                        DropdownMenuItem(value: 'Standard (128k)', child: Text('128k Standard')),
                      ],
                      onChanged: (val) {
                        if (val != null) _prefs.setAudioQuality(val);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // GitHub In-App Updater
            const Text(
              'Updates & About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            LiquidGlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              tintColor: Colors.white.withValues(alpha: 0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FluentMusic',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Version 1.0.9-flutter (Universal)',
                              style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: _isCheckingUpdate
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.system_update_rounded, size: 16),
                        label: const Text('Check Update'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isCheckingUpdate ? null : _checkForUpdates,
                      ),
                    ],
                  ),
                  if (_updateStatus.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _updateStatus,
                      style: TextStyle(
                        color: _updateStatus.contains('available')
                            ? const Color(0xFF00CEC9)
                            : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
