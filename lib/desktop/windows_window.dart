/*
 *     Copyright (C) 2026 jaypakash sahu
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, Colors, Size;
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:window_manager/legacy.dart' as wm;

bool get isWindowsDesktop =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

bool? _appliedDark;

/// Prepares the Windows window before the first Flutter frame: transparent
/// client area, custom caption (traffic lights live in the sidebar), and a
/// native DWM material underneath the Flutter scene.
Future<void> initializeDesktopWindow({required bool dark}) async {
  if (!isWindowsDesktop) return;

  try {
    await Window.initialize();
  } catch (error) {
    debugPrint('[Desktop] flutter_acrylic init failed: $error');
  }

  await wm.windowManager.ensureInitialized();

  const options = wm.WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(960, 640),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    title: 'FluentMusic',
    titleBarStyle: wm.TitleBarStyle.hidden,
  );

  await wm.windowManager.waitUntilReadyToShow(options, () async {
    await wm.windowManager.show();
    await wm.windowManager.focus();
  });

  try {
    await Window.hideWindowControls();
  } catch (error) {
    debugPrint('[Desktop] Could not hide native window controls: $error');
  }

  await applyDesktopWindowMaterial(dark: dark);
}

/// Applies Mica on Windows 11, Acrylic on Windows 10, and a solid tint when
/// neither composition effect is available.
Future<void> applyDesktopWindowMaterial({required bool dark}) async {
  if (!isWindowsDesktop || _appliedDark == dark) return;
  _appliedDark = dark;

  final tint = dark ? const Color(0xCC0B0B0F) : const Color(0xCCF4F1FA);

  for (final effect in const [
    WindowEffect.mica,
    WindowEffect.acrylic,
    WindowEffect.solid,
  ]) {
    try {
      await Window.setEffect(effect: effect, color: tint, dark: dark);
      return;
    } catch (error) {
      debugPrint('[Desktop] Window effect $effect unavailable: $error');
    }
  }
}

Future<void> startWindowDrag() async {
  if (!isWindowsDesktop) return;
  await wm.windowManager.startDragging();
}

Future<void> minimizeWindow() async {
  if (!isWindowsDesktop) return;
  await wm.windowManager.minimize();
}

Future<void> toggleMaximizeWindow() async {
  if (!isWindowsDesktop) return;
  if (await wm.windowManager.isMaximized()) {
    await wm.windowManager.unmaximize();
  } else {
    await wm.windowManager.maximize();
  }
}

Future<void> closeWindow() async {
  if (!isWindowsDesktop) return;
  await wm.windowManager.close();
}
