# Changelog

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
