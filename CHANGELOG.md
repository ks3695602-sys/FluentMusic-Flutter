# Changelog

## 1.5.1+15 - Light-mode and menu polish

### Fixed from the v1.5.0 recording
- Glass surfaces now follow the app theme explicitly, fixing light-mode Account/Appearance rows that turned dark (or white-on-white) after switching from System dark to Light, and the white segmented-control labels on a light track.
- Speed & Pitch panel text, value badges and the Done button resolve from the painted glass variant, so the sheet is readable over both dark artwork and light glass.
- Player overflow menus are titles-only, so the last row (Speed & Pitch) is no longer clipped.
- Removed the stray floating search pill that duplicated the Search tab icon on every page; the Search tab remains the single entry point.
- Settings now reports `FluentMusic 1.5.1` instead of the stale 1.4.0 label.
- Library badge now says `Offline Cache Ready` instead of claiming lossless caching.
- Lyrics Timing sheet shows the real current offset value.

## 1.5.0+14 - Signed-in YouTube Music, sharper player

### The player
- Full-bleed, edge-to-edge artwork: blurred bed, masked sharper layer and soft scrims, drawn behind the status bar and gesture handle with no solid strip.
- The mini-player picture now flies into the player with a rounded `Hero` transition, plus a short dolly-in entrance.
- Real remaining time (`-MM:SS`) instead of a static placeholder.
- The fake "Lossless" pill is gone; only an actual speed change shows a badge.
- One heart everywhere with optimistic state and a 450 ms debounce, for songs and radio alike.
- Volume reaching zero can pause playback, and raising it can resume — both optional.

### Glass controls
- Every iOS-18-style action sheet is replaced by `GlassPullDownButton` + `GlassMenuItem`: player overflow, audio output, playlist options and the now-playing art menu.
- Speed & Pitch is a real control panel: Speed/Pitch/Both segmented control, live sliders, presets and one-tap reset.
- Glass Lab gains working **Distortion amount** and **Refraction height** sliders (refractive index and thickness), persisted and applied to the global glass theme.
- Light-mode pass for Liked / Offline / Recent headers, the Account page and Glass Lab.

### YouTube Music account
- Sign in on Google's own page inside an isolated WebView. Only YouTube cookies are read back; the password never reaches the app.
- Connected profile with avatar, email and channel handle, plus expired-session handling and explicit sign-out.
- New experimental **Use Account for Playback** switch. It is off by default; when on, the app tries the signed-in session first and silently falls back to the existing anonymous stream. The anonymous path, buffer sizes, preload counts and URL caches are unchanged.

### Known limitations
- YouTube's `poToken`/BotGuard requirement means signed-in audio often falls back to the anonymous stream; that fallback is expected, not an error.
- Two-device cloud sync remains a manual test and needs real Supabase keys.
- Lyrics availability still depends on the upstream provider.

## 1.4.0+13 — iOS 27 Liquid Glass remake

### Glass engine
- Live liquid-glass tuning with eight working controls: pinch, horizontal and vertical expansion, chromatic aberration, tint, refraction, bar radius and indicator radius.
- Glass Lab with live preview, copy/paste config, reset and persisted settings.
- Colourful mesh backdrop, clearer refraction and light/dark contrast fixes.
- One glass layer per backdrop group; no glass-inside-glass nesting.

### Navigation and Home
- Four-tab glass bar: Home, Search, Library and Settings.
- Inline search expansion with debounced queries; Search auto-hides when offline.
- Mini player sits above the dock and collapses while search is open.
- Home rebuilt on a sliver scroll view with spring physics, a collapsing large title, and content clear of the dock.
- Quick Picks, playlists, recommended songs, artists and genre shortcuts.

### Settings and account
- Settings rebuilt as separate tinted glass section cards with matching glass subpages.
- Optional account: skip and stay fully local; sign in only when sync is wanted.
- Local profile, JSON export/import and union-based library/playlist sync.
- Supabase REST keys are optional `--dart-define`s; without keys every local feature still works.

### Library
- Add songs through a searchable glass sheet with live YouTube Music results.
- Search, delete, undo and playlist removal, plus create-playlist actions.
- Liked-songs empty state and circular artist grid with drill-down pages.

### Lyrics
- Long unbroken tokens such as `oooooo` wrap safely without overflow.
- Grapheme-safe wrapping keeps emoji, combining marks and RTL text intact.
- Active lyric line scales to 1.06 for a clearer Apple Music-style focus.
- LRC/QRC round-trip coverage for synced and word-timed lyrics.

### Favourites
- Queued glass toast for favourites, unfavourites and playlist adds.
- Two-second auto-dismiss, swipe-to-dismiss, reduced-motion support and dock-aware placement.

### Known limitations
- Two-device cloud sync remains a manual test and needs real Supabase keys.
- Lyrics availability still depends on the upstream provider.
- Deletions are not propagated across devices; sync merges by union.
