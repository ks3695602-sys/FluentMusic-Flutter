import 'dart:typed_data';

import 'package:flutter/services.dart';

/// The bridge Mornye uses for its Rust/native helper.
///
/// FluentMusic does not ship that helper. Callers all wrap the native path in
/// a `MissingPluginException` fallback, so throwing here keeps their pure-Dart
/// replacement in charge instead of pretending the helper answered.
class PlatformBridge {
  const PlatformBridge._();

  /// Runs [job] in the native helper. FluentMusic has no native helper, so
  /// this always reports the plugin as missing and the caller falls back.
  static Future<Map<String, dynamic>> runNativeDataJob(
    Map<String, dynamic> job, {
    Uint8List? bytes,
  }) async {
    throw MissingPluginException(
      'Native data job "${job['operation']}" is unavailable',
    );
  }

  /// Stats a Storage Access Framework document. Unavailable outside Mornye's
  /// Android host, so callers treat it as an unreadable file.
  static Future<Map<String, dynamic>> safStat(String path) async {
    throw MissingPluginException('SAF stat is unavailable');
  }

  /// Modification times of SAF documents, keyed by URI. Unavailable here.
  static Future<Map<String, DateTime>> getSafFileModTimes(
    List<String> paths,
  ) async {
    throw MissingPluginException('SAF modification times are unavailable');
  }

  /// Desktop Google Cast calls. FluentMusic ships no Rust sender, so the cast
  /// transport reports the plugin as missing and stays disconnected.
  static Future<Object?> castCall(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    throw MissingPluginException('Cast is unavailable');
  }

  /// Desktop Google Cast session events. No sender, so no events.
  static Stream<Object?> castEvents() => const Stream<Object?>.empty();
}