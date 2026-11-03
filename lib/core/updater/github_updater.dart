import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String tagName;
  final String releaseName;
  final String body;
  final String apkDownloadUrl;
  final bool hasUpdate;

  const UpdateInfo({
    required this.tagName,
    required this.releaseName,
    required this.body,
    required this.apkDownloadUrl,
    required this.hasUpdate,
  });
}

class GithubUpdater {
  static const String currentVersion = 'v1.0.9-flutter';
  static const String repoOwner = 'ks3695602-sys';
  static const String repoName = 'FluentMusic-Flutter';

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final url = Uri.parse(
          'https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final res = await http.get(url, headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'FluentMusic-App',
      }).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final tagName = data['tag_name'] as String? ?? '';
        final releaseName = data['name'] as String? ?? '';
        final body = data['body'] as String? ?? '';

        String apkUrl = '';
        final assets = data['assets'] as List<dynamic>? ?? [];
        for (final a in assets) {
          final assetName = a['name'] as String? ?? '';
          if (assetName.endsWith('.apk')) {
            apkUrl = a['browser_download_url'] as String? ?? '';
            break;
          }
        }

        final bool hasUpdate = tagName.isNotEmpty && tagName != currentVersion;
        return UpdateInfo(
          tagName: tagName,
          releaseName: releaseName,
          body: body,
          apkDownloadUrl: apkUrl,
          hasUpdate: hasUpdate,
        );
      }
    } catch (e) {
      debugPrint('[GithubUpdater] Update check failed: $e');
    }
    return null;
  }
}
