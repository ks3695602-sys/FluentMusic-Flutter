import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Mornye's logging front end, kept so the copied player code does not change.
///
/// FluentMusic does not ship Mornye's file-backed log buffer or the
/// `logger`/`device_info_plus` dependencies: every level writes through
/// Flutter's own debug logging, which the release build compiles away.
class AppLogger {
  AppLogger(this._tag);

  final String _tag;

  void d(String message) {
    if (kDebugMode) debugPrint('[$_tag] $message');
  }

  void i(String message) {
    if (kDebugMode) debugPrint('[$_tag] $message');
  }

  void w(String message) {
    debugPrint('[$_tag] WARN: $message');
  }

  void e(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[$_tag] ERROR: $message');
    if (error != null) debugPrint('[$_tag] ERROR: $error');
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}

/// The renderer line of a log export. Only Impeller supports shader image
/// filters, so their support tells Impeller from Skia.
String rendererDiagnosticLine({bool? shaderFilters}) {
  final impeller = shaderFilters ?? ui.ImageFilter.isShaderFilterSupported;
  return impeller
      ? 'Renderer: Impeller (shader filters supported)'
      : 'Renderer: Skia (no shader filters)';
}