import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/audio/audio_handler.dart';
import '../widgets/mini_player_bar.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainScaffold extends StatefulWidget {
  final FluentAudioHandler audioHandler;

  const MainScaffold({super.key, required this.audioHandler});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentNavIndex = 0;
  bool _isSearchActive = false;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      // Pure OLED Black background (SKILL.md Rule 1: Glass is a platter, not a wallpaper)
      background: const ColoredBox(color: Colors.black),
      contentAwareBrightness: true,

      // Floating Bottom Platter Layer
      bottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Floating MiniPlayer Platter
              MiniPlayerBar(audioHandler: widget.audioHandler),
              const SizedBox(height: 8),

              // Floating Capsule Dock + Detached Circular Search Bubble (Image 2 & 4)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Main 3-Tab Floating Glass Capsule
                  Expanded(
                    child: GlassTabBar.bottom(
                      selectedIndex: _isSearchActive ? -1 : _currentNavIndex,
                      onTabSelected: (index) {
                        setState(() {
                          _isSearchActive = false;
                          _currentNavIndex = index;
                        });
                      },
                      tabs: const [
                        GlassTab(
                          icon: Icon(CupertinoIcons.house_fill),
                          label: 'Home',
                        ),
                        GlassTab(
                          icon: Icon(CupertinoIcons.music_albums_fill),
                          label: 'Library',
                        ),
                        GlassTab(
                          icon: Icon(CupertinoIcons.gear_alt_fill),
                          label: 'Settings',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Standalone Detached Circular Search Lens Bubble (Image 2)
                  GlassIconButton(
                    icon: Icon(
                      CupertinoIcons.search,
                      color: _isSearchActive
                          ? const Color(0xFFFA2D48)
                          : Colors.white.withOpacity(0.9),
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearchActive = !_isSearchActive;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // Scrollable Body Content
      body: _buildCurrentBody(),
    );
  }

  Widget _buildCurrentBody() {
    if (_isSearchActive) {
      return SearchScreen(audioHandler: widget.audioHandler);
    }

    switch (_currentNavIndex) {
      case 0:
        return HomeScreen(audioHandler: widget.audioHandler);
      case 1:
        return LibraryScreen(audioHandler: widget.audioHandler);
      case 2:
        return const SettingsScreen();
      default:
        return HomeScreen(audioHandler: widget.audioHandler);
    }
  }
}
