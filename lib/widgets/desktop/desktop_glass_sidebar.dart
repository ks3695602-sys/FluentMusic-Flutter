/*
 *     Copyright (C) 2026 jaypakash sahu
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Divider, Tooltip;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:musify/desktop/windows_window.dart';

class DesktopNavItem {
  const DesktopNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;
}

/// macOS 27 inspired floating sidebar. It deliberately sits above the Mica
/// window as a glass platter instead of hugging the window edges, and keeps
/// all the mobile pages untouched in the content area.
class DesktopGlassSidebar extends StatefulWidget {
  const DesktopGlassSidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.isDark,
    super.key,
  });

  final List<DesktopNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool isDark;

  @override
  State<DesktopGlassSidebar> createState() => _DesktopGlassSidebarState();
}

class _DesktopGlassSidebarState extends State<DesktopGlassSidebar> {
  bool _userCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final autoCollapsed = MediaQuery.sizeOf(context).width < 1100;
    final collapsed = _userCollapsed || autoCollapsed;
    final width = collapsed ? 78.0 : 248.0;
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1C1C1E);
    final mutedColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.45);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: width,
        child: GlassContainer(
          useOwnLayer: true,
          shape: const LiquidRoundedSuperellipse(borderRadius: 22),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTitleBar(collapsed),
                if (!collapsed) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 2, 18, 14),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/appicon_rounded.png',
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox(width: 30, height: 30),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'FluentMusic',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: collapsed ? 12 : 12,
                    ),
                    children: [
                      for (final item in widget.items)
                        _DesktopNavTile(
                          item: item,
                          selected: item.index == widget.selectedIndex,
                          collapsed: collapsed,
                          isDark: widget.isDark,
                          onTap: () => widget.onSelect(item.index),
                        ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 14,
                  endIndent: 14,
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                _SidebarFooter(
                  collapsed: collapsed,
                  isDark: widget.isDark,
                  mutedColor: mutedColor,
                  onToggle: () =>
                      setState(() => _userCollapsed = !_userCollapsed),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(bool collapsed) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          const SizedBox(width: 14),
          _TrafficLight(
            color: const Color(0xFFFF5F57),
            tooltip: 'Close',
            onTap: closeWindow,
          ),
          const SizedBox(width: 7),
          _TrafficLight(
            color: const Color(0xFFFEBC2E),
            tooltip: 'Minimize',
            onTap: minimizeWindow,
          ),
          const SizedBox(width: 7),
          _TrafficLight(
            color: const Color(0xFF28C840),
            tooltip: 'Maximize',
            onTap: toggleMaximizeWindow,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => startWindowDrag(),
              onDoubleTap: toggleMaximizeWindow,
              child: const SizedBox.expand(),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'FluentMusic',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesktopNavTile extends StatefulWidget {
  const _DesktopNavTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.isDark,
    required this.onTap,
  });

  final DesktopNavItem item;
  final bool selected;
  final bool collapsed;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_DesktopNavTile> createState() => _DesktopNavTileState();
}

class _DesktopNavTileState extends State<_DesktopNavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFFF2D55);
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1C1C1E);
    final selectedFill = accent.withValues(alpha: widget.isDark ? 0.20 : 0.14);
    final hoverFill = widget.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: EdgeInsets.symmetric(
        horizontal: widget.collapsed ? 0 : 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: widget.selected
            ? selectedFill
            : (_hovered ? hoverFill : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        border: widget.selected
            ? Border.all(color: accent.withValues(alpha: 0.28), width: 0.8)
            : null,
      ),
      child: Row(
        mainAxisAlignment: widget.collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Icon(
            widget.selected ? widget.item.selectedIcon : widget.item.icon,
            size: 20,
            color: widget.selected ? accent : textColor.withValues(alpha: 0.8),
          ),
          if (!widget.collapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (widget.selected)
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.collapsed
            ? Tooltip(
                message: widget.item.label,
                waitDuration: const Duration(milliseconds: 400),
                child: content,
              )
            : content,
      ),
    );
  }
}

class _TrafficLight extends StatelessWidget {
  const _TrafficLight({
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final Color color;
  final String tooltip;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.collapsed,
    required this.isDark,
    required this.mutedColor,
    required this.onToggle,
  });

  final bool collapsed;
  final bool isDark;
  final Color mutedColor;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: [
          if (!collapsed)
            Text(
              'v1.5.4',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: mutedColor,
              ),
            ),
          Tooltip(
            message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
            child: GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  collapsed
                      ? CupertinoIcons.chevron_right
                      : CupertinoIcons.chevron_left,
                  size: 15,
                  color: mutedColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
