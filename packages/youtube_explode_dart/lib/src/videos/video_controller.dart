import 'dart:convert';

import 'package:meta/meta.dart';

import '../../youtube_explode_dart.dart';
import '../reverse_engineering/pages/watch_page.dart';
import '../reverse_engineering/player/player_response.dart';

@internal
class VideoController {
  @protected
  final YoutubeHttpClient httpClient;

  VideoController(this.httpClient);

  Future<PlayerResponse> getPlayerResponse(
      VideoId videoId, YoutubeApiClient client,
      {WatchPage? watchPage}) async {
    final payload = client.payload;
    assert(payload['context'] != null, 'client must contain a context');
    assert(payload['context']!['client'] != null,
        'client must contain a context.client');

    final payloadContext = Map<String, dynamic>.from(
      payload['context'] as Map<dynamic, dynamic>,
    );
    final clientContext = Map<String, dynamic>.from(
      payloadContext['client'] as Map<dynamic, dynamic>,
    );

    final userAgent = clientContext['userAgent'] as String?;
    final ytCfg = watchPage?.ytCfg;

    // BotGuard WebPO clients have to name the visitor the token was minted
    // for. The native IOS client asks the same question through sw.js_data, as
    // before, when no visitor data was handed in.
    final visitorData = client.visitorData ??
        (clientContext['clientName'] == 'IOS'
            ? await _extractVisitorData(httpClient, client)
            : null);
    if (visitorData != null && visitorData.isNotEmpty) {
      clientContext['visitorData'] = visitorData;
    }

    final body = {
      ...payload,
      'context': {...payloadContext, 'client': clientContext},
      'videoId': videoId.value,
      // The player-request PO token is what lets googlevideo authorise a
      // web client's audio past the 1 MiB boundary. Without it the URL looks
      // fine and dies mid-track.
      if (client.poToken != null && client.poToken!.isNotEmpty)
        'serviceIntegrityDimensions': {'poToken': client.poToken},
      if (ytCfg?.containsKey('STS') ?? false)
        'playbackContext': {
          'contentPlaybackContext': {
            'html5Preference': 'HTML5_PREF_WANTS',
            'signatureTimestamp': ytCfg!['STS'].toString()
          }
        }
    };

    final visitorHeader = _visitorHeader(ytCfg, visitorData);

    final content = await httpClient.postString(
      client.apiUrl,
      body: body,
      headers: {
        if (userAgent != null) 'User-Agent': userAgent,
        'X-Youtube-Client-Name': clientContext['clientName'],
        'X-Youtube-Client-Version': clientContext['clientVersion'],
        if (visitorHeader != null) 'X-Goog-Visitor-Id': visitorHeader,
        'Origin': 'https://www.youtube.com',
        'Sec-Fetch-Mode': 'navigate',
        'Content-Type': 'application/json',
        if (watchPage != null) 'Cookie': watchPage.cookieString,
        ...client.headers,
      },
    );
    return PlayerResponse.parse(content);
  }

  /// The visitor id the request should carry: the one the PO token was minted
  /// for when there is one, otherwise the watch page's.
  String? _visitorHeader(Map<String, dynamic>? ytCfg, String? visitorData) {
    if (visitorData != null && visitorData.isNotEmpty) return visitorData;
    final watchVisitor =
        ytCfg?['INNERTUBE_CONTEXT']?['client']?['visitorData'];
    return watchVisitor is String && watchVisitor.isNotEmpty
        ? watchVisitor
        : null;
  }

  String? _visitorData;

  Future<String> _extractVisitorData(
      YoutubeHttpClient http, YoutubeApiClient client) async {
    if (_visitorData != null) {
      return _visitorData!;
    }

    var response =
        await http.getString('https://www.youtube.com/sw.js_data', headers: {
      'User-Agent': client.payload['context']['client']['userAgent']!,
      'Content-Type': 'application/json',
    });

    if (response.startsWith(")]}'")) {
      response = response.substring(4);
    }

    final data = json.decode(response) as List<dynamic>;
    final value = data[0][2][0][0][13];

    return _visitorData = value;
  }
}
