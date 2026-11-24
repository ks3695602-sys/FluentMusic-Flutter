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
 */

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/services/innertube_client.dart';
import 'package:musify/services/ytmusic_auth_service.dart';

/// Google account sign-in for YouTube Music.
///
/// Mirrors the Kotlin reference:
///   1. wipe the WebView cookie jar so a previous account cannot leak in
///   2. load the plain Google login URL with the WebView's default UA
///   3. on every YouTube page, read `LOGIN_INFO` + a SAPISID cookie
///   4. once the cookie is complete, validate it through `account_menu`
///   5. pop with `true` when the session is connected
///
/// The password never reaches Dart: only cookies are read back.
class YtMusicLoginPage extends StatefulWidget {
  const YtMusicLoginPage({super.key});

  static const String loginUrl =
      'https://accounts.google.com/ServiceLogin'
      '?continue=https%3A%2F%2Fmusic.youtube.com';

  @override
  State<YtMusicLoginPage> createState() => _YtMusicLoginPageState();
}

class _YtMusicLoginPageState extends State<YtMusicLoginPage> {
  InAppWebViewController? _controller;
  Timer? _poll;
  int _pollTicks = 0;
  double _progress = 0;
  bool _finishing = false;
  String? _error;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _prepareSession(InAppWebViewController controller) async {
    _controller = controller;
    try {
      await CookieManager.instance().deleteAllCookies();
    } catch (_) {
      // A blocked cookie jar is not fatal: the login page still loads.
    }
    if (!mounted) return;
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(YtMusicLoginPage.loginUrl)),
    );
  }

  void _handleUrl(WebUri? uri) {
    if (_finishing || uri == null) return;
    final host = uri.host;
    if (host == 'youtube.com' || host.endsWith('.youtube.com')) {
      _schedulePoll();
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    _pollTicks = 0;
    _poll = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || _finishing) {
        timer.cancel();
        return;
      }
      _pollTicks++;
      await _inspectYoutubePage();
      if (_pollTicks >= 10) timer.cancel();
    });
  }

  Future<void> _inspectYoutubePage() async {
    if (_finishing) return;
    final controller = _controller;
    if (controller == null) return;

    final cookieManager = CookieManager.instance();
    final merged = <String, String>{};
    for (final origin in const [
      'https://music.youtube.com',
      'https://www.youtube.com',
      'https://youtube.com',
    ]) {
      try {
        final cookies = await cookieManager.getCookies(
          url: WebUri(origin),
        );
        for (final cookie in cookies) {
          final name = cookie.name;
          final value = cookie.value?.toString() ?? '';
          if (name.isEmpty || value.isEmpty) continue;
          // First value wins, exactly like the Kotlin merge.
          merged.putIfAbsent(name, () => value);
        }
      } catch (_) {
        // Try the next origin.
      }
    }

    if (merged.isEmpty) return;
    final cookie = merged.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
    if (!hasCompleteYouTubeLoginCookies(cookie)) return;

    _finishing = true;
    _poll?.cancel();
    final visitorData = await _readYtCfg(controller, 'VISITOR_DATA');
    final dataSyncId = await _readYtCfg(controller, 'DATASYNC_ID');

    try {
      await ytMusicAuthService.completeLogin(
        cookie: cookie,
        visitorData: visitorData,
        dataSyncId: dataSyncId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on YtMusicAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _error = error.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _error = 'Could not finish sign-in. Try again from this page.';
      });
    }
  }

  Future<String?> _readYtCfg(
    InAppWebViewController controller,
    String key,
  ) async {
    try {
      final result = await controller.evaluateJavascript(
        source:
            "(function(){try{"
            "var v=(window.ytcfg&&window.ytcfg.get)?window.ytcfg.get('$key'):null;"
            "if(!v&&window.yt&&window.yt.config_){v=window.yt.config_['$key'];}"
            "return v?String(v):null;"
            "}catch(e){return null;}})()",
      );
      final text = result?.toString().trim();
      if (text == null || text.isEmpty || text == 'null') return null;
      return text;
    } catch (_) {
      return null;
    }
  }

  Future<void> _retry() async {
    _poll?.cancel();
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _finishing = false;
      _error = null;
      _progress = 0;
    });
    await _prepareSession(controller);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF0B0B0F)
        : const Color(0xFFF7F7FA);
    final foreground = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'YouTube Music',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            tooltip: 'Start over',
            onPressed: _retry,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: _progress > 0 && _progress < 1
              ? LinearProgressIndicator(value: _progress, minHeight: 3)
              : const SizedBox(height: 3),
        ),
      ),
      body: Column(
        children: [
          _NoticeBar(isDark: isDark, error: _error),
          Expanded(
            child: InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                thirdPartyCookiesEnabled: true,
                sharedCookiesEnabled: false,
                supportZoom: true,
                mediaPlaybackRequiresUserGesture: false,
                useShouldOverrideUrlLoading: false,
              ),
              onWebViewCreated: _prepareSession,
              onProgressChanged: (controller, progress) {
                if (!mounted) return;
                setState(() => _progress = progress / 100);
              },
              onLoadStop: (controller, uri) => _handleUrl(uri),
              onUpdateVisitedHistory: (controller, uri, isReload) =>
                  _handleUrl(uri),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeBar extends StatelessWidget {
  const _NoticeBar({required this.isDark, required this.error});

  final bool isDark;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final errorText = error;
    final color = errorText == null
        ? (isDark ? Colors.white70 : const Color(0xFF636366))
        : (isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: errorText == null
          ? (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04))
          : (isDark
                ? const Color(0xFF3B1513)
                : const Color(0xFFFFDAD6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            errorText == null
                ? CupertinoIcons.lock_shield
                : CupertinoIcons.exclamationmark_triangle,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorText ??
                  'Only YouTube cookies are read back. Your password never '
                      'reaches FluentMusic.',
              style: TextStyle(fontSize: 12, height: 1.35, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
