# Changelog

## 1.5.4+18 - Player backgrounds, Zen Music and configurable lyrics

### Player and streaming
- Fixed player controls and labels rendering dark in light mode.
- Added Cinematic, Album Art and Blurred Album Art player background modes, with migration from the previous mesh toggle.
- Added Zen Music as the preferred stream resolver while preserving the existing fallback ladder; throttled Zen streams receive larger range chunks.

### Lyrics
- Added configurable BitChord/ArchiveTune lyrics providers with provider enable/disable and priority ordering.
- Added encrypted Paxsenix API-key storage and settings.
- Preserved attribution notices for Unison and GPL-3.0 provider ports.

## 1.5.3+17 - UI recovery, account shelves and a calmer player

### Player and sheets
- Speed & Pitch opens expanded with a pinned Done button, so presets and both sliders stay reachable instead of hiding below the sheet fold.
- The segmented control uses the painted sheet variant for its track, indicator and labels, keeping contrast correct in light and dark themes.
- Player overflow menus are wider, capped at 62% of the screen, and grouped into Playback and Track submenus with short, readable labels.
- The menu glass now carries an explicit readable tint instead of relying on the clear global iOS 27 tint over bright artwork.
- Menu labels, icons and dividers follow the same dark variant, so light mode no longer draws black menu text on the dark platter.
- Synced lyrics add a soft shadow so the active line and its neighbours stay legible on pale artwork.

### Layout and navigation
- Home's large title is shorter, reducing the empty band above the hero card on tall status-bar phones.
- Settings subtitles are shortened to fit the two-line row, so labels no longer truncate mid-word.
- Mini-player bottom spacing follows the dock: 150 px plus the safe-area inset while a track is loaded, and a compact 88 px when the dock is alone.
- The floating dock hides while a page-owned text field has the keyboard, releasing its reserved height and bottom fade so the field and results use the full viewport.
- Settings-style subpages keep the dock-aware body layout, with 40 px back buttons and no content hidden behind the bars.

### Account and Home
- Signed-in YouTube Music library sync reads playlists, liked songs and listening history through InnerTube and merges them with the local library.
- Home gains account-powered Listen again, Speed dial and Forgotten favourites shelves alongside the local hero and rails.
- Offline and anonymous playback paths are unchanged; the signed-in playback experiment remains off by default and flag-gated.

### Performance
- Now Playing no longer stacks multiple live backdrop-blur passes over the lower third of the artwork.
- Player headers only pay for their blur while collapsing, and the mini-player dock uses a single glass surface.

### Known limitations
- YouTube Music InnerTube library shapes still need verification against a live signed-in account; no endpoint is treated as stable yet.
- Signed-in audio playback can still fall back to the anonymous stream because YouTube requires a poToken/BotGuard proof.
- Two-device Supabase sync and lyrics availability remain manual/upstream-dependent, as before.

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
