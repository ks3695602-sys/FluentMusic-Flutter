# FluentMusic v1.4.0 — MASTERPLAN
**"All features first → ONE APK at the end"**
Last updated: 2026-11-14 · Owner: user · Executor: Gemini via opencode · Reviewer: assistant

---

## 0. Mission

FluentMusic (Android only) ko iOS 27 Apple Music level par le jana:
real liquid glass, working glass tuner, naya searchable bottom bar, naya settings,
optional account + sync, library features, lyrics polish — **sab features pehle,
phir ek hi APK build**.

**Non-goals:** iOS build, tablet layout, web build.

---

## 1. Core rules (never break)

| # | Rule | Why |
|---|---|---|
| R1 | **Local-first** — login optional, app bina account ke 100% chale | Koi user lock-out nahi |
| R2 | **No invented API** — koi bhi `Glass*` use karne se pehle `docs/GLASS_API.md` se signature confirm | Pichli baar `GlassAdaptiveScope.maybeOf` guess se CI red hua |
| R3 | **No glass-inside-glass** | Nested glass = grey/dull (image 6 bug) |
| R4 | **One glass layer per backdrop group** | `GlassBackdropGroup` ke andar sirf ek |
| R5 | **Batch = 3–4 files per turn** | Gemini ka sweet spot |
| R6 | **Code must compile after every turn** | Half-refactor kabhi push na ho |
| R7 | **Turn > 20 min = kill + chhota chunk** | Gemini "Working" me so jata hai |
| R8 | **Commit + push every 20–30 min** | PC band / API limit par loss zero |
| R9 | **Only ONE APK build at the end** | User requirement |
| R10 | **Analyze-only CI on every push** | Errors jaldi pakdo, APK ka wait nahi |
| R11 | **Secrets repo me nahi** | `--dart-define` + GitHub Secrets |
| R12 | **PROGRESS.md update every 5 min** | Crash/limit ke baad resume |

---

## 2. Timeline (single build at end)

| Phase | Kaam | Est. |
|---|---|---|
| P0 | Ground truth (API doc + GEMINI.md + analyze-only CI) | 15 min |
| P1 | Glass engine + Glass Lab + backdrop + old sliders delete | 40 min |
| P2 | Bottom bar + accessory + search + bouncy | 30 min |
| P3 | Home redesign + spring | 30 min |
| P4 | Settings full remake + subpages | 40 min |
| P5 | Account + sync (local-first, cloud optional) | 45 min |
| P6 | Library features | 35 min |
| P7 | Lyrics long-token polish | 15 min |
| P8 | Favourite glass popup | 10 min |
| P9 | QA fixes + **single APK build** + release | 25 min |
| | **Total** | **~4.5 h** |

**Checkpoints:** commit + push at end of P1, P3, P5, P7, P9. If anything dies, resume from last checkpoint.

---

## 3. Progress protocol (5-min updates)

Every 5 minutes, executor posts a block like this and appends it to `PROGRESS.md`:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏱️ T+00:35 | PHASE P1 | 62% | vibe: 🧊
✅ Done: glass_config + controller
🔨 Now: glass_lab_page sliders bind
⏭️ Next: delete old sliders in settings_subpages
🐛 Blocked: none
💾 Commit: 3f2a1c9 (pushed)
📄 Files touched: 2
😹 Joke: Glass itna clear hai ki ex ka message bhi dikh jaye (unfortunately)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If blocked: write **exact error + file:line + last good commit** in `PROGRESS.md`.

---

## 4. Resume-after-crash (any AI can continue)

1. Read `PROGRESS.md` → section **RESUME CARD**.
2. `git log --oneline -5` → last commit = checkpoint.
3. Open phase checklist in `PROGRESS.md`, pick first unchecked item.
4. Read `GEMINI.md` + `docs/GLASS_API.md` (if exists).
5. Continue from **next step**, do not redo done items.
6. Commit + push before touching anything risky.

---

## 5. Phases (full detail)

### P0 — Ground Truth (15 min)

**Create**
- `docs/GLASS_API.md` — real signatures from `liquid_glass_widgets 1.17.3`:
  - `GlassTabBar.searchable` params (accessory slot? `searchConfig`? `isSearchActive`?)
  - `GlassSearchBarConfig` fields
  - Glass theme/settings model: pinch, expansionH/V, chromaticAberration, tint, refraction, barRadius, indicatorRadius
  - `GlassQuality`, `GlassAdaptiveScopeConfig`, `GlassScaffold` bottomBar inset
  - Is `GlassSearchableBottomBar` a **package export** or **example-local composite**?
- `GEMINI.md` — AI rules, file map, commands, traps, batch limits, progress protocol
- `.github/workflows/analyze-only.yml` — analyze on push to `feat/**` (2 min)

**Verify:** `flutter analyze --no-fatal-infos --no-fatal-warnings` green.
**Gate:** no phase starts until this is green.

---

### P1 — Glass Engine + Glass Lab (40 min)

**New**
- `lib/theme/glass_config.dart`
- `lib/theme/glass_config_controller.dart` (ChangeNotifier + Hive + InheritedNotifier scope)
- `lib/widgets/glass/glass_lab_page.dart`
- `lib/widgets/glass/glass_backdrop.dart`

**Model**
```dart
class GlassConfig {
  final double pinchStrength;       // 0.00–1.00  (0.40)
  final double expansionH;          // 0–32 px    (12)
  final double expansionV;          // 0–32 px    (8)
  final double chromaticAberration; // 0.00–0.50  (0.15)
  final double tint;                // 0.00–1.00  (0.00)
  final double refraction;          // 1.00–1.50  (1.15)
  final double? barRadius;          // null = capsule
  final double? indicatorRadius;    // null = auto
}
```

**Glass Lab UI (image "Indicator Parity")**
- 8 sliders + value chips + live preview: `GlassSegmentedControl`, bottom bar pill, glass button
- `Reset to iOS 26 defaults` + Export/Import JSON
- Purane saare sliders **delete** (blur/thickness/tier junk in `settings_subpages.dart`)

**Look fixes**
- Colorful backdrop (album art blur + subtle mesh gradient) behind glass — **refraction ke liye zaroori**
- `GlassAdaptiveScopeConfig(minQuality: premium, initialQuality: premium)`
- Light/dark split intact; light mode contrast pass

**DONE WHEN:** slider move → visible difference; diagnostic says Premium + shader OK.

---

### P2 — Bottom Bar + Accessory (30 min)

**Files:** `lib/screens/bottom_navigation_page.dart`, `lib/widgets/mini_player.dart`, `lib/widgets/glass/glass_bottom_accessory.dart` (new)

- Old Column (MiniPlayer + GlassTabBar) **remove**
- One `GlassTabBar.searchable` + **accessory slot**
- Tabs: **Home · Library · Canvas · Settings** (4) + search action
- `expandWhenActive: true` → inline expand (no separate search branch)
- Search expand → mini player **collapse** (height 64→0, opacity); close → back
- `bottomInset` = bar + accessory; content never hidden
- Bouncy effect: `SpringSimulation` scale 0.96→1.0
- No nested glass; one `GlassBackdropGroup`

**DONE WHEN:** zero overlap, no text bleed, 60fps, search smooth.

---

### P3 — Home Redesign (30 min)

**Files:** `lib/screens/home_page.dart`, `lib/widgets/home/*`

- `CustomScrollView` + slivers; large title → `SliverPersistentHeader` collapse
- Long page: Recently Played → Quick Picks → Suggested → Recommended → Monthly Recap → Genres
- Spring physics: `BouncingScrollPhysics` + `SpringSimulation` overscroll
- Content under bottom bar (P2 inset)
- Section cards glass, list rows solid
- **Songs pehle, Artists baad me**

**DONE WHEN:** long scroll + spring feel, last item fully visible above bar.

---

### P4 — Settings Remake (40 min)

**Files:** `lib/screens/settings_page.dart`, `lib/screens/settings/settings_subpages.dart`

| Section card (separate glass) | Tiles |
|---|---|
| Account & Sync | Profile, Sign in, Last sync |
| Appearance | Theme mode, **Glass Lab**, Layout |
| Playback | Quality, Crossfade, Background play, Equalizer |
| Library & Content | Songs/Artists order, Lyrics providers, Language, Country |
| Data & Backup | Export/Import JSON, Clear cache |
| Behavior & Privacy | History, Defaults, Android Auto |
| About | Version, Updates, Licenses |

- Har item apna card (not one rectangle) + colored icon badge
- Every subpage: `GlassScaffold` + `GlassListTile` (Account black-box fix)
- "Tab Bar + Bottom Fade" pattern
- Solid list cards stay solid (no glass-on-glass)

**DONE WHEN:** 7 sections, no plain black subpage, light mode readable.

---

### P5 — Account + Sync (45 min)

**New**
- `lib/services/account/account_service.dart`
- `lib/services/sync/sync_service.dart`
- `lib/screens/account_page.dart`

**Models**
```dart
AccountSession { userId, email, displayName, provider, createdAt }
SyncEnvelope   { schema, updatedAt, playlists[], librarySongs[], settings{} }
Tombstone      { entity, id, deletedAt }
```

**Rules**
- Skip / Continue without account → everything works
- Email magic-link + Google OAuth (Supabase); keys via `--dart-define`
- Offline outbox + status chip (Synced / Syncing / Offline)
- Conflict: `updated_at` wins + per-entity merge + tombstones
- RLS: `user_id = auth.uid()`
- Kotlin reference: `FluentMusic-Android/app/src/main/kotlin/moe/rukamori/archivetune/`
  - `viewmodels/LoginViewModel.kt`, `utils/SavedAccounts.kt`, `backup/BackupArchiveRepository.kt`, `ui/screens/settings/AccountSettings.kt`
- Backup compat: Kotlin JSON → `SyncEnvelope v1`

**DONE WHEN:** skip works; with keys, 2 devices sync; offline add flushes later.

---

### P6 — Library Features (35 min)

| Item | Detail |
|---|---|
| Add new songs | URL / YouTube search / local file, duplicate detect |
| Search in add-song | debounce field + results |
| Delete song | long-press/swipe + glass confirm dialog |
| Playlist create | + button, name/cover, reorder |
| Artist section | improve (image, album count), songs-first |

**DONE WHEN:** add → search → delete → playlist create all work from UI.

---

### P7 — Lyrics Polish (15 min)

**Files:** `lib/services/lyrics/lyrics_models.dart`, `lib/widgets/now_playing/synced_lyrics_view.dart`

- Long token `oooooo` → soft hyphen / break-word / FittedBox per word
- Active word scale 1.0→1.06
- Multi-line + RTL safe
- QRC/LRC round-trip tests green

---

### P8 — Favourite Glass Popup (10 min)

**New:** `lib/widgets/glass/glass_toast.dart` + favourite call sites

- **Not an ad** — glass toast: *"Smoothly added to favourites ♥"*
- 2s, queue, swipe dismiss, reduced-motion respect
- Favourite / playlist-add / unfavourite use it

---

### P9 — QA + ONE APK + Release (25 min)

1. Full `flutter analyze` + `flutter test`
2. **Single APK build** (release) → artifact
3. Device smoke test checklist (below)
4. `version: 1.4.0+13`, CHANGELOG
5. Tag `v1.4.0`, GitHub Release (APK + Windows demo optional)

**Debug fallback:** agar release APK fail ho (lint/AGP), debug APK build karo — feature test ke liye same.

---

## 6. Feature checklist (traceability — nothing skipped)

| Item | Phase |
|---|---|
| Refraction/bending/alpha, dull fix | P1 |
| Sliders actually work | P1 |
| Shaders / Impeller fix | P1 |
| Colorful backdrop | P1 |
| More liquid glass | P1/P4 |
| Clear ↔ Tinted α | P1 |
| `GlassSearchableBottomBar` 4 tabs | P2 |
| Search inline expand | P2 |
| Mini player accessory + collapse | P2 |
| Dock overlap fix | P2 |
| Bouncy effect | P2 |
| Settings complete remake | P4 |
| Separate section cards | P4 |
| Glass subpages | P4 |
| Tab Bar + Bottom Fade | P4 |
| Glass Lab tuner | P1 |
| Light mode contrast | P1/P4 |
| Long-word lyrics fix | P7 |
| Add new songs | P6 |
| Account, login not mandatory | P5 |
| Search in add-song | P6 |
| Delete song | P6 |
| Playlist create | P6 |
| Songs before Artists | P3 |
| Artist section improve | P6 |
| UI overall | P1–P4 |
| Background play (verify) | P9 |
| Inbuilt dark mode (verify) | P9 |
| Favourite popup (not ad) | P8 |
| Sign-in + playlist/library sync | P5 |
| Home long + spring + under bar | P3 |
| v1.4.0 release | P9 |

---

## 7. File map

| File | Phase |
|---|---|
| `docs/GLASS_API.md`, `GEMINI.md`, `analyze-only.yml` | P0 |
| `lib/theme/glass_config.dart` | P1 |
| `lib/theme/glass_config_controller.dart` | P1 |
| `lib/widgets/glass/glass_lab_page.dart` | P1 |
| `lib/widgets/glass/glass_backdrop.dart` | P1 |
| `lib/widgets/glass/glass_bottom_accessory.dart` | P2 |
| `lib/screens/bottom_navigation_page.dart` | P2 |
| `lib/widgets/mini_player.dart` | P2 |
| `lib/screens/home_page.dart` + `lib/widgets/home/*` | P3 |
| `lib/screens/settings_page.dart` | P4 |
| `lib/screens/settings/settings_subpages.dart` | P1/P4 |
| `lib/services/account/account_service.dart` | P5 |
| `lib/screens/account_page.dart` | P5 |
| `lib/services/sync/sync_service.dart` | P5 |
| add-song sheet + `library_page.dart` + `playlist_page.dart` | P6 |
| `lib/services/lyrics/lyrics_models.dart` | P7 |
| `lib/widgets/now_playing/synced_lyrics_view.dart` | P7 |
| `lib/widgets/glass/glass_toast.dart` | P8 |
| `pubspec.yaml`, `lib/constants/version.dart`, `CHANGELOG.md` | P9 |

---

## 8. Risk register

| Risk | Mitigation |
|---|---|
| API guess galat | P0 doc + analyze-only 2 min |
| Shaders device par off | Diagnostic tile + fallback tier + Impeller manifest |
| Glass phir dull | Colorful backdrop + tint 0.0 + screenshot A/B |
| Backend keys nahi | Feature flag hidden; local-first |
| Long single-build wait | analyze-only every push; checkpoints every ~30 min |
| Gemini slow/stuck | 20-min kill rule; 3–4 files max |
| Half-done refactor pushed | compile gate per turn |
| Network push fail | `--resolve api.github.com:443:140.82.112.6` + retry |
| PC shutdown mid-work | PROGRESS.md + checkpoint commits |
| API limit | RESUME CARD in PROGRESS.md |

---

## 9. QA checklist (before final APK)

- [ ] Refraction/bending visible, not dull
- [ ] All 8 sliders produce live change
- [ ] Dock overlap zero; search expand smooth; mini player collapse
- [ ] Home long scroll + spring; last item above bar
- [ ] Settings 7 separate cards; no plain black subpage
- [ ] Login skip works; login syncs
- [ ] Songs before Artists
- [ ] `oooooo` lyric line not broken
- [ ] Glass toast on favourite
- [ ] Light mode WCAG AA
- [ ] 60fps scroll, ≤6 glass surfaces/screen, APK <45MB
- [ ] Android 10 / 13 / 15 smoke test

---

## 10. Release

```
version: 1.4.0+13
tag: v1.4.0
assets: FluentMusic-universal-release.apk (+ windows zip optional)
notes: glass engine, tuner, new bar, settings, account/sync, library, lyrics
```

---

## 11. AI hand-off prompt (copy-paste)

```
Read MASTERPLAN.md, PROGRESS.md, GEMINI.md first.
Continue from the first unchecked item in PROGRESS.md.
Rules: 3–4 files per turn, compile after every turn, commit+push every 20–30 min,
update PROGRESS.md every 5 min. Do NOT build APK until P9.
Never guess a package API — check docs/GLASS_API.md.
```

---

## 12. User inputs needed

1. **Supabase URL + anon key** before P5 (optional; without it local sync ships).
2. Final device test at P9.
