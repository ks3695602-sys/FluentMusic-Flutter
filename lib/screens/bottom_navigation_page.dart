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
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/search_bridge.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/glass_config_controller.dart';
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

  /// Inline search state driven by [GlassTabBar.searchable].
  bool _isSearchActive = false;
  final TextEditingController _inlineSearchController = TextEditingController();

  @override
  void dispose() {
    _inlineSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.child.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final currentIndex = widget.child.currentIndex;
        if (_isSearchActive) {
          setState(() => _isSearchActive = false);
        }
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
              final glassConfig = GlassConfigScope.of(context).config;

              return GlassScaffold(
                contentAwareBrightness: true,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isLight
                          ? const [
                              Color(0xFFF0EBF8),
                              Color(0xFFF7F7FA),
                              Color(0xFFE8EEF5),
                              Color(0xFFFFFFFF),
                            ]
                          : const [
                              Color(0xFF1F122B),
                              Color(0xFF120D1A),
                              Color(0xFF09070D),
                              Color(0xFF000000),
                            ],
                      stops: const [0.0, 0.35, 0.70, 1.0],
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
                          final searchExpanded = _isSearchActive;

                          return GlassTabBar.searchable(
                            isSearchActive: searchExpanded,
                            selectedIndex:
                                _getCurrentIndex(items, isOfflineMode),
                            onTabSelected: (index) {
                              if (_isSearchActive) {
                                setState(() => _isSearchActive = false);
                              }
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
                            verticalPadding: 8.0,
                            spacing: 8.0,
                            selectedIconColor: const Color(0xFFFF2D55),
                            unselectedIconColor: isLight
                                ? CupertinoColors.black
                                    .withValues(alpha: 0.65)
                                : CupertinoColors.white
                                    .withValues(alpha: 0.85),
                            labelFontSize: 10,
                            iconSize: 26,
                            iconLabelSpacing: 0,
                            quality: GlassQuality.premium,
                            interactionBehavior:
                                GlassInteractionBehavior.full,
                            pressScale: 0.96,
                            adaptiveBrightness: true,
                            barBorderRadius: glassConfig.barRadius ??
                                GlassDefaults.capsuleRadius,
                            indicatorBorderRadius:
                                glassConfig.indicatorRadius,
                            indicatorPinchStrength:
                                glassConfig.pinchStrength,
                            indicatorExpansion: EdgeInsets.symmetric(
                              horizontal: glassConfig.expansionH,
                              vertical: glassConfig.expansionV,
                            ),
                            // The mini-player lives *inside* the bar's accessory
                            // slot. No external GlassBackdropGroup: one glass
                            // layer = no dull composite, no dock overlap.
                            bottomAccessory:
                                isMiniPlayerVisible && !searchExpanded
                                    ? const MiniPlayer()
                                    : null,
                            bottomAccessoryHeight:
                                MiniPlayer.playerHeight + 8,
                            bottomAccessorySpacing: 4,
                            bottomAccessoryPlacement:
                                GlassTabBarAccessoryPlacement.expanded,
                            searchConfig: GlassSearchBarConfig(
                              controller: _inlineSearchController,
                              expandWhenActive: true,
                              showPill: !isOfflineMode,
                              hintText: context.l10n?.search ?? 'Search',
                              textInputAction: TextInputAction.search,
                              onSubmitted: _submitInlineSearch,
                              onSearchToggle: (active) {
                                if (active && isOfflineMode) return;
                                setState(() => _isSearchActive = active);
                                if (active) {
                                  closeCurrentBottomSheet();
                                  if (widget.child.currentIndex != 1) {
                                    widget.child.goBranch(1);
                                  }
                                } else if (widget.child.currentIndex == 1) {
                                  widget.child.goBranch(0);
                                }
                              },
                              searchIconColor: isLight
                                  ? CupertinoColors.black
                                      .withValues(alpha: 0.85)
                                  : CupertinoColors.white
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
      if (!isOfflineMode)
        _NavigationItem(
          icon: CupertinoIcons.search,
          selectedIcon: CupertinoIcons.search,
          label: context.l10n?.search ?? 'Search',
          shellIndex: 1,
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

  /// Sends the inline bar query to [SearchPage] and makes sure its branch is
  /// visible. The bridge keeps the query queued if the branch is cold.
  void _submitInlineSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    InlineSearchBridge.submit(query);
    FocusScope.of(context).unfocus();
    if (widget.child.currentIndex != 1) {
      widget.child.goBranch(1);
    }
  }

  void _handleOfflineModeChange(bool isOfflineMode) {
    if (!mounted) return;

    // Offline mode has no search branch, so collapse the inline field first.
    if (isOfflineMode && _isSearchActive) {
      setState(() => _isSearchActive = false);
    }

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
