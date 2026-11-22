# Third-party notices

FluentMusic is distributed under the GNU General Public License v3.0 (see
[`LICENSE`](LICENSE)). It also builds on, or takes design guidance and public
services from, the projects and communities listed here. Their licences and
terms apply to the parts described below; nothing in this file changes the
licence of FluentMusic itself.

---

## Mornye

- Upstream: <https://github.com/mornyeapp/Mornye-Extension> and the Mornye app
- Copyright © 2026 zarzet and Mornye contributors
- SPDX licence: `LGPL-3.0-only`

FluentMusic's player stage, lyric preview, word-sweep lyrics presentation and
the multi-client YouTube Music stream ladder were designed after Mornye's
open-source implementation. FluentMusic does not ship Mornye's name, icons,
artwork, fonts or other branding. Any code adapted from Mornye remains under
`LGPL-3.0-only`, and its copyright and licence notices are preserved here.

## BitChord

- Upstream: <https://github.com/kushagrasinghx/BitChord>
- Licence: GNU General Public License v3.0

BitChord's public InnerTube client catalog (`InnerTubeXResolver`,
`PlayerClient`, `StreamResolver`) was used as a reference for which YouTube
client identities to try, in what order, and how to repeat a client's headers
when fetching the media bytes. The Dart implementation in
`lib/constants/clients.dart` is FluentMusic's own; no Kotlin source is
included. Because BitChord is GPL-3.0 and FluentMusic is GPL-3.0, the
obligations are compatible.

The BotGuard (“PO token”) minter in `lib/services/youtube/po_token_service.dart`,
`lib/services/youtube/po_token_parsing.dart` and `assets/potoken/bgutils.html`
is a port of BitChord's `PoTokenGenerator`, `PoTokenWebView`, `PoTokenPage`
and `JavaScriptUtil`. The request flow, the token bindings and the page's
JavaScript entry points are BitChord's; the transport is Flutter's
`flutter_inappwebview` bridge instead of Android's `@JavascriptInterface`.
BitChord's GPL-3.0 notice therefore covers those three files.

## Gyawun Music

- Upstream: <https://github.com/sheikhhaziq/gyawun_music>
- Licence: GNU General Public License v3.0

Gyawun's `AudioStreamClient` was the reference for the bounded-range retry
policy in `lib/services/streaming/chunked_stream_proxy.dart`: five units of
error budget, a 500 ms pause between attempts, separate costs for rate limits
and server errors, and resuming a partial response instead of restarting it.
The Dart implementation is FluentMusic's own and runs inside its existing
loopback proxy. Gyawun and FluentMusic are both GPL-3.0, so the obligations
are compatible.

## BgUtils

- Upstream: <https://github.com/LuanRT/BgUtils>
- Licence: MIT
- Copyright © LuanRT and contributors

The BotGuard page FluentMusic loads is modelled on BgUtils v3.2.0, the
reference JavaScript implementation of YouTube's BotGuard challenge client.
The challenge program itself is served by Google and is not redistributed.

## JioSaavn (jiosaavn.com web API)

- Service: <https://www.jiosaavn.com>
- Endpoint: `GET https://www.jiosaavn.com/api.php?__call=search.getResults`

When every YouTube identity refuses a track, FluentMusic may ask JioSaavn's own
web catalogue for the same song by title and artist. Only the search terms leave
the device; no account, cookie or listening data is sent. The media URL in a
search result is wrapped in JioSaavn's public single-DES envelope (key
`38346591`), which the client opens locally to reach the ordinary AAC file. The
service is unofficial, is not affiliated with this project, and may change or
disappear at any time; the switch in **Settings → Playback → Cross-Source
Fallback** turns it off. Streaming remains subject to JioSaavn's own terms.

Spotify is listed in the same settings screen but cannot stream: its audio is
DRM-protected and only plays through Spotify's own SDK, so FluentMusic does not
fetch Spotify audio.

## PointyCastle

- Package: <https://pub.dev/packages/pointycastle>
- License: MIT

PointyCastle supplies the block-cipher primitives used only to open the
JioSaavn media envelope described above. No key material is generated or
stored.

## Unison (Better Lyrics)

- Service: <https://unison.betterlyrics.org>
- Documentation: <https://docs.betterlyrics.org/unison>
- Operator: the Better Lyrics project

Unison is a crowdsourced lyrics database. FluentMusic reads lyrics through the
public `GET /lyrics?v=<videoId>` endpoint. No API key or account is used, and
only the public YouTube video id is sent.

**Required attribution.** Wherever Unison lyrics are displayed, FluentMusic
shows:

> Lyrics from Unison · submitted by *&lt;submitter display name&gt;*

The credit is rendered under the lyrics (synced view footer and plain-text
view). When the API returns no submitter name, the fallback credit is
“Lyrics from Unison”. Unison's attribution requirement applies to apps that
display its lyrics until **7 February 2027** and continues for as long as the
API is used.

Unison's terms permit use by individuals, non-profits and open-source
projects. FluentMusic is an open-source GPL-3.0 project and does not sell
access to the service. Requests stay well below the published read limit
(600 requests per minute per IP), and lyrics are cached in memory for six
hours to avoid repeat downloads.

## Binimum Lyrics

- Service: <https://lyrics-api.binimum.org>
- Operator: the Binimum Lyrics project
- Reference implementation: ArchiveTune's `BinimumLyricsProvider.kt`
  (GPL-3.0, github.com/rukamori)

FluentMusic reads word/syllable-synchronized TTML lyrics through the public
`GET /?track=&artist=&album=&duration=` endpoint and then fetches the returned
`lyricsUrl`. No API key or account is used; only the song title, artist and
optional album/duration are sent. Requests carry the app's own User-Agent and
are cached in memory for six hours.

Results are ranked the same way ArchiveTune ranks them: entries advertised as
word-timed (`timing_type == "word"`) come first, then the closest duration
match. The Dart implementation in `lib/services/lyrics/binimum_provider.dart`
is FluentMusic's own, based on the documented JSON shape. Both projects are
GPL-3.0, so the obligations are compatible.

## Lyrics providers

FluentMusic can also query the following public lyrics services. Each result
is credited in the lyrics UI with the provider name returned by the service:

| Provider | Endpoint | Notes |
| --- | --- | --- |
| YouLy+ | `lyricsplus.prjktla.my.id`, `lyricsplus.binimum.org` | Community word/syllable-synced lyrics |
| BetterLyrics API | `api.betterlyrics.org` | Apple-style TTML word/syllable lyrics |
| Binimum Lyrics | `lyrics-api.binimum.org` | Word/syllable TTML, open API |
| LRCLIB | `lrclib.net` | Open community LRC database |
| lyrics.ovh | `api.lyrics.ovh` | Plain-text fallback |
| paroles.net | `www.paroles.net` | Plain-text fallback, scraped |
| LyricsMania | `www.lyricsmania.com` | Plain-text fallback, scraped |

Lyrics remain the property of their authors and rights holders. FluentMusic
only displays them for personal playback and does not redistribute lyric
files.

## youtube_explode_dart

- Upstream: <https://github.com/Hexer10/youtube_explode_dart>
- Licence: MIT

FluentMusic uses a locally patched copy under `packages/youtube_explode_dart`
for metadata and stream extraction. The upstream MIT notice is retained in
that package.

## liquid_glass_widgets / liquid_glass_renderer

- Upstream: <https://github.com/dhruv-mishra/liquid_glass_widgets>
- Licence: MIT

FluentMusic vendors a patched copy under `packages/liquid_glass_widgets`. The
package's own `THIRD_PARTY_NOTICES` and
`lib/src/engine/ATTRIBUTION.md` contain the complete MIT notices for the
vendored renderer and adapted spring utilities.

## Remote stream bridge (Cobalt)

The optional “Remote Last Resort” playback fallback sends a public YouTube
video id to a Cobalt-compatible bridge (`api.zarz.moe`) only after every
InnerTube client has refused the track. No cookies, account tokens, library
data or listening history are transmitted. The returned URL is temporary and
handled like any other stream URL. This switch can be turned off in
**Settings → Playback → Streaming Fallback**.

Using a bridge does not grant rights to any content. Users are responsible
for complying with the terms of service of the sources they access.

---

If you believe a notice is missing or incorrect, please open an issue at
<https://github.com/ks3695602-sys/FluentMusic-Flutter/issues>.