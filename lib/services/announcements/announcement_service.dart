/*
 *     Copyright (C) 2026 jaypakash sahu
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:musify/services/settings_manager.dart';

const String announcementUrl =
    'https://raw.githubusercontent.com/ks3695602-sys/FluentMusic-Flutter/main/check.json';

/// Reads only the optional announcement banner from `check.json`.
///
/// Update checks deliberately do not use this file any more: releases come
/// from the GitHub Releases API. Keeping announcements separate means a stale
/// or broken `check.json` can never block an update prompt.
Future<void> fetchAnnouncementOnly() async {
  try {
    final response = await http
        .get(Uri.parse(announcementUrl))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return;

    final map = json.decode(response.body);
    if (map is! Map<String, dynamic>) return;
    final announcement = map['announcementurl'];
    if (announcement != null) {
      announcementURL.value = announcement.toString();
    }
  } catch (error) {
    debugPrint('[Announcements] Could not load announcement: $error');
  }
}
