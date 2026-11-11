/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide ColorScheme;
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart'
    show closeCurrentBottomSheet;
import 'package:musify/widgets/mini_player.dart';

class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({required this.child, super.key});

  final StatefulNavigationShell child;

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {
  late final _miniPlayerVisibilityStream = audioHandler.mediaItem
      .map((mediaItem) => mediaItem != null)
      .distinct();

  bool? _previousOfflineMode;

  /// Track the previously selected shell branch to detect reselects.
  int? _previousShellIndex;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.child.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final currentIndex = widget.child.currentIndex;
        if (currentIndex != 0) {
          widget.child.goBranch(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: offlineMode,
        builder: (context, isOfflineMode, _) {
          if (_previousOfflineMode != null &&
              _previousOfflineMode != isOfflineMode) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              _handleOfflineModeChange(isOfflineMode);
            });
          }
          _previousOfflineMode = isOfflineMode;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = MediaQuery.of(context).size.width >= 600;
              final items = _getNavigationItems(isOfflineMode);

              final isLight = Theme.of(context).brightness == Brightness.light;

              return GlassScaffold(
                contentAwareBrightness: true,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isLight
                          ? const [
                              Color(0xFFF7F7F9),
                              Color(0xFFEBEBF0),
                              Color(0xFFFFFFFF),
                            ]
                          : const [
                              Color(0xFF160E1A),
                              Color(0xFF0A070D),
                              Color(0xFF000000),
                            ],
                    ),
                  ),
                ),
                body: SafeArea(
                  child: Row(
                    children: [
                      if (isLargeScreen)
                        NavigationRail(
                          labelType: NavigationRailLabelType.selected,
                          destinations: items
                              .map(
                                (item) => NavigationRailDestination(
                                  icon: Icon(item.icon),
                                  selectedIcon: Icon(item.selectedIcon),
                                  label: Text(item.label),
                                ),
                              )
                              .toList(),
                          selectedIndex: _getCurrentIndex(items, isOfflineMode),
                          onDestinationSelected: (index) =>
                              _onTabTapped(index, items),
                        ),
                      Expanded(
                        child: widget.child,
                      ),
                    ],
                  ),
                ),
                bottomBar: !isLargeScreen
                    ? StreamBuilder<bool>(
                        initialData: audioHandler.mediaItem.value != null,
                        stream: _miniPlayerVisibilityStream,
                        builder: (context, snapshot) {
                          final isMiniPlayerVisible = snapshot.data ?? false;
                          final isSearching = widget.child.currentIndex == 1;

                          return GlassTabBar.searchable(
                            isSearchActive: isSearching,
                            selectedIndex:
                                _getCurrentIndex(items, isOfflineMode),
                            onTabSelected: (index) {
                              _onTabTapped(index, items);
                            },
                            tabs: items
                                .map(
                                  (item) => GlassTab(
                                    icon: Icon(item.icon),
                                    activeIcon: Icon(item.selectedIcon),
                                    label: item.label,
                                  ),
                                )
                                .toList(),
                            barHeight: 64.0,
                            searchBarHeight: 50.0,
                            horizontalPadding: 16.0,
                            verticalPadding: 12.0,
                            spacing: 8.0,
                            bottomAccessory: isMiniPlayerVisible
                                ? const MiniPlayer()
                                : null,
                            bottomAccessoryHeight: 56.0,
                            bottomAccessoryEnabled: isMiniPlayerVisible,
                            bottomAccessoryPlacement:
                                GlassTabBarAccessoryPlacement.expanded,
                            selectedIconColor: const Color(0xFFFF2D55),
                            unselectedIconColor: isLight
                                ? CupertinoColors.black.withValues(alpha: 0.65)
                                : CupertinoColors.white.withValues(alpha: 0.85),
                            labelFontSize: 10,
                            iconSize: 26,
                            iconLabelSpacing: 0,
                            quality: GlassQuality.premium,
                            interactionBehavior: GlassInteractionBehavior.full,
                            searchConfig: GlassSearchBarConfig(
                              expandWhenActive: false,
                              hintText: context.l10n?.search ?? 'Search',
                              onSearchToggle: (active) {
                                if (active && !isOfflineMode) {
                                  closeCurrentBottomSheet();
                                  widget.child.goBranch(1);
                                } else if (!active &&
                                    widget.child.currentIndex == 1) {
                                  widget.child.goBranch(0);
                                }
                              },
                              searchIconColor: CupertinoColors.white
                                  .withValues(alpha: 0.9),
                            ),
                          );
                        },
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  List<_NavigationItem> _getNavigationItems(bool isOfflineMode) {
    final items = <_NavigationItem>[
      _NavigationItem(
        icon: CupertinoIcons.house,
        selectedIcon: CupertinoIcons.house_fill,
        label: context.l10n?.home ?? 'Home',
        shellIndex: 0,
      ),
      _NavigationItem(
        icon: CupertinoIcons.music_albums,
        selectedIcon: CupertinoIcons.music_albums_fill,
        label: context.l10n?.library ?? 'Library',
        shellIndex: 2,
      ),
      _NavigationItem(
        icon: CupertinoIcons.gear_alt,
        selectedIcon: CupertinoIcons.gear_alt_fill,
        label: context.l10n?.settings ?? 'Settings',
        shellIndex: 3,
      ),
    ];

    return items;
  }

  void _handleOfflineModeChange(bool isOfflineMode) {
    if (!mounted) return;

    final currentRoute = GoRouterState.of(context).matchedLocation;

    // If we're switching to offline mode and currently on search tab
    if (isOfflineMode && currentRoute.startsWith('/search')) {
      // Navigate to home
      widget.child.goBranch(0);
    }
  }

  void _onTabTapped(int index, List<_NavigationItem> items) {
    if (index < items.length) {
      final item = items[index];
      final isReselect = _previousShellIndex == item.shellIndex;

      // Close any open bottom sheet before switching tabs
      closeCurrentBottomSheet();

      // If user taps the same tab again, reset it to initial state.
      // Otherwise, preserve the branch state.
      if (isReselect) {
        widget.child.goBranch(item.shellIndex, initialLocation: true);
      } else {
        widget.child.goBranch(item.shellIndex);
      }

      _previousShellIndex = item.shellIndex;
    }
  }

  int _getCurrentIndex(List<_NavigationItem> items, bool isOfflineMode) {
    final currentShellIndex = widget.child.currentIndex;

    if (items.isEmpty) return 0;

    // Try to find the current shell index in the available items
    final matchedIndex = items.indexWhere(
      (item) => item.shellIndex == currentShellIndex,
    );
    if (matchedIndex != -1) return matchedIndex;

    // If the Search branch (1) is active but Search is hidden in offline mode,
    // fall back to the Home tab.
    if (isOfflineMode && currentShellIndex == 1) return 0;

    // Final fallback: return the first tab to keep UI in a valid state.
    return 0;
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.shellIndex,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int shellIndex;
}
