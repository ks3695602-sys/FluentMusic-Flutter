# Sprint D3 — Streaming + Lyrics + Video + Polish

**Status:** 📝 Plan only — koi code change nahi hua
**Created:** 2026-11-22
**Base commit:** `b64d644` (`feat/v1.5.0-s1-d2`)
**Target branch:** `feat/v1.5.0-s1-d3`
**Estimated coding time:** ~90 min + ~10 min APK build
**Resume later:** user abhi doosre project me contribute kar raha hai; yeh file handoff ke liye hai.

---

## 0. Goal (user request, ek jagah)

1. **Streaming** — Gyawun Music ka streaming code tap karo (fast start).
2. **Lyrics word-to-word** — Mornye ka poora lyrics rendering engine copy/port karo; active line ke missing spaces fix karo.
3. **Lyrics providers** — Kotlin reference app ke saare providers port karo.
4. **Lyrics providers in Settings** — toggles + order + word-sync option.
5. **Video support** — current track ke liye minimal video playback.
6. **Mesh** — aur zyada colorful/vivid.
7. **Performance** — quick wins.
8. **Immersive mode** — status bar + navigation bar default hidden (fullscreen).
9. **Backup provider** — jo existing provider gaana der se play karta hai, use **last-resort backup** rakho; delete mat karo.
10. **Home top-right** — light/dark theme toggle button.

**Out of scope is sprint:** full video search/browse, video queue, deep performance profiling, iOS build.

---

## 1. Reality check

1.5h mein "sab kuch full quality" possible nahi:

- Video **minimal** hoga (current track only, muxed stream). Full video browse/search next sprint.
- Providers **6–8 live** add honge; jo API dead/blocked mile use disabled by default. "Saare" ka framework ready hoga, baaki 5-min additions later.
- Performance sirf **quick wins**; koi risky rewrite nahi.

Agar time bache to providers pehle, video baad me — ya ulta. Recommendation: **video pehle** (visible feature), extra providers next round.

---

## 2. Timeline

| # | Kaam | Time | Files | Done = |
|---|---|---|---|---|
| 0 | Branch + baseline analyze/test | 3m | — | clean start |
| 1 | Streaming: Gyawun port + androidVr primary | 18m | `lib/services/streaming/`, `lib/services/common_services.dart`, `lib/constants/clients.dart` | logs me primary path; fallback intact |
| 2 | Lyrics word-join fix + Mornye renderer complete | 10m | `lib/mornye_player/widgets/player_lyrics_word_sweep.dart`, `player_lyrics.dart` | `I was on the outside...` sahi |
| 3 | Lyrics providers port | 18m | `lib/services/lyrics_manager.dart` + new provider files | fallback chain + tests |
| 4 | Lyrics settings UI | 7m | `lib/screens/settings/settings_subpages.dart`, settings model | persist + apply |
| 5 | Video minimal | 15m | `pubspec.yaml`, new video sheet, player GlassMenu | video plays for supported tracks |
| 6 | Home theme toggle + immersive | 8m | `lib/screens/home_page.dart`, `lib/main.dart` | tap toggles + persists; bars hidden |
| 7 | Mesh + performance quick wins | 8m | `lib/mornye_player/widgets/mornye_player_background.dart`, hot widgets | zyada vivid, jank kam |
| 8 | Analyze + tests + commit + push + APK | 10m | — | green run |

**Total ~90 min** (GitHub APK build alag ~9 min).

---

## 3. Lane details

### Lane 1 — Streaming (Gyawun)

**Source research (done):**
- Repo: `https://github.com/sheikhhaziq/gyawun_music` — Flutter, **GPL-3.0**, same `just_audio` + `youtube_explode_dart` family.
- Key files:
  - `lib/services/stream_client.dart` → `AudioStreamClient`
  - `lib/services/yt_audio_stream.dart` → `YouTubeAudioSource extends StreamAudioSource`
  - `lib/services/media_player.dart` → just_audio queue setup
- Gyawun approach:
  - `youtube_explode_dart` fork; **single client** `YoutubeApiClient.androidVr` + `requireWatchPage: true`.
  - Audio-only streams sorted by bitrate; high/low quality.
  - Throttled stream par ~10.4 MB bounded range; warna full file.
  - `StreamAudioSource` direct (local HTTP proxy nahi).
  - Retry: 5 attempts, 500ms backoff, error cost — `RequestLimitExceededException` = 2, `FatalFailureException` = 3, other = 1.
  - `c=ANDROID` ke liye `Range` header; warna URL me `range` query param.

**Hamare app me:**
- `ChunkedStreamProxy` already BitChord ka `ChunkedDataSource` port hai — chunking/seek cache rehne do.
- Add:
  1. Gyawun-style retry policy (error cost + backoff) in streaming layer.
  2. **Primary resolver:** single `androidVr` + `requireWatchPage` path (pehle 5 min me check karo ki vendored `packages/youtube_explode_dart` yeh support karta hai; nahi to client config add karo).
  3. Timing logs: `stream timing: primary ...` / `fallback ...`.
- **Fallback order (user requirement):**
  1. Gyawun primary (`androidVr`)
  2. Existing 20-client ladder
  3. Existing slow provider — **last-resort backup**, delete nahi karna.

**Acceptance:**
- Primary path hit hone par first-byte timing improve.
- Primary fail hone par purana ladder + slow provider exactly pehle jaisa kaam kare.
- Koi crash/regression nahi.

**License:** Gyawun GPL-3.0; FluentMusic bhi GPL-3.0 — compatible, attribution add karna (`THIRD_PARTY_NOTICES.md`).

---

### Lane 2 — Lyrics word-to-word (Mornye)

**Root cause mil gaya:**
- `lib/mornye_player/widgets/player_lyrics_word_sweep.dart` line ~636:
  ```dart
  final text = widget.segments.join();
  ```
  Segments word tokens hain, bina space ke join ho rahe hain → active line `Iwasontheoutsidealwayslookingin`.
- Fix: source spacing preserve karo ya `join(' ')` + punctuation handling. Non-active lines plain text hain isliye theek dikhti hain.

**Mornye renderer:**
- `lib/mornye_player/widgets/player_lyrics.dart` + `part 'player_lyrics_word_sweep.dart'`
- Related files: `lyrics_parser.dart`, `lyrics_timeline.dart`, `synced_lyrics_scroll.dart`, `aligned_lyric_pronunciation.dart`.
- Mornye reference (Kotlin/Compose) me `Lyrics.kt`, `LyricsV2.kt`, `LyricsEnhanced.kt`, `LyricsTextWrapping.kt` — spacing/wrapping logic se diff karke jo missing hai port karo.
- **UI naya mat banao** — Mornye ka copied renderer hi use hoga.

**Acceptance:**
- Active word-synced line me saare spaces sahi.
- Word highlight/sweep timing pehle jaisa.
- Regression test for token join.

---

### Lane 3 — Lyrics providers (Kotlin reference)

**Already in Flutter (`lib/services/lyrics_manager.dart`):**
- Unison (video-id exact)
- YouLyPlus
- BetterLyrics (Apple TTML)
- LRCLIB
- Plain-text: lyrics.ovh, paroles.net, lyricsmania.com

**Kotlin reference providers (`C:\Rough\Antigravity\FluentMusic-Android\app\src\main\kotlin\moe\rukamori\archivetune\lyrics\`):**
- `KuGouLyricsProvider.kt` — **missing**
- `MegalobizLyricsProvider.kt` — **missing**
- `SimpMusicLyricsProvider.kt` — **missing**
- `PaxsenixAppleMusicLyricsProvider.kt` — **missing**
- `PaxsenixMusixmatchLyricsProvider.kt` — **missing**
- `PaxsenixSpotifyLyricsProvider.kt` — **missing**
- `PaxsenixLyricsProvider.kt` (base/helper) — reference
- `BinimumLyricsProvider.kt` — **missing**
- `YouTubeLyricsProvider.kt` — **missing**
- `YouTubeSubtitleLyricsProvider.kt` — **missing**
- `BetterLyricsProvider.kt` / `BetterLyricsPortatoProvider.kt` — already ported (verify)
- `UnisonLyricsProvider.kt`, `YouLyPlusLyricsProvider.kt`, `LrcLibLyricsProvider.kt` — already ported
- `LyricsHelper.kt` — fallback chain reference
- `LyricsProvider.kt` — interface reference
- `LyricsProviderSettings.kt` — settings reference

**Port rules:**
- Existing `Lyrics` model + `_fetchFrom*` pattern follow karo.
- Har provider: 8s timeout, cache, source credit, graceful failure.
- Priority: synced (word/syllable) > synced LRC > plain text.
- Dead/blocked API → provider disabled by default, app crash nahi.
- Tests: parser + provider selection + fallback order.

**Acceptance:**
- At least 6 missing providers live.
- Settings me on/off + order.
- Lyrics result me provider credit.

---

### Lane 4 — Lyrics settings

- Existing page: `LyricsSettingsPage` in `lib/screens/settings/settings_subpages.dart` (~line 1115).
- Add:
  - Provider list with toggles + drag-to-reorder.
  - "Word-by-word" toggle (on/off).
  - Persist via existing settings manager (`addOrUpdateData` / settings model).
- Settings entry already exists: `settings_page.dart` line ~123 → "Lyrics — Providers, translation and timed lyrics".

**Acceptance:** toggle/order app restart ke baad bhi yaad rahe; disabled provider call na ho.

---

### Lane 5 — Video (minimal)

- Add `video_player` dependency (currently pubspec me nahi; `media_kit` hai par Android video libs nahi).
- Resolve **muxed** stream (typically 360p) from the same manifest.
- Player ke GlassMenu me "Video" item — sirf tab dikhe jab muxed stream available ho.
- Video sheet/route: `VideoPlayer` + basic controls; open hone par `just_audio` pause, close par resume.
- Muxed stream na mile → item hide, audio unaffected. **Crash nahi.**
- Out of scope: video search, browse, separate video queue, PiP.

**Acceptance:** supported track par video chalta hai; unsupported par gracefully hidden.

---

### Lane 6 — Theme toggle + immersive mode

**Theme toggle (home top-right):**
- `lib/screens/home_page.dart` → `_HomeHeaderDelegate` (line ~552), right side me profile avatar ke paas sun/moon button.
- Reuse existing mechanism (now-playing me already hai, `now_playing_page.dart` line ~515):
  ```dart
  final next = isDark ? ThemeMode.light : ThemeMode.dark;
  addOrUpdateData<int>('settings', 'themeIndex', next.index);
  Musify.updateAppState(context, newThemeMode: next);
  ```
- Delegate me naye params add karo; `shouldRebuild` update karo.

**Immersive mode:**
- `lib/main.dart` line ~137 currently `SystemUiMode.edgeToEdge`.
- Default: `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`.
- Keyboard/dialog open par bars restore; band hone par wapas hide.
- Bottom sheets / GlassMenu ke saath test karo.

**Acceptance:** app open par fullscreen; theme button tap par light/dark toggle + persist.

---

### Lane 7 — Mesh + performance quick wins

**Mesh (`lib/mornye_player/widgets/mornye_player_background.dart`):**
- `mornyePlayerGradient` abhi 3-stop hai.
- 4-stop + **artwork-independent complementary accent** (hue + ~150°) add karo.
- Saturation up, brightness ladder same — lyrics/white text readable rahe.
- Optional: very slow drift, par `RepaintBoundary` ke andar; performance pehle.

**Performance quick wins:**
- Player/lyrics ke around `RepaintBoundary`.
- Image cache cap (`PaintingBinding.instance.imageCache.maximumSizeBytes`).
- Scroll ke dauraan home header ka `BackdropFilter` blur off.
- Hot lists me `const` widgets.
- Riverpod `select` se rebuild scope tight.
- **No deep profiling** is sprint me.

**Acceptance:** mesh visibly zyada colorful; obvious jank kam; koi naya crash nahi.

---

### Lane 8 — Verify + ship

Commands (Windows, Flutter PATH me nahi hai):

```powershell
& "C:\flutter\flutter\bin\flutter.bat" analyze --no-pub
& "C:\flutter\flutter\bin\flutter.bat" test test/lyrics_manager_test.dart test/chunked_stream_proxy_test.dart
```

- New tests: word join regression, provider selection/fallback.
- Commit per lane (3–4 files max per commit), push branch.
- APK dispatch:
  ```powershell
  gh workflow run build-apk.yml --ref feat/v1.5.0-s1-d3
  ```
- Build success ke baad artifact download:
  ```powershell
  gh run download <run-id> -n FluentMusic-Flutter-APKs -D "C:\Rough\Antigravity\Project1\Artifacts\apk-<sha>"
  ```

---

## 4. Risks & fallbacks

| Risk | Fallback |
|---|---|
| `androidVr` bhi fail | Existing ladder + slow provider backup; no regression |
| Vendored `youtube_explode_dart` me `androidVr`/`requireWatchPage` nahi | Client config add karo ya Gyawun fork ke relevant files vendor karo (GPL-3.0) |
| Provider API dead/blocked | Disabled by default; settings me off; app crash nahi |
| Muxed video stream nahi mila | Video menu item hide; audio unaffected |
| 1.5h tight | Video pehle (visible), extra providers next round |
| Immersive mode keyboard ke saath fight | Bars restore on keyboard, re-hide on close |
| GPL attribution miss | `THIRD_PARTY_NOTICES.md` me Gyawun + provider credits |

---

## 5. Resume card (baad me isi file se start karna)

```
STATUS      : plan only, no code changed
BASE COMMIT : b64d644 (feat/v1.5.0-s1-d2)
NEW BRANCH  : feat/v1.5.0-s1-d3
NEXT ACTION : git switch -c feat/v1.5.0-s1-d3
              → Lane 1: streaming (Gyawun androidVr primary + retry policy)
BLOCKED BY  : none
NOTE        : user abhi doosre project me contribute kar raha hai
```

---

## 6. Source references

- Gyawun Music: `https://github.com/sheikhhaziq/gyawun_music` (GPL-3.0)
  - `lib/services/stream_client.dart`
  - `lib/services/yt_audio_stream.dart`
  - `lib/services/media_player.dart`
- Kotlin lyrics reference:
  `C:\Rough\Antigravity\FluentMusic-Android\app\src\main\kotlin\moe\rukamori\archivetune\lyrics\`
- Flutter lyrics:
  `lib/services/lyrics_manager.dart`, `lib/services/lyrics/`
  `lib/mornye_player/widgets/player_lyrics.dart`, `player_lyrics_word_sweep.dart`
- Streaming:
  `lib/services/common_services.dart`, `lib/services/streaming/chunked_stream_proxy.dart`, `lib/constants/clients.dart`
- Theme:
  `lib/screens/home_page.dart`, `lib/screens/now_playing_page.dart`, `lib/main.dart`
- Mesh:
  `lib/mornye_player/widgets/mornye_player_background.dart`
