/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     FluentMusic is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:musify/main.dart' show logger;

import 'po_token_parsing.dart';

/// A pair of BotGuard tokens for one track.
///
/// YouTube's web clients want two different bindings:
/// * [playerRequestToken] is bound to the **visitor data** and travels in the
///   player request's `serviceIntegrityDimensions.poToken`;
/// * [streamingToken] is bound to the **video id** and travels as the `pot`
///   parameter of the googlevideo URL.
class PoTokenPair {
  const PoTokenPair({
    required this.playerRequestToken,
    required this.streamingToken,
    required this.visitorData,
  });

  final String playerRequestToken;
  final String streamingToken;
  final String visitorData;
}

/// Mints YouTube PO tokens in a headless WebView.
///
/// Port of BitChord's `PoTokenGenerator` + `PoTokenWebView` (GPL-3.0). One
/// loaded BotGuard page is kept per visitor session; it is rebuilt when the
/// integrity token nears its expiry, when the page dies, or when a mint fails.
class PoTokenService {
  PoTokenService._();

  static final PoTokenService instance = PoTokenService._();

  static const _mintTimeout = Duration(seconds: 8);
  static const _initTimeout = Duration(seconds: 45);
  static const _tokenTtl = Duration(minutes: 20);

  /// How long a failed minter is left alone before it is retried.
  static const _failureTtl = Duration(minutes: 5);

  final http.Client _http = http.Client();

  _BotGuardMinter? _minter;
  Future<_BotGuardMinter>? _starting;

  String? _visitorData;
  String? _playerRequestToken;
  DateTime? _playerRequestTokenAt;

  /// When minting failed, the web rungs stop asking for a while.
  ///
  /// Three web identities sit in the ladder. Without this brake a broken
  /// minter would make each of them wait out the full token budget before the
  /// native clients were even tried.
  DateTime? _unavailableUntil;

  final Map<String, ({String token, DateTime at})> _streamingTokens = {};

  /// Whether this platform can host the minter at all.
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// The visitor identity tokens are bound to, fetched once per session.
  Future<String?> visitorData() async {
    final cached = _visitorData;
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final response = await _http.get(
        Uri.parse('https://www.youtube.com/sw.js_data'),
        headers: const {
          'User-Agent': _userAgent,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      var body = response.body;
      if (body.startsWith(")]}'")) body = body.substring(4);
      final decoded = jsonDecode(body);
      final value = (decoded as List)[0][2][0][0][13];
      if (value is String && value.isNotEmpty) {
        return _visitorData = value;
      }
    } catch (error) {
      logger.log('Could not read YouTube visitor data', error: error);
    }
    return null;
  }

  /// Tokens for [videoId], or null when this device cannot mint them.
  ///
  /// Both halves are cached: the visitor-bound token per session and the
  /// video-bound token per track.
  Future<PoTokenPair?> tokensFor(String videoId) async {
    if (!isSupported) return null;

    final blocked = _unavailableUntil;
    if (blocked != null && DateTime.now().isBefore(blocked)) return null;

    final visitor = await visitorData();
    if (visitor == null || visitor.isEmpty) {
      _unavailableUntil = DateTime.now().add(_failureTtl);
      return null;
    }

    try {
      final results = await Future.wait<String>([
        _sessionToken(visitor),
        _videoToken(videoId),
      ]);
      _unavailableUntil = null;
      return PoTokenPair(
        playerRequestToken: results[0],
        streamingToken: results[1],
        visitorData: visitor,
      );
    } catch (error) {
      logger.log('PO token generation failed for $videoId', error: error);
      _unavailableUntil = DateTime.now().add(_failureTtl);
      return null;
    }
  }

  Future<String> _sessionToken(String visitor) async {
    final at = _playerRequestTokenAt;
    if (_playerRequestToken != null &&
        at != null &&
        DateTime.now().difference(at) < _tokenTtl) {
      return _playerRequestToken!;
    }
    final token = await _mintToken(visitor);
    _playerRequestToken = token;
    _playerRequestTokenAt = DateTime.now();
    return token;
  }

  Future<String> _videoToken(String videoId) async {
    final entry = _streamingTokens[videoId];
    if (entry != null &&
        DateTime.now().difference(entry.at) < _tokenTtl) {
      return entry.token;
    }
    final token = await _mintToken(videoId);
    if (_streamingTokens.length > 64) {
      _streamingTokens.remove(_streamingTokens.keys.first);
    }
    _streamingTokens[videoId] = (token: token, at: DateTime.now());
    return token;
  }

  Future<String> _mintToken(String identifier) async {
    final minter = await _ensureMinter();
    try {
      return await minter.mint(identifier).timeout(_mintTimeout);
    } catch (error) {
      logger.log('PO token mint failed; rebuilding the page', error: error);
      await _reset();
      final fresh = await _ensureMinter();
      return fresh.mint(identifier).timeout(_mintTimeout);
    }
  }

  Future<_BotGuardMinter> _ensureMinter() {
    final existing = _minter;
    if (existing != null && !existing.isExpired && !existing.isDead) {
      return Future.value(existing);
    }

    // A second caller waits on the same start-up instead of opening a second
    // headless page.
    final starting = _starting;
    if (starting != null) return starting;

    final future = _startMinter();
    _starting = future;
    return future.whenComplete(() {
      if (identical(_starting, future)) _starting = null;
    });
  }

  Future<_BotGuardMinter> _startMinter() async {
    final minter = _BotGuardMinter();
    _minter = minter;
    try {
      await minter.start().timeout(_initTimeout);
      return minter;
    } catch (error, stackTrace) {
      _minter = null;
      try {
        await minter.close();
      } catch (_) {
        // The page never came up; nothing to shut down.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _reset() async {
    final minter = _minter;
    _minter = null;
    _starting = null;
    try {
      await minter?.close();
    } catch (_) {
      // The page may already be gone.
    }
  }

  Future<void> dispose() => _reset();
}

const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/// One loaded BotGuard page.
class _BotGuardMinter {
  HeadlessInAppWebView? _webView;
  InAppWebViewController? _controller;

  final Completer<void> _ready = Completer<void>();
  final Map<String, Completer<String>> _pending = {};
  final http.Client _http = http.Client();

  int _requestCounter = 0;
  DateTime? _expiresAt;
  bool _dead = false;
  bool _challengeRequested = false;

  bool get isDead => _dead;
  bool get isExpired =>
      _expiresAt != null && DateTime.now().isAfter(_expiresAt!);

  Future<void> start() async {
    if (_dead) throw StateError('BotGuard page is dead');

    final html = await rootBundle.loadString('assets/potoken/bgutils.html');
    final webView = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(
        data: html,
        baseUrl: WebUri('https://www.youtube.com'),
        mimeType: 'text/html',
        encoding: 'utf-8',
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        disableContextMenu: true,
        isInspectable: false,
        mediaPlaybackRequiresUserGesture: false,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'onBotguardResult',
          callback: _onBotguardResult,
        );
        controller.addJavaScriptHandler(
          handlerName: 'onInitError',
          callback: _onInitError,
        );
        controller.addJavaScriptHandler(
          handlerName: 'onMinterReady',
          callback: _onMinterReady,
        );
        controller.addJavaScriptHandler(
          handlerName: 'onTokenResult',
          callback: _onTokenResult,
        );
        controller.addJavaScriptHandler(
          handlerName: 'onTokenError',
          callback: _onTokenError,
        );
      },
      onLoadStop: (controller, _) {
        // The page loads once; a second stop event (sub-frame, redirect) must
        // not start a second challenge on the same page.
        if (_challengeRequested) return;
        _challengeRequested = true;
        unawaited(_requestChallenge(controller));
      },
    );

    _webView = webView;
    await webView.run();
    await _ready.future;
  }

  Future<void> _requestChallenge(InAppWebViewController controller) async {
    try {
      final response = await _http.post(
        botguardCreateUri,
        headers: {...botguardHeaders, 'User-Agent': _userAgent},
        body: jsonEncode([botguardRequestKey]),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200 || response.body.isEmpty) {
        throw StateError('BotGuard Create failed (${response.statusCode})');
      }

      final challenge = parseChallengeData(response.body);
      await controller.evaluateJavascript(
        source: 'startFlutterPoToken(${jsonEncode(challenge.toJson())})',
      );
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
  }

  Future<void> _onBotguardResult(List<dynamic> args) async {
    try {
      final botguardResponse = args.isEmpty ? '' : '${args.first}';
      final controller = _controller;
      if (controller == null) throw StateError('No BotGuard page');

      final response = await _http.post(
        botguardGenerateItUri,
        headers: {...botguardHeaders, 'User-Agent': _userAgent},
        body: jsonEncode([botguardRequestKey, botguardResponse]),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200 || response.body.isEmpty) {
        throw StateError('BotGuard GenerateIT failed (${response.statusCode})');
      }

      final parsed = parseIntegrityTokenData(response.body);
      // Leave ten minutes of margin before the token expires.
      _expiresAt = DateTime.now()
          .add(Duration(seconds: parsed.ttlSeconds))
          .subtract(const Duration(minutes: 10));

      await controller.evaluateJavascript(
        source: 'createFlutterMinter(${parsed.integrityTokenLiteral})',
      );
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
  }

  Future<void> _onMinterReady(List<dynamic> args) async {
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<void> _onInitError(List<dynamic> args) async {
    final message = args.isEmpty ? 'unknown' : '${args.first}';
    _fail(StateError('BotGuard init failed: $message'), StackTrace.current);
  }

  Future<void> _onTokenResult(List<dynamic> args) async {
    final payload = args.isEmpty ? '' : '${args.first}';
    final separator = payload.indexOf('|');
    if (separator < 0) return;
    final key = payload.substring(0, separator);
    final bytes = payload.substring(separator + 1);
    final completer = _pending.remove(key);
    if (completer == null || completer.isCompleted) return;
    completer.complete(uint8ListToBase64(bytes));
  }

  Future<void> _onTokenError(List<dynamic> args) async {
    final payload = args.isEmpty ? '' : '${args.first}';
    final separator = payload.indexOf('|');
    final key = separator < 0 ? '' : payload.substring(0, separator);
    final message = separator < 0 ? payload : payload.substring(separator + 1);
    final completer = _pending.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(StateError('PO token failed: $message'));
    }
  }

  void _fail(Object error, StackTrace stackTrace) {
    _dead = true;
    if (!_ready.isCompleted) {
      _ready.completeError(error, stackTrace);
    }
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
    _pending.clear();
  }

  Future<String> mint(String identifier) {
    if (_dead) {
      return Future.error(StateError('BotGuard page is dead'));
    }
    final controller = _controller;
    if (controller == null || !_ready.isCompleted) {
      return Future.error(StateError('BotGuard page is not ready'));
    }

    final key = '$identifier#${++_requestCounter}';
    final completer = Completer<String>();
    _pending[key] = completer;

    controller
        .evaluateJavascript(
          source: 'mintFlutterToken(${jsonEncode(key)}, '
              '${stringToUint8Array(identifier)})',
        )
        .catchError((Object error) {
      final pending = _pending.remove(key);
      if (pending != null && !pending.isCompleted) {
        pending.completeError(error);
      }
    });

    return completer.future;
  }

  Future<void> close() async {
    _dead = true;
    _http.close();
    final webView = _webView;
    _webView = null;
    _controller = null;
    try {
      await webView?.dispose();
    } catch (_) {
      // The renderer may already be gone.
    }
  }
}