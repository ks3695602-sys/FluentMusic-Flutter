import 'package:flutter/material.dart';
import '../../core/audio/audio_handler.dart';
import '../widgets/liquid_glass_container.dart';
import '../widgets/mini_player_bar.dart';
import 'home_screen.dart';
import 'new_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class MainScaffold extends StatefulWidget {
  final FluentAudioHandler audioHandler;

  const MainScaffold({super.key, required this.audioHandler});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with SingleTickerProviderStateMixin {
  int _currentNavIndex = 0;
  late TabController _dualHomeTabController;

  @override
  void initState() {
    super.initState();
    _dualHomeTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _dualHomeTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Main Body Content
          SafeArea(
            bottom: false,
            child: _buildCurrentBody(),
          ),

          // Mini Player + Floating Bottom Bar Stack
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mini Player
                  MiniPlayerBar(audioHandler: widget.audioHandler),

                  // Floating Liquid Glass Navigation Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: LiquidGlassContainer(
                      borderRadius: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      tintColor: const Color(0xFF13151F).withValues(alpha: 0.75),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(0, Icons.music_note_rounded, 'Discover'),
                          _buildNavItem(1, Icons.search_rounded, 'Search'),
                          _buildNavItem(2, Icons.library_music_rounded, 'Library'),
                          _buildNavItem(3, Icons.tune_rounded, 'Settings'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBody() {
    switch (_currentNavIndex) {
      case 0:
        // Dual-Home Screen with Home + New Tabs
        return Column(
          children: [
            // Dual-Home Segmented Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white12),
                ),
                child: TabBar(
                  controller: _dualHomeTabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Home'),
                    Tab(text: 'New Releases'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _dualHomeTabController,
                children: [
                  HomeScreen(audioHandler: widget.audioHandler),
                  NewScreen(audioHandler: widget.audioHandler),
                ],
              ),
            ),
          ],
        );
      case 1:
        return SearchScreen(audioHandler: widget.audioHandler);
      case 2:
        return LibraryScreen(audioHandler: widget.audioHandler);
      case 3:
        return const SettingsScreen();
      default:
        return HomeScreen(audioHandler: widget.audioHandler);
    }
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00CEC9) : Colors.white60,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
